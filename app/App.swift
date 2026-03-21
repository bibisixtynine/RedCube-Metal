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
    
    func runCode() {
        print("CodeStore: Running code...")
        qjs_run_code(jsCode)
    }
    
    func reloadScene() {
        print("CodeStore: Reloading scene...")
        RealityRenderer.shared.resetJS()
        runCode()
    }
    
    func loadFile(from path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        if let content = try? String(contentsOf: url, encoding: .utf8) {
            DispatchQueue.main.async {
                self.jsCode = content
            }
            return true
        }
        return false
    }
    
    func saveFile(to path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        do {
            try jsCode.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            print("Failed to save file: \(error)")
            return false
        }
    }
}

struct ContentView: View {
    @ObservedObject var codeStore = CodeStore.shared
    @State private var isPaused = false
    @State private var isDraggingObject = false
    @State private var hasInitialized = false
    
    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                RealityKitView()
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !isDraggingObject {
                                    RealityRenderer.shared.startDragging(at: value.startLocation)
                                    isDraggingObject = true
                                }
                                RealityRenderer.shared.updateDragging(at: value.location)
                            }
                            .onEnded { _ in
                                RealityRenderer.shared.endDragging()
                                isDraggingObject = false
                            }
                    )
                
                if isPaused {
                    Rectangle()
                        .fill(Color.black.opacity(0.5))
                        .overlay(
                            Image(systemName: "pause.circle.fill")
                                .resizable()
                                .frame(width: 100, height: 100)
                                .foregroundColor(.white)
                        )
                }
            }
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
                    
                    Button(action: { DebugWindowManager.shared.toggle() }) {
                        Image(systemName: "ladybug")
                    }
                    .help("Debug Réseau")
                    
                    Button(action: { CLIWindowManager.shared.toggle() }) {
                        Image(systemName: "terminal")
                    }
                    .help("Terminal JS")
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
        setupAPIServer()
    }
    
    func setupAPIServer() {
        let server = APIServer.shared
        server.onRunJS = { code in
            qjs_run_code(code)
        }
        server.onReload = {
            codeStore.reloadScene()
        }
        server.onRunEditorCode = {
            codeStore.runCode()
        }
        server.onTogglePause = {
            isPaused.toggle()
            RealityRenderer.shared.isPaused = isPaused
        }
        server.onLoadPath = { path in
            codeStore.loadFile(from: path)
        }
        server.onSavePath = { path in
            codeStore.saveFile(to: path)
        }
        server.onGetHelp = {
            // Basic help for now, could be more elaborate
            return "Available functions: spawn, setPosition, setRotation, setScale, setColor, remove, setCamera, setPhysics, setTexture, requestAnimationFrame"
        }
        server.onCallFunction = { call in
            qjs_run_code(call)
        }
        server.onTakeScreenshot = { completion in
            RealityRenderer.shared.takeScreenshot(completion: completion)
        }
        server.start()
    }
    
    func runCode() {
        codeStore.runCode()
    }
    
    func reloadScene() {
        codeStore.reloadScene()
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
        return RealityRenderer.shared.arView!
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
                            title: "setPhysics(id, mode)",
                            description: "Active la physique ('static' ou 'dynamic').",
                            example: "setPhysics(id, 'dynamic');"
                        )
                        
                        helpSection(
                            title: "setTexture(id, name)",
                            description: "Applique une texture (ex: 'grid').",
                            example: "setTexture(id, 'grid');"
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

                        helpSection(
                            title: "_onEvent(type, x, y)",
                            description: "Hook global pour les interactions (drag, scroll, zoom).",
                            example: "globalThis._onEvent = function(type, x, y) {\n  if (type === 'drag') camRotY -= x * 0.01;\n};"
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

struct CLITextField: NSViewRepresentable {
    @Binding var text: String
    var onCommit: () -> Void
    var onUpArrow: () -> Void
    var onDownArrow: () -> Void
    var onTab: () -> Void
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.delegate = context.coordinator
        textField.isBezeled = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textField.placeholderString = "Commande JS..."
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: CLITextField
        
        init(_ parent: CLITextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.moveUp(_:)) {
                parent.onUpArrow()
                return true
            } else if commandSelector == #selector(NSResponder.moveDown(_:)) {
                parent.onDownArrow()
                return true
            } else if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onCommit()
                return true
            } else if commandSelector == #selector(NSResponder.insertTab(_:)) {
                parent.onTab()
                return true
            }
            return false
        }
    }
}

struct CLIView: View {
    @State private var input: String = ""
    @State private var log: [CLILine] = []
    
    struct CLILine: Identifiable {
        let id = UUID()
        let text: String
        let isResponse: Bool
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(log) { line in
                            Text(line.isResponse ? "← \(line.text)" : "→ \(line.text)")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(line.isResponse ? .blue : .primary)
                                .textSelection(.enabled)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id("bottom")
                }
                .onChange(of: log.count) { _ in
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: input) { newValue in
                updateSuggestions(for: newValue)
            }
            .background(Color.black.opacity(0.05))
            
