import RealityKit
import AppKit
import Combine
import QuartzCore
import simd

class RealityARView: ARView {
    private var dragStartedInContent = false
    
    override func scrollWheel(with event: NSEvent) {
        RealityRenderer.shared.handleScroll(deltaX: Float(event.scrollingDeltaX), deltaY: Float(event.scrollingDeltaY))
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        // Check if the click is in the content area (below the title bar)
        if let window = self.window {
            let locationInWindow = event.locationInWindow
            let windowHeight = window.frame.height
            let titleBarHeight: CGFloat = 52
            // locationInWindow.y is from bottom, so title bar is at top
            dragStartedInContent = locationInWindow.y < (windowHeight - titleBarHeight)
        } else {
            dragStartedInContent = true
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard dragStartedInContent else { return }
        RealityRenderer.shared.handleDrag(dx: Float(event.deltaX), dy: Float(event.deltaY))
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        dragStartedInContent = false
    }
    
    override func magnify(with event: NSEvent) {
        RealityRenderer.shared.handleMagnify(delta: Float(event.magnification))
    }
}

extension Float {
    var degreesToRadians: Float { self * .pi / 180 }
    var radiansToDegrees: Float { self * 180 / .pi }
}

extension simd_quatf {
    var eulerAngles: SIMD3<Float> {
        let simd_quat = self.vector
        let lw = simd_quat.w
        let lx = simd_quat.x
        let ly = simd_quat.y
        let lz = simd_quat.z
        
        let tx = atan2(2 * (lw * lx + ly * lz), 1 - 2 * (lx * lx + ly * ly))
        let ty = asin(max(-1, min(1, 2 * (lw * ly - lz * lx))))
        let tz = atan2(2 * (lw * lz + lx * ly), 1 - 2 * (ly * ly + lz * lz))
        
        return SIMD3<Float>(tx, ty, tz)
    }
    
    init(eulerAngles angles: SIMD3<Float>) {
        let c1 = cos(angles.y / 2)
        let s1 = sin(angles.y / 2)
        let c2 = cos(angles.z / 2)
        let s2 = sin(angles.z / 2)
        let c3 = cos(angles.x / 2)
        let s3 = sin(angles.x / 2)
        
        let qw = c1 * c2 * c3 - s1 * s2 * s3
        let qx = c1 * c2 * s3 + s1 * s2 * c3
        let qy = s1 * c2 * c3 + c1 * s2 * s3
        let qz = c1 * s2 * c3 - s1 * c2 * s3
        
        self.init(ix: qx, iy: qy, iz: qz, r: qw)
    }
}

struct EntityItem: Identifiable, Equatable {
    let id: String
    var name: String
    var position: SIMD3<Float>
    var rotation: SIMD3<Float>
    var scale: SIMD3<Float>
    var color: SIMD4<Float> = [1, 1, 1, 1]
    var metallic: Float = 0
    var roughness: Float = 0.5
    var physicsMode: String = "static"
    var isLocked: Bool = false
    
    static func == (lhs: EntityItem, rhs: EntityItem) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.position == rhs.position &&
               lhs.rotation == rhs.rotation &&
               lhs.scale == rhs.scale &&
               lhs.color == rhs.color &&
               lhs.metallic == rhs.metallic &&
               lhs.roughness == rhs.roughness &&
               lhs.physicsMode == rhs.physicsMode &&
               lhs.isLocked == rhs.isLocked
    }
}

class SceneModel: ObservableObject {
    static let shared = SceneModel()
    @Published var items: [EntityItem] = []
    
    func update(items newItems: [EntityItem]) {
        if items != newItems {
            items = newItems
        }
    }
}

class RealityRenderer: NSObject {
    static let shared = RealityRenderer()
    
    var arView: ARView?
    private var draggedEntity: Entity?
    private var previousPhysicsMode: PhysicsBodyMode?
    private var dragPlane: Float = 0
    private var dragOffset: SIMD3<Float> = .zero
    private var entities: [String: Entity] = [:]
    private var lockedEntities: Set<String> = []
    private let rootAnchor = AnchorEntity(world: .zero)
    private let camera = PerspectiveCamera()
    private let cameraAnchor = AnchorEntity(world: .zero)
    private var cancellables = Set<AnyCancellable>()
    private var lastInspectorUpdate: TimeInterval = 0
    
    // Camera Modes
    private var cameraMode: String = "free"
    private var orbitTheta: Float = Float(45.0).degreesToRadians // Yaw
    private var orbitPhi: Float = Float(30.0).degreesToRadians   // Pitch
    private var orbitDistance: Float = 15.0
    private var cameraTarget: SIMD3<Float> = .zero
    
    // Navigate Mode
    private var lookYaw: Float = 0
    private var lookPitch: Float = 0
    
    var isPaused: Bool = false
    
