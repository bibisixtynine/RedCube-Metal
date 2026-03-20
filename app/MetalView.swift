import SwiftUI
import MetalKit

class InputMTKView: MTKView {
    override var acceptsFirstResponder: Bool { true }
    
    override func scrollWheel(with event: NSEvent) {
        Renderer.shared.handleScroll(deltaX: Float(event.scrollingDeltaX), deltaY: Float(event.scrollingDeltaY))
    }
    
    override func mouseDragged(with event: NSEvent) {
        Renderer.shared.handleDrag(dx: Float(event.deltaX), dy: Float(event.deltaY))
    }
    
    override func magnify(with event: NSEvent) {
        Renderer.shared.handleMagnify(delta: Float(event.magnification))
    }
}

struct MetalView: NSViewRepresentable {
    func makeNSView(context: Context) -> MTKView {
        let mtkView = InputMTKView()
        let renderer = Renderer.shared
        mtkView.device = renderer.device
        mtkView.delegate = renderer
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false
        mtkView.preferredFramesPerSecond = 60
        mtkView.depthStencilPixelFormat = .depth32Float
        mtkView.clearDepth = 1.0
        
        return mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var renderer: Renderer?
    }
}
