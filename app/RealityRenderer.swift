import RealityKit
import AppKit
import Combine

class RealityARView: ARView {
    override func scrollWheel(with event: NSEvent) {
        RealityRenderer.shared.handleScroll(deltaX: Float(event.scrollingDeltaX), deltaY: Float(event.scrollingDeltaY))
    }
    
    override func mouseDragged(with event: NSEvent) {
        RealityRenderer.shared.handleDrag(dx: Float(event.deltaX), dy: Float(event.deltaY))
    }
    
    override func magnify(with event: NSEvent) {
        RealityRenderer.shared.handleMagnify(delta: Float(event.magnification))
    }
}

class RealityRenderer: NSObject {
    static let shared = RealityRenderer()
    
    var arView: ARView?
    private var draggedEntity: Entity?
    private var dragPlane: Float = 0
    private var dragOffset: SIMD3<Float> = .zero
    private var entities: [String: Entity] = [:]
    private let rootAnchor = AnchorEntity(world: .zero)
    private let camera = PerspectiveCamera()
    private let cameraAnchor = AnchorEntity(world: .zero)
    private var cancellables = Set<AnyCancellable>()
    
    var isPaused: Bool = false
    
    private override init() {
        let view = RealityARView(frame: .zero)
        self.arView = view
        super.init()
        setupScene()
        
        arView?.environment.background = .color(.black)
        
        print("RealityRenderer: Initializing...")
        qjs_init(qjsSpawnCallback, qjsSetPositionCallback, qjsSetRotationCallback, qjsSetScaleCallback, qjsSetColorCallback, qjsRemoveCallback, qjsSetCameraCallback, qjsSetPhysicsCallback, qjsSetTextureCallback)
        
        arView?.scene.publisher(for: SceneEvents.Update.self)
            .sink { [weak self] event in
                self?.update(time: event.deltaTime)
            }
            .store(in: &cancellables)
        print("RealityRenderer: Initialized.")
    }
    
    func setupScene() {
        arView?.scene.addAnchor(rootAnchor)
        cameraAnchor.addChild(camera)
        arView?.scene.addAnchor(cameraAnchor)
        
        camera.camera.fieldOfViewInDegrees = 60
        camera.position = [0, 0, 0]
        
        // Studio Lighting with Shadows
        let sun = DirectionalLight()
        sun.light.intensity = 6000
        sun.light.color = .white
        
        // Configuration Robuste des ombres (plus nettes)
        var shadowSettings = DirectionalLightComponent.Shadow()
        shadowSettings.maximumDistance = 40
        shadowSettings.depthBias = 0.01
        sun.shadow = shadowSettings
        
        let sunAnchor = AnchorEntity(world: [20, 30, 20])
        sunAnchor.look(at: .zero, from: [20, 30, 20], relativeTo: nil)
        sunAnchor.addChild(sun)
        arView?.scene.addAnchor(sunAnchor)
        
        let fill = DirectionalLight()
        fill.light.intensity = 500
        fill.light.color = .init(red: 0.7, green: 0.8, blue: 1.0, alpha: 1.0)
        let fillAnchor = AnchorEntity(world: .zero)
        fillAnchor.look(at: .zero, from: [-20, 15, -20], relativeTo: nil)
        fillAnchor.addChild(fill)
        arView?.scene.addAnchor(fillAnchor)
    }
    
    func resetJS() {
        for entity in entities.values {
            entity.removeFromParent()
        }
        entities.removeAll()
        qjs_reset(qjsSpawnCallback, qjsSetPositionCallback, qjsSetRotationCallback, qjsSetScaleCallback, qjsSetColorCallback, qjsRemoveCallback, qjsSetCameraCallback, qjsSetPhysicsCallback, qjsSetTextureCallback)
    }
    