    private override init() {
        let view = RealityARView(frame: .zero)
        self.arView = view
        super.init()
        setupScene()
        
        arView?.environment.background = .color(.black)
        
        print("RealityRenderer: Initializing...")
        qjs_init(qjsSpawnCallback, qjsSetPositionCallback, qjsSetRotationCallback, qjsSetScaleCallback, qjsSetColorCallback, qjsRemoveCallback, qjsSetCameraCallback, qjsSetPhysicsCallback, qjsSetTextureCallback, qjsSetLockCallback, qjsAttachToCallback, qjsCameraModeCallback, qjsSetVelocityCallback)
        
        arView?.scene.publisher(for: SceneEvents.Update.self)
            .sink { [weak self] event in
                self?.update(time: event.deltaTime)
                
                // Update inspector data periodically
                let now = CACurrentMediaTime()
                if let self = self, now - self.lastInspectorUpdate > 0.2 {
                    self.lastInspectorUpdate = now
                    self.refreshSceneModel()
                }
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
        shadowSettings.shadowProjection = .automatic(maximumDistance: 40)
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
        cameraMode = "free" // Reset camera mode
        qjs_reset(qjsSpawnCallback, qjsSetPositionCallback, qjsSetRotationCallback, qjsSetScaleCallback, qjsSetColorCallback, qjsRemoveCallback, qjsSetCameraCallback, qjsSetPhysicsCallback, qjsSetTextureCallback, qjsSetLockCallback, qjsAttachToCallback, qjsCameraModeCallback, qjsSetVelocityCallback)
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
        
        refreshSceneModel()
        return id
    }
    
    private func refreshSceneModel() {
        var items: [EntityItem] = []
        for (id, entity) in entities {
            var item = EntityItem(
                id: id,
                name: entity.name,
                position: entity.position,
                rotation: entity.orientation.eulerAngles,
                scale: entity.scale,
                isLocked: lockedEntities.contains(id)
            )
            
            if let model = entity.components[ModelComponent.self],
               let material = model.materials.first as? PhysicallyBasedMaterial {
                let tint = material.baseColor.tint
                item.color = [Float(tint.redComponent), Float(tint.greenComponent), Float(tint.blueComponent), Float(tint.alphaComponent)]
                item.metallic = material.metallic.scale
                item.roughness = material.roughness.scale
            }
                // Extract RGBA from baseColor.tint
                // This is a bit simplified, but RealityKit materials are complex.
                // PhysicallyBasedMaterial doesn't easily expose the current color components as SIMD4.
                // We'll use a placeholder or assume we have it if we set it.
            
            if let physics = entity.components[PhysicsBodyComponent.self] {
                item.physicsMode = physics.mode == .static ? "static" : (physics.mode == .dynamic ? "dynamic" : "kinematic")
            }
            
            items.append(item)
        }
        
        DispatchQueue.main.async {
            SceneModel.shared.update(items: items)
        }
    }
    
    func updateFromInspector(item: EntityItem) {
        guard let entity = entities[item.id] else { return }
        
        entity.position = item.position
        entity.orientation = .init(eulerAngles: item.rotation)
        entity.scale = item.scale
        
        let mode: PhysicsBodyMode
        switch item.physicsMode {
        case "dynamic": mode = .dynamic
        case "kinematic": mode = .kinematic
        default: mode = .static
        }
        
        if var physics = entity.components[PhysicsBodyComponent.self] {
            physics.mode = mode
            entity.components.set(physics)
        }
        
        if var model = entity.components[ModelComponent.self],
           var material = model.materials.first as? PhysicallyBasedMaterial {
            material.baseColor = .init(tint: .init(red: CGFloat(item.color.x), green: CGFloat(item.color.y), blue: CGFloat(item.color.z), alpha: CGFloat(item.color.w)))
            material.metallic = .init(floatLiteral: item.metallic)
            material.roughness = .init(floatLiteral: item.roughness)
            model.materials = [material]
            entity.components.set(model)
        }
        
        setLock(id: item.id, locked: item.isLocked ? 1 : 0)
    }
    
    func attachTo(id: String, parentId: String?) {
        guard let child = entities[id] else { return }
        
        if let pid = parentId, let parent = entities[pid] {
            parent.addChild(child, preservingWorldTransform: true)
        } else {
            rootAnchor.addChild(child, preservingWorldTransform: true)
        }
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
    
    func setLock(id: String, locked: Int) {
        if locked != 0 {
            lockedEntities.insert(id)
        } else {
            lockedEntities.remove(id)
        }
    }
    
    func setVelocity(id: String, vx: Float, vy: Float, vz: Float) {
        guard let entity = entities[id] else { return }
        var motion = entity.components[PhysicsMotionComponent.self] ?? PhysicsMotionComponent()
        motion.linearVelocity = [vx, vy, vz]
        entity.components.set(motion)
    }
    
    func setCameraMode(mode: String) {
        self.cameraMode = mode
        if mode == "cinematic" {
            // Initialize orbit from current position if possible
            let pos = cameraAnchor.position
            orbitDistance = simd_length(pos)
            orbitTheta = atan2(pos.x, pos.z)
            orbitPhi = atan2(pos.y, sqrt(pos.x*pos.x + pos.z*pos.z))
        } else if mode == "navigate" {
            lookYaw = 0
            lookPitch = 0
        }
    }

    func handleScroll(deltaX: Float, deltaY: Float) { 
        if draggedEntity != nil { return }
        
        if cameraMode == "cinematic" {
            orbitDistance -= deltaY * 0.1
            orbitDistance = max(1.0, min(100.0, orbitDistance))
            updateCinematicCamera()
        } else if cameraMode == "navigate" {
            let forward = cameraAnchor.transform.matrix.columns.2.xyz
            cameraAnchor.position -= forward * deltaY * 0.05
        } else {
            qjs_send_event("scroll", Double(deltaX), Double(deltaY)) 
        }
    }
    
    func handleDrag(dx: Float, dy: Float) { 
        if draggedEntity != nil { return }
        
        if cameraMode == "cinematic" {
            orbitTheta -= dx * 0.01
            orbitPhi += dy * 0.01
            orbitPhi = max(-Float.pi/2 + 0.1, min(Float.pi/2 - 0.1, orbitPhi))
            updateCinematicCamera()
        } else if cameraMode == "navigate" {
            // If Shift is pressed (how do we know? NSEvent.modifierFlags)
            // For now, let's assume a simpler navigate: drag = rotate
            lookYaw -= dx * 0.01
            lookPitch -= dy * 0.01
            lookPitch = max(-Float.pi/2 + 0.1, min(Float.pi/2 - 0.1, lookPitch))
            
            let qy = simd_quatf(angle: lookYaw, axis: [0, 1, 0])
            let qx = simd_quatf(angle: lookPitch, axis: [1, 0, 0])
            cameraAnchor.orientation = qy * qx
        } else {
            qjs_send_event("drag", Double(dx), Double(dy)) 
        }
    }
    
    func handleMagnify(delta: Float) { 
        if draggedEntity != nil { return }
        
        if cameraMode == "cinematic" {
            orbitDistance -= delta * 10
            orbitDistance = max(1.0, min(100.0, orbitDistance))
            updateCinematicCamera()
        } else if cameraMode == "navigate" {
            let forward = cameraAnchor.transform.matrix.columns.2.xyz
            cameraAnchor.position -= forward * delta * 5
        } else {
            qjs_send_event("zoom", Double(delta), 0) 
        }
    }
    
    private func updateCinematicCamera() {
        let x = orbitDistance * cos(orbitPhi) * sin(orbitTheta)
        let y = orbitDistance * sin(orbitPhi)
        let z = orbitDistance * cos(orbitPhi) * cos(orbitTheta)
        
        setCamera(px: x, py: y, pz: z, tx: cameraTarget.x, ty: cameraTarget.y, tz: cameraTarget.z)
    }
    
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
                // Find the ID of this entity
                if let id = entities.first(where: { $0.value === current })?.key {
                    if lockedEntities.contains(id) {
                        return // Locked!
                    }
                    break
                }
                current = current?.parent
            }
            
            if let target = current {
                self.draggedEntity = target
                
                // Set to kinematic if it has physics to avoid jitter while dragging
                if var physics = target.components[PhysicsBodyComponent.self] {
                    self.previousPhysicsMode = physics.mode
                    physics.mode = .kinematic
                    target.components[PhysicsBodyComponent.self] = physics
                } else {
                    self.previousPhysicsMode = nil
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
        
        // Restore physics mode to its original state
        if let previousMode = previousPhysicsMode,
           var physics = entity.components[PhysicsBodyComponent.self] {
            physics.mode = previousMode
            entity.components[PhysicsBodyComponent.self] = physics
        }
        
        draggedEntity = nil
        previousPhysicsMode = nil
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

let qjsSetLockCallback: SetLockCallback = { id, locked in
    guard let id = id else { return }
    RealityRenderer.shared.setLock(id: String(cString: id), locked: Int(locked))
}

let qjsAttachToCallback: AttachToCallback = { childId, parentId in
    guard let childId = childId else { return }
    let pid = parentId != nil ? String(cString: parentId!) : nil
    RealityRenderer.shared.attachTo(id: String(cString: childId), parentId: pid)
}

let qjsCameraModeCallback: SetCameraModeCallback = { mode in
    guard let mode = mode else { return }
    let modeStr = String(cString: mode)
    RealityRenderer.shared.setCameraMode(mode: modeStr)
}

let qjsSetVelocityCallback: SetVelocityCallback = { id, vx, vy, vz in
    guard let id = id else { return }
    let idStr = String(cString: id)
    RealityRenderer.shared.setVelocity(id: idStr, vx: vx, vy: vy, vz: vz)
}
