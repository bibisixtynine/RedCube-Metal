import MetalKit
import simd
import Foundation

struct Vertex {
    let position: simd_float3
    let color: simd_float4
}

struct CubeInstance {
    var position: simd_float3
    var size: Float
}

typealias DrawCubeCFunction = @convention(c) (Float, Float, Float) -> Void

let qjsDrawCubeCallback: DrawCubeCFunction = { x, y, size in
    Renderer.shared.addCube(x: x, y: y, size: size)
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
    
    var cubes: [CubeInstance] = []
    let lock = NSRecursiveLock()
    var rotation: Float = 0
    var isPaused: Bool = false
    
    private override init() {
        super.init()
        guard let device = MTLCreateSystemDefaultDevice() else { return }
        self.device = device
        self.commandQueue = device.makeCommandQueue()
        setupMetal()
        qjs_init(qjsDrawCubeCallback)
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
        vertexDescriptor.attributes[1].format = .float4
        vertexDescriptor.attributes[1].offset = 16
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = 32
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
        
        // Cube vertices
        let vertices = [
            Vertex(position: [-0.5, -0.5,  0.5], color: [1, 0, 0, 1]),
            Vertex(position: [ 0.5, -0.5,  0.5], color: [0, 1, 0, 1]),
            Vertex(position: [ 0.5,  0.5,  0.5], color: [0, 0, 1, 1]),
            Vertex(position: [-0.5,  0.5,  0.5], color: [1, 1, 0, 1]),
            Vertex(position: [-0.5, -0.5, -0.5], color: [1, 0, 1, 1]),
            Vertex(position: [ 0.5, -0.5, -0.5], color: [0, 1, 1, 1]),
            Vertex(position: [ 0.5,  0.5, -0.5], color: [1, 1, 1, 1]),
            Vertex(position: [-0.5,  0.5, -0.5], color: [0.5, 0.5, 0.5, 1])
        ]
        vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * 32, options: [])
        
        let indices: [UInt16] = [
            0, 1, 2, 2, 3, 0, 1, 5, 6, 6, 2, 1, 5, 4, 7, 7, 6, 5, 4, 0, 3, 3, 7, 4, 3, 2, 6, 6, 7, 3, 4, 5, 1, 1, 0, 4
        ]
        indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * 2, options: [])
        uniformBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.stride * 100, options: [])
    }
    
    func clearCubes() {
        lock.lock()
        cubes.removeAll()
        lock.unlock()
    }
    
    func addCube(x: Float, y: Float, size: Float) {
        lock.lock()
        defer { lock.unlock() }
        cubes.append(CubeInstance(position: [x, y, 0], size: size))
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let pipelineState = pipelineState else { return }
        
        if !isPaused {
            rotation += 0.02
        }
        
        let projectionMatrix = Math.perspectiveMatrix(fovy: Float.pi / 4, aspect: Float(view.drawableSize.width / view.drawableSize.height), near: 0.1, far: 100.0)
        
        let commandBuffer = commandQueue.makeCommandBuffer()
        let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        
        renderEncoder?.setRenderPipelineState(pipelineState)
        renderEncoder?.setDepthStencilState(depthState)
        renderEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        lock.lock()
        let currentCubes = cubes
        lock.unlock()
        
        for (index, cube) in currentCubes.enumerated() {
            if index >= 100 { break }
            
            let modelMatrix = Math.rotationMatrix(angle: rotation, axis: [1, 1, 0])
            var translation = Math.identityMatrix()
            translation.columns.3 = [cube.position.x, cube.position.y, cube.position.z - 5.0, 1.0]
            
            var scale = Math.identityMatrix()
            scale[0][0] = cube.size
            scale[1][1] = cube.size
            scale[2][2] = cube.size
            
            let mvp = projectionMatrix * translation * modelMatrix * scale
            
            let uniformOffset = index * MemoryLayout<Uniforms>.stride
            let ptr = uniformBuffer.contents().advanced(by: uniformOffset).bindMemory(to: Uniforms.self, capacity: 1)
            ptr.pointee.modelViewProjectionMatrix = mvp
            
            renderEncoder?.setVertexBuffer(uniformBuffer, offset: uniformOffset, index: 1)
            renderEncoder?.drawIndexedPrimitives(type: .triangle, indexCount: 36, indexType: .uint16, indexBuffer: indexBuffer, indexBufferOffset: 0)
        }
        
        renderEncoder?.endEncoding()
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
    }
}