    func spawn(type: String, name: String) -> String {
        let id = UUID().uuidString
        let entity: Entity
        
        switch type {
        case "sphere":
            let mesh = MeshResource.generateSphere(radius: 0.5)
            entity = ModelEntity(mesh: mesh, materials: [SimpleMaterial(color: .white, isMetallic: false)])
            entity.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.5)]))
        case "plane":
            let mesh = MeshResource.generatePlane(width: 1, depth: 1)
            entity = ModelEntity(mesh: mesh, materials: [SimpleMaterial(color: .white, isMetallic: false)])
            entity.components.set(CollisionComponent(shapes: [.generateBox(size: [1, 0.01, 1])]))
        default: // box with rounded corners
            let mesh = MeshResource.generateBox(size: 1.0, cornerRadius: 0.15)
            entity = ModelEntity(mesh: mesh, materials: [SimpleMaterial(color: .white, isMetallic: false)])
            entity.components.set(CollisionComponent(shapes: [.generateBox(size: [1, 1, 1])]))
        }
        
        entity.name = name.isEmpty ? id : name
        rootAnchor.addChild(entity)
        entities[id] = entity
        return id
    }
    
    func setPosition(id: String, x: Float, y: Float, z: Float) {
        entities[id]?.position = [x, y, z]
    }
    
    func setRotation(id: String, x: Float, y: Float, z: Float) {
        entities[id]?.orientation = simd_quatf(angle: 0, axis: [1, 0, 0]) // Simplified for now
        // To do full Euler to Quat conversion if needed
        let qx = simd_quatf(angle: x, axis: [1, 0, 0])
        let qy = simd_quatf(angle: y, axis: [0, 1, 0])
        let qz = simd_quatf(angle: z, axis: [0, 0, 1])
        entities[id]?.orientation = qz * qy * qx
    }
    
    func setScale(id: String, x: Float, y: Float, z: Float) {
        entities[id]?.scale = [x, y, z]
    }
    
    func setColor(id: String, r: Float, g: Float, b: Float, a: Float, metallic: Float, roughness: Float) {
        guard let modelEntity = entities[id] as? ModelEntity else { return }
        let color = NSColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a))
        var material = SimpleMaterial(color: color, isMetallic: metallic > 0)
        material.roughness = MaterialScalarParameter(floatLiteral: roughness)
        modelEntity.model?.materials = [material]
    }
    
    func remove(id: String) {
        entities[id]?.removeFromParent()
        entities.removeValue(forKey: id)
    }
    
    func setCamera(px: Float, py: Float, pz: Float, tx: Float, ty: Float, tz: Float) {
        cameraAnchor.position = [px, py, pz]
        cameraAnchor.look(at: [tx, ty, tz], from: [px, py, pz], relativeTo: nil)
    }
    
    func setPhysics(id: String, mode: String) {
        guard let entity = entities[id] as? ModelEntity else {
            print("setPhysics: Entity \(id) not found or not a ModelEntity")
            return
        }
        
        var body = PhysicsBodyComponent()
        if mode == "dynamic" {
            body.mode = .dynamic
            body.massProperties = .init(mass: 1.0)
        } else {
            body.mode = .static
        }
        entity.components.set(body)
        
        if mode == "dynamic" {
            entity.components.set(PhysicsMotionComponent())
        }
    }
    
    func setTexture(id: String, name: String) {
        guard let entity = entities[id] as? ModelEntity else { return }
        
        let filename = name.contains(".") ? name : "\(name).png"
        // Try to load from bundle
        guard let url = Bundle.main.url(forResource: filename.replacingOccurrences(of: ".png", with: ""), withExtension: "png"),
              let texture = try? TextureResource.load(contentsOf: url) else {
            print("Failed to load texture: \(name)")
            return
        }
        
        var material = SimpleMaterial()
        material.color = .init(tint: .white, texture: .init(texture))
        entity.model?.materials = [material]
    }
    
    func handleScroll(deltaX: Float, deltaY: Float) { qjs_send_event("scroll", Double(deltaX), Double(deltaY)) }
    func handleDrag(dx: Float, dy: Float) { qjs_send_event("drag", Double(dx), Double(dy)) }
    func handleMagnify(delta: Float) { qjs_send_event("zoom", Double(delta), 0) }
    
    private func update(time: Double) {
        if isPaused { return }
        qjs_on_frame(CACurrentMediaTime())
    }
    
    func takeScreenshot(completion: @escaping (Data?) -> Void) {
        DispatchQueue.main.async {
            guard let arView = self.arView else {
                completion(nil)
                return
            }
            let size = arView.bounds.size
            guard size.width > 0 && size.height > 0 else {
                completion(nil)
                return
            }
            
            // On macOS, we can use the window backing or a bitmap rep.
            // RealityKit handles its own rendering, but the view remains an NSView.
            guard let bitmapRep = arView.bitmapImageRepForCachingDisplay(in: arView.bounds) else {
                completion(nil)
                return
            }
            arView.cacheDisplay(in: arView.bounds, to: bitmapRep)
            
            if let data = bitmapRep.representation(using: .png, properties: [:]) {
                completion(data)
            } else {
                completion(nil)
            }
        }
    }
    
    // MARK: - Mouse Interaction (Picking & Dragging)
    
    func startDragging(at point: CGPoint) {
        guard let arView = arView else { return }
        let adjustedPoint = CGPoint(x: point.x, y: arView.bounds.height - point.y)
        
        // Entity picking
        if let entity = arView.entity(at: adjustedPoint) {
            // Traverse up to find a draggable entity (e.g. one we spawned)
            var current: Entity? = entity
            while current != nil {
                if entities.values.contains(where: { $0 === current }) {
                    break
                }
                current = current?.parent
            }
            
            if let target = current {
                self.draggedEntity = target
                
                // Set to kinematic if it has physics to avoid jitter while dragging
                if var physics = target.components[PhysicsBodyComponent.self] {
                    physics.mode = .kinematic
                    target.components[PhysicsBodyComponent.self] = physics
                }
                
                // Calculate drag plane (distance from camera)
                let cameraTransform = arView.cameraTransform
                let entityPos = target.position(relativeTo: nil)
                let camToEntity = entityPos - cameraTransform.translation
                let planeNormal = simd_normalize(cameraTransform.matrix.columns.2.xyz) // Forward vector
                dragPlane = simd_dot(camToEntity, planeNormal)
                
                // Initial offset
                if let worldPos = arView.unproject(adjustedPoint, ontoPlane: cameraTransform.matrix, distance: dragPlane) {
                    dragOffset = entityPos - worldPos
                }
            }
        }
    }
    
    func updateDragging(at point: CGPoint) {
        guard let arView = arView, let entity = draggedEntity else { return }
        let adjustedPoint = CGPoint(x: point.x, y: arView.bounds.height - point.y)
        
        let cameraTransform = arView.cameraTransform
        if let worldPos = arView.unproject(adjustedPoint, ontoPlane: cameraTransform.matrix, distance: dragPlane) {
            entity.setPosition(worldPos + dragOffset, relativeTo: nil)
        }
    }
    
    func endDragging() {
        guard let entity = draggedEntity else { return }
        
        // Restore physics mode to dynamic if it was kinematic
        if var physics = entity.components[PhysicsBodyComponent.self] {
            physics.mode = .dynamic
            entity.components[PhysicsBodyComponent.self] = physics
        }
        
        draggedEntity = nil
    }
}

