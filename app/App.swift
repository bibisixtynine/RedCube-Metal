import SwiftUI
import UniformTypeIdentifiers
import AppKit


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
                
                HStack {
                    Button("Load") { loadFile() }
                    Button("Save") { saveFile() }
                    Button("Help") { HelpWindowManager.shared.toggle() }
                }
                .padding(.bottom, 4)
                
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
        } else if let resourceURL = Bundle.main.url(forResource: "default-example", withExtension: "js"),
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
        Renderer.shared.resetJS()
        runCode()
    }
    
    func loadFile() {
        let panel = NSOpenPanel()
        if let jsType = UTType(filenameExtension: "js") {
            panel.allowedContentTypes = [jsType, .sourceCode, .plainText]
        } else {
            panel.allowedContentTypes = [.sourceCode, .plainText]
        }
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                jsCode = content
                print("Loaded file from \(url.path)")
            }
        }
    }
    
    func saveFile() {
        let panel = NSSavePanel()
        if let jsType = UTType(filenameExtension: "js") {
            panel.allowedContentTypes = [jsType, .sourceCode, .plainText]
        } else {
            panel.allowedContentTypes = [.sourceCode, .plainText]
        }
        panel.nameFieldStringValue = "scene.js"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try jsCode.write(to: url, atomically: true, encoding: .utf8)
                print("Saved file to \(url.path)")
            } catch {
                print("Failed to save file: \(error)")
            }
        }
    }
}

struct HelpView: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Documentation JavaScript")
                    .font(.headline)
                    .bold()
                Spacer()
            }
            .padding(10)
            .background(Color(NSColor.windowBackgroundColor))
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Group {
                        helpSection(
                            title: "drawCube(x, y, z, size)",
                            description: "Affiche un cube 3D à une position donnée avec une taille spécifique.",
                            example: "drawCube(0, 0, 0, 1.0);"
                        )
                        
                        helpSection(
                            title: "setCamera(px, py, pz, tx, ty, tz)",
                            description: "Positionne la caméra (px, py, pz) et définit le point qu'elle regarde (tx, ty, tz).",
                            example: "setCamera(5, 5, 5, 0, 0, 0);"
                        )
                        
                        helpSection(
                            title: "clearCubes()",
                            description: "Efface tous les cubes actuellement affichés. À utiliser au début de chaque frame pour l'animation.",
                            example: "clearCubes();"
                        )
                        
                        helpSection(
                            title: "requestAnimationFrame(callback)",
                            description: "Enregistre une fonction à appeler avant le prochain rendu d'image.",
                            example: "function loop(t) {\n  clearCubes();\n  drawCube(0, 0, 0, 1);\n  requestAnimationFrame(loop);\n}\nloop(0);"
                        )
                        
                        helpSection(
                            title: "Événements (_onEvent)",
                            description: "Définissez globalThis._onEvent = function(type, x, y) { ... } pour gérer scroll, drag et zoom.",
                            example: "globalThis._onEvent = function(type, x, y) {\n  if (type === 'scroll') console.log('Scroll: ' + x);\n};"
                        )
                    }
                }
                .padding()
            }
        }
        .frame(width: 600, height: 700)
    }
    
    func helpSection(title: String, description: String, example: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundColor(.blue)
            
            Text(description)
                .font(.body)
            
            VStack(alignment: .leading) {
                HStack {
                    Text("Exemple (cliquez pour copier) :")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                Text(example)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.1))
                    .cornerRadius(4)
                    .onTapGesture {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.writeObjects([example as NSString])
                    }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

class HelpWindowManager {
    static let shared = HelpWindowManager()
    private var window: NSPanel?
    
    func toggle() {
        if let window = window, window.isVisible {
            window.orderOut(nil)
        } else {
            open()
        }
    }
    
    func open() {
        if window == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 100, y: 100, width: 600, height: 700),
                styleMask: [.titled, .closable, .resizable, .utilityWindow, .hudWindow, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.title = "Aide JavaScript"
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.contentView = NSHostingView(rootView: HelpView())
            panel.center()
            self.window = panel
        }
        window?.makeKeyAndOrderFront(nil)
    }
}
