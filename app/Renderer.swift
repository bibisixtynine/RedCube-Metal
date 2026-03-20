import MetalKit
import simd
import Foundation

struct Vertex {
    let position: simd_float3
    let normal: simd_float3
    let color: simd_float4
}

struct CubeInstance {
    var position: simd_float3
    var size: Float
    var color: simd_float4
}

typealias DrawCubeCFunction = @convention(c) (Float, Float, Float, Float, Float, Float, Float, Float) -> Void
typealias SetCameraCFunction = @convention(c) (Float, Float, Float, Float, Float, Float) -> Void
typealias ClearCubesCFunction = @convention(c) () -> Void

let qjsDrawCubeCallback: DrawCubeCFunction = { x, y, z, size, r, g, b, a in
    Renderer.shared.addCube(x: x, y: y, z: z, size: size, r: r, g: g, b: b, a: a)
}

let qjsSetCameraCallback: SetCameraCFunction = { px, py, pz, tx, ty, tz in
    Renderer.shared.setCamera(px: px, py: py, pz: pz, tx: tx, ty: ty, tz: tz)
}

let qjsClearCubesCallback: ClearCubesCFunction = {
    Renderer.shared.clearCubes()
}

class Renderer: NSObject, MTKViewDelegate {
    static let shared = Renderer()
    
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var pipelineState: MTLRenderPipelineState!
    var depthState: MTLDepthStencilState!
    var vertexBuffer: MTLBuffer!
    var indexBuffer: MTLBuffer!
    var uniformBuffer: MTLBuffer!
    
    let maxCubes = 10000
    var cubes: [CubeInstance] = []
    let lock = NSRecursiveLock()
    var rotation: Float = 0
    var isPaused: Bool = false
    
    var cameraPosition = simd_float3(0, 0, 5)
    var cameraTarget = simd_float3(0, 0, 0)
    var cameraUp = simd_float3(0, 1, 0)
    
    private override init() {
        super.init()
        guard let device = MTLCreateSystemDefaultDevice() else { return }
        self.device = device
        self.commandQueue = device.makeCommandQueue()
        setupMetal()
        qjs_init(qjsDrawCubeCallback, qjsSetCameraCallback, qjsClearCubesCallback)
    }
    
    func setupMetal() {
        let library: MTLLibrary?
        if let defaultLib = device.makeDefaultLibrary() {
            library = defaultLib
        } else if let libraryURL = Bundle.main.url(forResource: "default", withExtension: "metallib") {
            library = try? device.makeLibrary(URL: libraryURL)
        } else {
            library = nil
        }
        
        if library == nil {
            NSLog("Renderer error: Could not load Metal library!")
        }
        
        let vertexFunction = library?.makeFunction(name: "vertex_main")
        let fragmentFunction = library?.makeFunction(name: "fragment_main")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[1].format = .float3
        vertexDescriptor.attributes[1].offset = 12
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.attributes[2].format = .float4
        vertexDescriptor.attributes[2].offset = 24
        vertexDescriptor.attributes[2].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = 40
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            NSLog("Renderer error: Failed to create pipeline state: \(error.localizedDescription)")
        }
        
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .less
        depthDescriptor.isDepthWriteEnabled = true
        depthState = device.makeDepthStencilState(descriptor: depthDescriptor)
        
        // Cube vertices (24 vertices for flat shading)
        let v0: simd_float3 = [-0.5, -0.5,  0.5]
        let v1: simd_float3 = [ 0.5, -0.5,  0.5]
        let v2: simd_float3 = [ 0.5,  0.5,  0.5]
        let v3: simd_float3 = [-0.5,  0.5,  0.5]
        let v4: simd_float3 = [-0.5, -0.5, -0.5]
        let v5: simd_float3 = [ 0.5, -0.5, -0.5]
        let v6: simd_float3 = [ 0.5,  0.5, -0.5]
        let v7: simd_float3 = [-0.5,  0.5, -0.5]
        
