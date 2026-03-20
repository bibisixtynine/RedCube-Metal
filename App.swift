import SwiftUI

@main
struct MetalApp: App {
    static var scriptPath: String?
    
    init() {
        let args = CommandLine.arguments
        if args.count > 1 {
            MetalApp.scriptPath = args[1]
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var jsCode: String = ""
    @State private var isPaused: Bool = false
    @State private var hasInitialized: Bool = false
    
    var body: some View {
        HStack(spacing: 0) {
            MetalView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            VStack {
                Text("JavaScript Editor")
                    .font(.headline)
                    .padding(.top)
                
                TextEditor(text: $jsCode)
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 400)
                    .cornerRadius(8)
                    .padding()
                
                HStack {
                    Button("Run") {
                        runCode()
                    }
                    .keyboardShortcut("r", modifiers: .command)
                    
                    Button(isPaused ? "Resume" : "Pause") {
                        isPaused.toggle()
                        Renderer.shared.isPaused = isPaused
                    }
                    
                    Button("Reload") {
                        reloadScene()
                    }
                }
                .padding(.bottom)
            }
            .frame(width: 440)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .onAppear {
            if !hasInitialized {
                loadInitialCode()
                hasInitialized = true
            }
        }
    }
    
    func loadInitialCode() {
        print("loadInitialCode starting...")
        if let path = MetalApp.scriptPath,
           let content = try? String(contentsOfFile: path, encoding: .utf8) {
            jsCode = content
            print("Loaded code from file: \(path)")
        } else if let resourceURL = Bundle.main.url(forResource: "scene", withExtension: "js"),
                  let content = try? String(contentsOf: resourceURL, encoding: .utf8) {
            jsCode = content
            print("Loaded code from bundle: scene.js")
        } else {
            jsCode = "drawCube(0, 0, 1.0);"
            print("Using default code.")
        }
        
        print("loadInitialCode finished. Running code...")
        runCode()
    }
    
    func runCode() {
        print("runCode: Calling qjs_run_code...")
        qjs_run_code(jsCode)
        print("runCode: qjs_run_code returned.")
    }
    
    func reloadScene() {
        Renderer.shared.clearCubes()
        runCode()
    }
}
