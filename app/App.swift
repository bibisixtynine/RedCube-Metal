import SwiftUI
import UniformTypeIdentifiers
import AppKit
import RealityKit


@main
struct MetalApp: App {
    static var scriptPath: String?
    
    init() {
        let args = CommandLine.arguments
        if args.count > 1 {
            MetalApp.scriptPath = args[1]
        }
    }
    
    var body: some SwiftUI.Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class CodeStore: ObservableObject {
    static let shared = CodeStore()
    @Published var jsCode: String = ""
    weak var textView: NSTextView?
    
    func insertCode(_ text: String) {
        if let textView = textView {
            textView.insertText(text, replacementRange: textView.selectedRange())
        } else {
            // Fallback if no view is attached
            jsCode += "\n" + text
        }
    }
}

struct ContentView: View {
    @ObservedObject var codeStore = CodeStore.shared
    @State private var isPaused: Bool = false
    @State private var hasInitialized: Bool = false
    
    var body: some View {
        HStack(spacing: 0) {
            RealityKitView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            VStack {
                Text("JavaScript Editor")
                    .font(.headline)
                    .padding(.top)
                
                HStack {
                    Spacer()
                    Button(action: { loadFile() }) {
                        Image(systemName: "folder")
                    }
                    .help("Charger un fichier JS")
                    
                    Button(action: { saveFile() }) {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .help("Sauvegarder le fichier JS")
                    
                    Button(action: { HelpWindowManager.shared.toggle() }) {
                        Image(systemName: "questionmark.circle")
                    }
                    .help("Aide et exemples")
                    Spacer()
                }
                .padding(.bottom, 4)
                
                CodeEditor(text: $codeStore.jsCode)
                    .frame(width: 400)
                    .cornerRadius(8)
                    .padding()
                
                HStack {
                    Spacer()
                    Button(action: { runCode() }) {
                        Image(systemName: "play.fill")
                            .foregroundColor(.green)
                    }
                    .keyboardShortcut("r", modifiers: .command)
                    .help("Exécuter le code JS (Cmd+R)")
                    
                    Button(action: {
                        isPaused.toggle()
                        RealityRenderer.shared.isPaused = isPaused
                    }) {
                        Image(systemName: isPaused ? "play.circle" : "pause.fill")
                    }
                    .help(isPaused ? "Reprendre l'animation" : "Mettre en pause")
                    
                    Button(action: { reloadScene() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Recharger la scène")
                    Spacer()
                }
                .padding(.bottom)
            }
            .frame(width: 440)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .onAppear {
            // Save/Restore main window position
            DispatchQueue.main.async {
                if let window = NSApplication.shared.windows.first {
                    window.setFrameAutosaveName("MainWindow")
                }
            }
            
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
            codeStore.jsCode = content
            print("Loaded code from file: \(path)")
        } else if let resourceURL = Bundle.main.url(forResource: "default-example", withExtension: "js"),
                  let content = try? String(contentsOf: resourceURL, encoding: .utf8) {
            codeStore.jsCode = content
            print("Loaded code from bundle: default-example.js")
        } else {
            codeStore.jsCode = "drawCube(0, 0, 1.0);"
            print("Using default code.")
        }
        
        print("loadInitialCode finished. Running code...")
        runCode()
    }
    
    func runCode() {
        print("runCode: Calling qjs_run_code...")
        qjs_run_code(codeStore.jsCode)
        print("runCode: qjs_run_code returned.")
    }
    
    func reloadScene() {
        RealityRenderer.shared.resetJS()
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
                codeStore.jsCode = content
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
                try codeStore.jsCode.write(to: url, atomically: true, encoding: .utf8)
                print("Saved file to \(url.path)")
            } catch {
                print("Failed to save file: \(error)")
            }
        }
    }
}

struct RealityKitView: NSViewRepresentable {
    func makeNSView(context: Context) -> ARView {
        return RealityRenderer.shared.arView
    }
    
    func updateNSView(_ nsView: ARView, context: Context) {}
}

struct CodeEditor: NSViewRepresentable {
    @Binding var text: String
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        
        let textView = NSTextView(frame: .zero)
        textView.isRichText = false
        textView.allowsUndo = true
        textView.autoresizingMask = [.width]
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.delegate = context.coordinator
        
        scrollView.documentView = textView
        CodeStore.shared.textView = textView
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let textView = nsView.documentView as? NSTextView {
            if textView.string != text {
                textView.string = text
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditor
        
        init(_ parent: CodeEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            if let textView = notification.object as? NSTextView {
                self.parent.text = textView.string
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
                            title: "spawn(type, name?)",
                            description: "Crée une entité persistante ('box', 'sphere', 'plane'). Retourne un ID unique.",
                            example: "let id = spawn('box');\nsetPosition(id, 0, 0, 0);"
                        )
                        
                        helpSection(
                            title: "setPosition(id, x, y, z)",
                            description: "Déplace une entité à une position spécifique.",
                            example: "setPosition(id, 2, 0, -5);"
                        )
                        
                        helpSection(
                            title: "setRotation(id, x, y, z)",
                            description: "Oriente une entité avec des angles d'Euler (radians).",
                            example: "setRotation(id, 0.5, 3.14, 0);"
                        )
                        
                        helpSection(
                            title: "setColor(id, r, g, b, a, met?, rough?)",
                            description: "Change l'apparence. R, G, B, A de 0 à 1. Metallic et Roughness optionnels.",
                            example: "setColor(id, 1, 0, 0, 1, 0.8, 0.2); // Rouge métallique"
                        )
                        
                        helpSection(
                            title: "remove(id)",
                            description: "Supprime définitivement une entité de la scène.",
                            example: "remove(id);"
                        )
                        
                        helpSection(
                            title: "setCamera(px, py, pz, tx, ty, tz)",
                            description: "Positionne la caméra (px, py, pz) et définit la cible (tx, ty, tz).",
                            example: "setCamera(5, 5, 5, 0, 0, 0);"
                        )
                        
                        helpSection(
                            title: "requestAnimationFrame(callback)",
                            description: "Enregistre une boucle d'animation.",
                            example: "function loop(t) {\n  setRotation(id, 0, t * 0.001, 0);\n  requestAnimationFrame(loop);\n}\nloop(0);"
                        )
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 400, minHeight: 400) // Allow resizing
    }
    
    func helpSection(title: String, description: String, example: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.blue)
                Spacer()
                Button(action: {
                    CodeStore.shared.insertCode(example)
                }) {
                    Image(systemName: "plus.square.on.square")
                        .help("Insérer à la position du curseur")
                }
                .buttonStyle(.plain)
            }
            
            Text(description)
                .font(.body)
            
            VStack(alignment: .leading) {
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
                styleMask: [.titled, .closable, .resizable, .miniaturizable, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.title = "Aide JavaScript"
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.contentView = NSHostingView(rootView: HelpView())
            panel.center()
            panel.setFrameAutosaveName("HelpWindow")
            panel.isReleasedWhenClosed = false
            self.window = panel
        }
        window?.makeKeyAndOrderFront(nil)
    }
}