        let vertices = [
            // Front
            Vertex(position: v0, normal: [0, 0, 1], color: [1, 0, 0, 1]),
            Vertex(position: v1, normal: [0, 0, 1], color: [1, 0, 0, 1]),
            Vertex(position: v2, normal: [0, 0, 1], color: [1, 0, 0, 1]),
            Vertex(position: v3, normal: [0, 0, 1], color: [1, 0, 0, 1]),
            // Back
            Vertex(position: v5, normal: [0, 0, -1], color: [0, 1, 0, 1]),
            Vertex(position: v4, normal: [0, 0, -1], color: [0, 1, 0, 1]),
            Vertex(position: v7, normal: [0, 0, -1], color: [0, 1, 0, 1]),
            Vertex(position: v6, normal: [0, 0, -1], color: [0, 1, 0, 1]),
            // Left
            Vertex(position: v4, normal: [-1, 0, 0], color: [0, 0, 1, 1]),
            Vertex(position: v0, normal: [-1, 0, 0], color: [0, 0, 1, 1]),
            Vertex(position: v3, normal: [-1, 0, 0], color: [0, 0, 1, 1]),
            Vertex(position: v7, normal: [-1, 0, 0], color: [0, 0, 1, 1]),
            // Right
            Vertex(position: v1, normal: [1, 0, 0], color: [1, 1, 0, 1]),
            Vertex(position: v5, normal: [1, 0, 0], color: [1, 1, 0, 1]),
            Vertex(position: v6, normal: [1, 0, 0], color: [1, 1, 0, 1]),
            Vertex(position: v2, normal: [1, 0, 0], color: [1, 1, 0, 1]),
            // Top
            Vertex(position: v3, normal: [0, 1, 0], color: [1, 0, 1, 1]),
            Vertex(position: v2, normal: [0, 1, 0], color: [1, 0, 1, 1]),
            Vertex(position: v6, normal: [0, 1, 0], color: [1, 0, 1, 1]),
            Vertex(position: v7, normal: [0, 1, 0], color: [1, 0, 1, 1]),
            // Bottom
            Vertex(position: v4, normal: [0, -1, 0], color: [0, 1, 1, 1]),
            Vertex(position: v5, normal: [0, -1, 0], color: [0, 1, 1, 1]),
            Vertex(position: v1, normal: [0, -1, 0], color: [0, 1, 1, 1]),
            Vertex(position: v0, normal: [0, -1, 0], color: [0, 1, 1, 1])
        ]
        vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * 40, options: [])
        
        var indices: [UInt16] = []
        for i in 0..<6 {
            let offset = UInt16(i * 4)
            indices.append(contentsOf: [offset, offset+1, offset+2, offset, offset+2, offset+3])
        }
        indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * 2, options: [])
        uniformBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.stride * maxCubes, options: [])
    }
    
    func clearCubes() {
        lock.lock()
        cubes.removeAll()
        lock.unlock()
    }
    
    func resetJS() {
        clearCubes()
        qjs_reset(qjsDrawCubeCallback, qjsSetCameraCallback, qjsClearCubesCallback)
    }
    
    func addCube(x: Float, y: Float, z: Float, size: Float, r: Float, g: Float, b: Float, a: Float) {
        lock.lock()
        defer { lock.unlock() }
        cubes.append(CubeInstance(position: [x, y, z], size: size, color: [r, g, b, a]))
    }
    
    func setCamera(px: Float, py: Float, pz: Float, tx: Float, ty: Float, tz: Float) {
        lock.lock()
        defer { lock.unlock() }
        cameraPosition = [px, py, pz]
        cameraTarget = [tx, ty, tz]
    }
    
    func handleScroll(deltaX: Float, deltaY: Float) {
        qjs_send_event("scroll", Double(deltaX), Double(deltaY))
    }
    
    func handleDrag(dx: Float, dy: Float) {
        qjs_send_event("drag", Double(dx), Double(dy))
    }
    
    func handleMagnify(delta: Float) {
        qjs_send_event("zoom", Double(delta), 0)
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let pipelineState = pipelineState else { return }
        
        // Trigger JS frame callback
        qjs_on_frame(CACurrentMediaTime())
        
        if !isPaused {
            rotation += 0.02
        }
        
        let projectionMatrix = Math.perspectiveMatrix(fovy: Float.pi / 4, aspect: Float(view.drawableSize.width / view.drawableSize.height), near: 0.1, far: 100.0)
        
        lock.lock()
        let viewMatrix = Math.lookAt(eye: cameraPosition, target: cameraTarget, up: cameraUp)
        let currentCubes = cubes
        lock.unlock()
        let commandBuffer = commandQueue.makeCommandBuffer()
        let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        
        renderEncoder?.setRenderPipelineState(pipelineState)
        renderEncoder?.setDepthStencilState(depthState)
        renderEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        let cubeCount = min(currentCubes.count, maxCubes)
        if cubeCount == 0 {
            renderEncoder?.endEncoding()
            commandBuffer?.present(drawable)
            commandBuffer?.commit()
            return
        }
        
        let modelMatrix = Math.rotationMatrix(angle: rotation, axis: [1, 1, 0])
        let contents = uniformBuffer.contents().bindMemory(to: Uniforms.self, capacity: maxCubes)
        
        for (index, cube) in currentCubes.enumerated() {
            if index >= maxCubes { break }
            
            var translation = Math.identityMatrix()
            translation.columns.3 = [cube.position.x, cube.position.y, cube.position.z, 1.0]
            
            var scale = Math.identityMatrix()
            scale[0][0] = cube.size
            scale[1][1] = cube.size
            scale[2][2] = cube.size
            
            let mvp = projectionMatrix * viewMatrix * translation * modelMatrix * scale
            contents[index].modelViewProjectionMatrix = mvp
            contents[index].instanceColor = cube.color
        }
        
        renderEncoder?.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        renderEncoder?.drawIndexedPrimitives(type: MTLPrimitiveType.triangle, indexCount: 36, indexType: MTLIndexType.uint16, indexBuffer: indexBuffer, indexBufferOffset: 0, instanceCount: cubeCount)
        
        renderEncoder?.endEncoding()
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
    }
}