            if let doc = currentHelp {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(doc.signature)
                            .font(.system(.body, design: .monospaced))
                            .bold()
                            .foregroundColor(.primary)
                        Spacer()
                        Button(action: { currentHelp = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text(doc.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 2)
                    
                    if !doc.parameters.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(doc.parameters) { param in
                                HStack(alignment: .top) {
                                    Text("• \(param.name):")
                                        .font(.system(.caption, design: .monospaced))
                                        .bold()
                                        .frame(width: 100, alignment: .leading)
                                    Text(param.desc)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding(10)
                .background(Color(NSColor.windowBackgroundColor))
                .transition(.opacity)
            } else if !suggestions.isEmpty {
                Divider()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Text(suggestion)
                                .font(.system(.caption, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                                .onTapGesture {
                                    applySuggestion(suggestion)
                                }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            Divider()
            
            HStack {
                Text(">")
                    .font(.system(.body, design: .monospaced))
                    .bold()
                CLITextField(text: $input, onCommit: {
                    sendCommand()
                }, onUpArrow: {
                    navigateHistory(direction: -1)
                }, onDownArrow: {
                    navigateHistory(direction: 1)
                }, onTab: {
                    handleAutocomplete()
                })
                .frame(height: 22)
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 300)
    }
    
    @State private var history: [String] = []
    @State private var historyIndex: Int = -1
    @State private var tempInput: String = ""
    @State private var suggestions: [String] = []
    @State private var currentHelp: FunctionDoc? = nil
    
    let jsFunctions = ["spawn", "setPosition", "setRotation", "setScale", "setColor", "remove", "setCamera", "setPhysics", "setTexture", "requestAnimationFrame", "console.log", "lock", "unlock"]
    
    struct FunctionDoc {
        let signature: String
        let description: String
        let parameters: [ParamDoc]
        
        struct ParamDoc: Identifiable {
            let id = UUID()
            let name: String
            let desc: String
        }
    }
    
    let jsFunctionHelp: [String: FunctionDoc] = [
        "spawn": FunctionDoc(
            signature: "spawn(type, name)",
            description: "Spawns a new 3D entity and returns an interactive object.",
            parameters: [
                .init(name: "type", desc: "'box', 'sphere', 'cone', etc."),
                .init(name: "name", desc: "Optional debug name")
            ]),
        "setPosition": FunctionDoc(
            signature: "entity.setPosition(x, y, z)",
            description: "Sets the entity's position in world space.",
            parameters: [
                .init(name: "x, y, z", desc: "Position coordinates")
            ]),
        "setRotation": FunctionDoc(
            signature: "entity.setRotation(x, y, z)",
            description: "Sets the entity's rotation (Euler angles in radians).",
            parameters: [
                .init(name: "x, y, z", desc: "Rotation angles")
            ]),
        "setScale": FunctionDoc(
            signature: "entity.setScale(x, y, z)",
            description: "Sets the entity's scale multiplier.",
            parameters: [
                .init(name: "x, y, z", desc: "Scale factors")
            ]),
        "setColor": FunctionDoc(
            signature: "entity.setColor(r, g, b, a, metallic, roughness)",
            description: "Sets the material color and properties.",
            parameters: [
                .init(name: "r, g, b, a", desc: "RGBA values (0.0 to 1.0)"),
                .init(name: "metallic", desc: "Metallic factor (0.0 to 1.0)"),
                .init(name: "roughness", desc: "Roughness factor (0.0 to 1.0)")
            ]),
        "remove": FunctionDoc(
            signature: "entity.remove()",
            description: "Removes the entity from the scene.",
            parameters: []),
        "setCamera": FunctionDoc(
            signature: "setCamera(x, y, z, tx, ty, tz)",
            description: "Positions the camera and its look-at target.",
            parameters: [
                .init(name: "x, y, z", desc: "Camera position"),
                .init(name: "tx, ty, tz", desc: "Target point")
            ]),
        "setPhysics": FunctionDoc(
            signature: "entity.setPhysics(mode)",
            description: "Changes the physics mode of the entity.",
            parameters: [
                .init(name: "mode", desc: "'static', 'dynamic', or 'kinematic'")
            ]),
        "setTexture": FunctionDoc(
            signature: "entity.setTexture(name)",
            description: "Applies a texture from the bundle (e.g. 'grid').",
            parameters: [
                .init(name: "name", desc: "Texture filename")
            ]),
        "requestAnimationFrame": FunctionDoc(
            signature: "requestAnimationFrame(callback)",
            description: "Schedules a function for the next frame update.",
            parameters: [
                .init(name: "callback", desc: "Function to execute")
            ]),
        "console.log": FunctionDoc(
            signature: "console.log(msg)",
            description: "Prints a message to the debug log.",
            parameters: [
                .init(name: "msg", desc: "Message text")
            ]),
        "lock": FunctionDoc(
            signature: "entity.lock()",
            description: "Prevents the entity from being picked or dragged.",
            parameters: []),
        "unlock": FunctionDoc(
            signature: "entity.unlock()",
            description: "Allows the entity to be picked and dragged again.",
            parameters: [])
    ]

    func updateSuggestions(for text: String) {
        // Handle help for function calls (text containing parenthesis)
        if let parenRange = text.range(of: "(", options: .backwards) {
            let beforeParen = text[..<parenRange.lowerBound]
            let parts = beforeParen.components(separatedBy: CharacterSet(charactersIn: " (.;"))
            if let lastWord = parts.last?.trimmingCharacters(in: .whitespaces), 
               jsFunctions.contains(lastWord) {
                suggestions = []
                currentHelp = jsFunctionHelp[lastWord]
                return
            }
        }
        
        let parts = text.components(separatedBy: CharacterSet(charactersIn: " (.;"))
        guard let lastPart = parts.last, !lastPart.isEmpty else {
            suggestions = []
            currentHelp = nil
            return
        }
        
        let matches = jsFunctions.filter { $0.lowercased().hasPrefix(lastPart.lowercased()) }
        if matches.count > 1 || (matches.count == 1 && matches[0] != lastPart) {
            suggestions = matches
            currentHelp = nil
        } else if matches.count == 1 && matches[0] == lastPart {
            suggestions = []
            currentHelp = jsFunctionHelp[matches[0]]
        } else {
            suggestions = []
            currentHelp = nil
        }
    }
    
    func applySuggestion(_ suggestion: String) {
        let parts = input.components(separatedBy: CharacterSet(charactersIn: " (.;"))
        guard let lastPart = parts.last else { return }
        let prefix = String(input.dropLast(lastPart.count))
        input = prefix + suggestion + "("
        suggestions = []
        currentHelp = jsFunctionHelp[suggestion]
    }

    func handleAutocomplete() {
        if let first = suggestions.first {
            applySuggestion(first)
        } else {
            // Fallback to the old logic if suggestions are empty but maybe we can still find something
            let parts = input.components(separatedBy: CharacterSet(charactersIn: " (.;"))
            guard let lastPart = parts.last, !lastPart.isEmpty else { return }
            let matches = jsFunctions.filter { $0.lowercased().hasPrefix(lastPart.lowercased()) }
            if let firstMatch = matches.first {
                applySuggestion(firstMatch)
            }
        }
    }

    func navigateHistory(direction: Int) {
        if history.isEmpty { return }
        
        if historyIndex == -1 {
            tempInput = input
        }
        
        let newIndex = historyIndex + direction
        if newIndex >= -1 && newIndex < history.count {
            historyIndex = newIndex
            if historyIndex == -1 {
                input = tempInput
            } else {
                // Return in reverse order (last command first)
                input = history[history.count - 1 - historyIndex]
            }
        }
    }
    
    func sendCommand() {
        let command = input
        guard !command.isEmpty else { return }
        
        if history.last != command {
            history.append(command)
        }
        historyIndex = -1
        currentHelp = nil
        
        log.append(CLILine(text: command, isResponse: false))
        input = ""
        
        guard let url = URL(string: "http://localhost:8080/js") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = command.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    log.append(CLILine(text: "Error: \(error.localizedDescription)", isResponse: true))
                } else if let data = data, let responseStr = String(data: data, encoding: .utf8) {
                    log.append(CLILine(text: responseStr, isResponse: true))
                }
            }
        }.resume()
    }
}

class CLIWindowManager {
    static let shared = CLIWindowManager()
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
                contentRect: NSRect(x: 300, y: 300, width: 600, height: 400),
                styleMask: [.titled, .closable, .resizable, .miniaturizable, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.title = "Terminal JS"
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.contentView = NSHostingView(rootView: CLIView())
            panel.center()
            panel.setFrameAutosaveName("CLIWindow")
            panel.isReleasedWhenClosed = false
            self.window = panel
        }
        window?.makeKeyAndOrderFront(nil)
    }
}
struct DebugView: View {
    @ObservedObject var commandLog = CommandLog.shared
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Debug Réseau - Commandes Reçues")
                    .font(.headline)
                Spacer()
                Button("Effacer") {
                    commandLog.entries.removeAll()
                }
            }
            .padding(10)
            .background(Color(NSColor.windowBackgroundColor))
            
            List {
                ForEach(commandLog.entries, id: \.self) { entry in
                    Text(entry)
                        .font(.system(.body, design: .monospaced))
                        .padding(.vertical, 2)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}

class DebugWindowManager {
    static let shared = DebugWindowManager()
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
                contentRect: NSRect(x: 200, y: 200, width: 500, height: 400),
                styleMask: [.titled, .closable, .resizable, .miniaturizable, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.title = "Debug Réseau"
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.contentView = NSHostingView(rootView: DebugView())
            panel.center()
            panel.setFrameAutosaveName("DebugWindow")
            panel.isReleasedWhenClosed = false
            self.window = panel
        }
        window?.makeKeyAndOrderFront(nil)
    }
}