extension ARView {
    func unproject(_ point: CGPoint, ontoPlane planeTransform: simd_float4x4, distance: Float) -> SIMD3<Float>? {
        guard let ray = self.ray(through: point) else { return nil }
        
        // Plane is defined by a point (camera position + distance * forward) and normal (forward)
        let planeNormal = simd_normalize(planeTransform.columns.2.xyz)
        let planePoint = planeTransform.translation + planeNormal * distance
        
        // Ray-plane intersection: t = dot(planePoint - rayOrigin, planeNormal) / dot(rayDirection, planeNormal)
        let denom = simd_dot(ray.direction, planeNormal)
        if abs(denom) > 0.0001 {
            let t = simd_dot(planePoint - ray.origin, planeNormal) / denom
            return ray.origin + t * ray.direction
        }
        return nil
    }
    
    var cameraTransform: Transform {
        // Our camera is always on the cameraAnchor
        return RealityRenderer.shared.cameraTransformProperty
    }
}

extension RealityRenderer {
    var cameraTransformProperty: Transform {
        return cameraAnchor.transform
    }
}

extension simd_float4x4 {
    var translation: SIMD3<Float> {
        return [columns.3.x, columns.3.y, columns.3.z]
    }
}

extension simd_float4 {
    var xyz: SIMD3<Float> {
        return [x, y, z]
    }
}

// Fixed C strings for IDs
private var idBuffers: [String: UnsafeMutablePointer<Int8>] = [:]

// C Callbacks
let qjsSpawnCallback: SpawnCallback = { type, name in
    let typeStr = String(cString: type!)
    let nameStr = String(cString: name!)
    let id = RealityRenderer.shared.spawn(type: typeStr, name: nameStr)
    
    if let existing = idBuffers[id] { return existing }
    let buffer = strdup(id)!
    idBuffers[id] = buffer
    return buffer
}

let qjsSetPositionCallback: SetPositionCallback = { id, x, y, z in
    RealityRenderer.shared.setPosition(id: String(cString: id!), x: x, y: y, z: z)
}

let qjsSetRotationCallback: SetRotationCallback = { id, x, y, z in
    RealityRenderer.shared.setRotation(id: String(cString: id!), x: x, y: y, z: z)
}

let qjsSetScaleCallback: SetScaleCallback = { id, x, y, z in
    RealityRenderer.shared.setScale(id: String(cString: id!), x: x, y: y, z: z)
}

let qjsSetColorCallback: SetColorCallback = { id, r, g, b, a, metallic, roughness in
    RealityRenderer.shared.setColor(id: String(cString: id!), r: r, g: g, b: b, a: a, metallic: metallic, roughness: roughness)
}

let qjsRemoveCallback: RemoveCallback = { id in
    let idStr = String(cString: id!)
    RealityRenderer.shared.remove(id: idStr)
    if let buffer = idBuffers[idStr] {
        free(buffer)
        idBuffers.removeValue(forKey: idStr)
    }
}

let qjsSetCameraCallback: SetCameraCallback = { px, py, pz, tx, ty, tz in
    RealityRenderer.shared.setCamera(px: px, py: py, pz: pz, tx: tx, ty: ty, tz: tz)
}

let qjsSetPhysicsCallback: SetPhysicsCallback = { id, mode in
    guard let id = id, let mode = mode else { return }
    RealityRenderer.shared.setPhysics(id: String(cString: id), mode: String(cString: mode))
}

let qjsSetTextureCallback: SetTextureCallback = { id, name in
    guard let id = id, let name = name else { return }
    RealityRenderer.shared.setTexture(id: String(cString: id), name: String(cString: name))
}
