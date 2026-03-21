import SwiftUI
import UniformTypeIdentifiers
import AppKit
import RealityKit


struct ParamDoc: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let desc: String
}

struct FunctionDoc: Equatable {
    let signature: String
    let description: String
    let parameters: [ParamDoc]
}

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
        .windowToolbarStyle(.unified)
    }
}

class SyntaxHighlighter {
    static let shared = SyntaxHighlighter()
    
    private let keywords = Set([
        "var", "let", "const", "function", "async", "await", "return", "if", "else", "for", "while", "do", "switch", "case", "default", "break", "continue", "try", "catch", "finally", "throw", "class", "extends", "super", "this", "new", "static", "instanceof", "typeof", "void", "delete", "in", "of", "import", "export", "from", "as", "get", "set"
    ])
    
    private let literals = Set(["true", "false", "null", "undefined", "NaN", "Infinity"])
    
    private let builtins = Set([
        "console", "Math", "JSON", "Array", "Object", "String", "Number", "Boolean", "RegExp", "Date", "Error", "globalThis", "window", "document",
        "spawn", "setPosition", "setRotation", "setScale", "setColor", "remove", "setCamera", "setPhysics", "setTexture", "requestAnimationFrame", "attachTo", "cameraMode", "setVelocity"
    ])

    func highlight(_ textStorage: NSTextStorage) {
        let string = textStorage.string
        if string.isEmpty { return }
        let range = NSRange(location: 0, length: (string as NSString).length)
        
        textStorage.beginEditing()
        // Reset colors and font to ensure consistency
        textStorage.addAttribute(.foregroundColor, value: NSColor.labelColor, range: range)
        textStorage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 15, weight: .regular), range: range)
        
        // Comments
        let commentRegex = try? NSRegularExpression(pattern: "//.*|/\\*[\\s\\S]*?\\*/", options: [])
        commentRegex?.enumerateMatches(in: string, options: [], range: range) { match, _, _ in
            if let matchRange = match?.range {
                textStorage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: matchRange)
            }
        }
        
        // Strings
        let stringRegex = try? NSRegularExpression(pattern: "\".*?\"|'.*?'|`[\\s\\S]*?`", options: [])
        stringRegex?.enumerateMatches(in: string, options: [], range: range) { match, _, _ in
            if let matchRange = match?.range {
                textStorage.addAttribute(.foregroundColor, value: NSColor.systemGreen, range: matchRange)
            }
        }
        
        // Numbers
        let numberRegex = try? NSRegularExpression(pattern: "\\b-?\\d+(\\.\\d+)?\\b", options: [])
        numberRegex?.enumerateMatches(in: string, options: [], range: range) { match, _, _ in
            if let matchRange = match?.range {
                textStorage.addAttribute(.foregroundColor, value: NSColor.systemOrange, range: matchRange)
            }
        }
        
        // Words (Keywords, literals, builtins)
        let wordRegex = try? NSRegularExpression(pattern: "\\b[a-zA-Z_$][a-zA-Z0-9_$]*\\b", options: [])
        wordRegex?.enumerateMatches(in: string, options: [], range: range) { match, _, _ in
            if let matchRange = match?.range {
                let word = (string as NSString).substring(with: matchRange)
                if keywords.contains(word) {
                    textStorage.addAttribute(.foregroundColor, value: NSColor.systemPurple, range: matchRange)
                } else if literals.contains(word) {
                    textStorage.addAttribute(.foregroundColor, value: NSColor.systemPink, range: matchRange)
                } else if builtins.contains(word) {
                    textStorage.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: matchRange)
                }
            }
        }
        textStorage.endEditing()
    }
}

class CodeStore: ObservableObject {
    static let shared = CodeStore()
    @Published var jsCode: String = ""
    @Published var isLineWrapping: Bool = true
    @Published var suggestions: [String] = []
    @Published var currentHelp: FunctionDoc? = nil
    @Published var cursorScreenRect: NSRect = .zero
    @Published var showSuggestions: Bool = false
    
    weak var textView: NSTextView?
    
    let jsFunctions = ["spawn", "setPosition", "setRotation", "setScale", "setColor", "remove", "setCamera", "setPhysics", "setTexture", "requestAnimationFrame", "console.log", "lock", "unlock", "setVelocity", "attachTo", "cameraMode"]
    
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
            parameters: []),
        "attachTo": FunctionDoc(
            signature: "entity.attachTo(parent)",
            description: "Attaches this entity to a parent entity (or scene if null).",
            parameters: [
                .init(name: "parent", desc: "Parent entity object or ID (null to detach)")
            ]),
        "setVelocity": FunctionDoc(
            signature: "entity.setVelocity(vx, vy, vz)",
            description: "Sets the linear velocity of a dynamic physics entity.",
            parameters: [
                .init(name: "vx, vy, vz", desc: "Velocity vector components")
            ]),
        "cameraMode": FunctionDoc(
            signature: "cameraMode(mode)",
            description: "Sets the camera management mode.",
            parameters: [
                .init(name: "mode", desc: "'cinematic', 'navigate', or 'free'")
            ])
    ]

    func updateAutocomplete(for text: String, cursorLocation: Int) {
        let nsText = text as NSString
        if cursorLocation > nsText.length { return }
        let beforeCursor = nsText.substring(to: cursorLocation)
        
        // Extract only the current line (text after last newline)
        let currentLine: String
        if let lastNewline = beforeCursor.range(of: "\n", options: .backwards) {
            currentLine = String(beforeCursor[lastNewline.upperBound...])
        } else {
            currentLine = beforeCursor
        }
        
        // Handle help for function calls - check if we're inside parens on THIS line
        if let parenRange = currentLine.range(of: "(", options: .backwards) {
            let beforeParen = currentLine[..<parenRange.lowerBound]
            let parts = String(beforeParen).components(separatedBy: CharacterSet(charactersIn: " (.;\t"))
            if let lastWord = parts.last?.trimmingCharacters(in: CharacterSet.whitespaces),
               jsFunctions.contains(lastWord) {
                suggestions = []
                currentHelp = jsFunctionHelp[lastWord]
                showSuggestions = true
                return
            }
        }
        
        // Extract the word being typed (after last separator)
        let parts = currentLine.components(separatedBy: CharacterSet(charactersIn: " (.;\t"))
        guard let lastPart = parts.last, !lastPart.isEmpty else {
            suggestions = []
            currentHelp = nil
            showSuggestions = false
            return
        }
        
        let matches = jsFunctions.filter { $0.lowercased().hasPrefix(lastPart.lowercased()) }
        if !matches.isEmpty {
            suggestions = matches
            currentHelp = nil
            showSuggestions = true
        } else {
            suggestions = []
            currentHelp = nil
            showSuggestions = false
        }
    }
    
    func applySuggestion(_ suggestion: String) {
        guard let textView = textView else { return }
        let cursorLocation = textView.selectedRange().location
        let nsText = textView.string as NSString
        let beforeCursor = nsText.substring(to: cursorLocation)
        let parts = beforeCursor.components(separatedBy: CharacterSet(charactersIn: " (.;\n"))
        guard let lastPart = parts.last else { return }
        
        let range = NSRange(location: cursorLocation - lastPart.count, length: lastPart.count)
        textView.insertText(suggestion + "(", replacementRange: range)
        
        suggestions = []
        currentHelp = jsFunctionHelp[suggestion]
    }
    
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

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct GlassButton<Content: View>: View {
    let content: Content
    let action: () -> Void
    
    init(action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.action = action
        self.content = content()
    }
    
    var body: some View {
        Button(action: action) {
            content
                .font(.system(size: 14, weight: .medium))
                .frame(width: 20, height: 20)
                .padding(10)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular, in: .circle)
    }
}

struct ContentView: View {
    @ObservedObject var codeStore = CodeStore.shared
    @ObservedObject var inspectorManager = SceneInspectorWindowManager.shared
    @State private var isPaused = false
    @State private var hasInitialized = false
    @State private var isDraggingObject = false
    @State private var isEditorVisible = true
    
    var body: some View {
        ZStack {
            // Full Screen 3D Background
            RealityKitView()
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if value.startLocation.y < 30 { return } // Ignore title bar area
                            if !isDraggingObject {
                                RealityRenderer.shared.startDragging(at: value.startLocation)
                                isDraggingObject = true
                            }
                            RealityRenderer.shared.updateDragging(at: value.location)
                        }
                        .onEnded { value in
                            if value.startLocation.y < 30 { return }
                            RealityRenderer.shared.endDragging()
                            isDraggingObject = false
                        }
                )
                .edgesIgnoringSafeArea(.all)
            
            if isPaused {
                Rectangle()
                    .fill(Color.black.opacity(0.3))
                    .edgesIgnoringSafeArea(.all)
                    .overlay(
                        Image(systemName: "pause.circle.fill")
                            .resizable()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.white.opacity(0.8))
                    )
                    .allowsHitTesting(false)
            }
            
            // Floating Glass Editor Panel
            HStack(spacing: 0) {
                Spacer()
                
                if isEditorVisible {
                    VStack(spacing: 0) {
                        HStack {
                            Text("JavaScript Editor")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                        
                        CodeEditor(text: $codeStore.jsCode, isLineWrapping: codeStore.isLineWrapping)
                            .frame(width: 380)
                            .layoutPriority(1)
                            .padding(.horizontal, 10)
                            .padding(.bottom, 10)
                        
                        if codeStore.showSuggestions {
                            Divider()
                                .padding(.top, 4)
                            SuggestionOverlay()
                                .padding(.horizontal)
                                .padding(.bottom, 10)
                        }
                    }
                    .frame(width: 400)
                    .glassEffect(.regular, in: .rect(cornerRadius: 20))
                    .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                    .padding(.trailing, 20)
                    .padding(.vertical, 40)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                GlassButton(action: { loadFile() }) {
                    Image(systemName: "folder")
                }
                .help("Charger un fichier JS")
            }
            ToolbarItem(placement: .navigation) {
                GlassButton(action: { saveFile() }) {
                    Image(systemName: "square.and.arrow.down")
                }
                .help("Sauvegarder le fichier JS")
            }
            
            ToolbarItem(placement: .principal) {
                GlassButton(action: { runCode() }) {
                    Image(systemName: "play.fill")
                        .foregroundColor(.green)
                }
                .keyboardShortcut("r", modifiers: .command)
                .help("Exécuter le code JS (Cmd+R)")
            }
            ToolbarItem(placement: .principal) {
                GlassButton(action: {
                    isPaused.toggle()
                    RealityRenderer.shared.isPaused = isPaused
                }) {
                    Image(systemName: isPaused ? "play.circle" : "pause.fill")
                }
                .help(isPaused ? "Reprendre l'animation" : "Mettre en pause")
            }
            ToolbarItem(placement: .principal) {
                GlassButton(action: { reloadScene() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Recharger la scène")
            }
            
            ToolbarItem(placement: .primaryAction) {
                GlassButton(action: { CLIWindowManager.shared.toggle() }) {
                    Image(systemName: "terminal")
                }
                .help("Terminal JS")
            }
            ToolbarItem(placement: .primaryAction) {
                GlassButton(action: { SceneInspectorWindowManager.shared.toggle() }) {
                    Image(systemName: "list.bullet.indent")
                        .foregroundColor(inspectorManager.isVisible ? .blue : .primary)
                }
                .help("Inspecteur de scène")
            }
            ToolbarItem(placement: .primaryAction) {
                GlassButton(action: { DebugWindowManager.shared.toggle() }) {
                    Image(systemName: "ladybug")
                }
                .help("Debug Réseau")
            }
            ToolbarItem(placement: .primaryAction) {
                GlassButton(action: { HelpWindowManager.shared.toggle() }) {
                    Image(systemName: "questionmark.circle")
                }
                .help("Aide et exemples")
            }
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 6) {
                    GlassButton(action: { 
                        codeStore.isLineWrapping.toggle()
                    }) {
                        Image(systemName: "text.wordwrap")
                            .foregroundColor(codeStore.isLineWrapping ? .blue : .primary)
                    }
                    .help("Retour à la ligne automatique")
                    
                    GlassButton(action: {
                        withAnimation(.spring()) {
                            isEditorVisible.toggle()
                        }
                    }) {
                        Image(systemName: isEditorVisible ? "sidebar.right" : "sidebar.left")
                            .foregroundColor(isEditorVisible ? .blue : .primary)
                    }
                    .help(isEditorVisible ? "Masquer l'éditeur" : "Afficher l'éditeur")
                }
            }
        }
        .onAppear {
            DispatchQueue.main.async {
                if let window = NSApplication.shared.windows.first {
                    window.titlebarAppearsTransparent = true
                    window.titleVisibility = .hidden
                    window.styleMask.insert(.fullSizeContentView)
                    window.backgroundColor = .clear
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
            return "Available functions: spawn, setPosition, setRotation, setScale, setColor, remove, setCamera, setPhysics, setTexture, requestAnimationFrame, setVelocity"
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
    var isLineWrapping: Bool
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true // Enabled for no-wrap mode
        scrollView.drawsBackground = false // Make scroll view transparent
        
        let textView = NSTextView(frame: .zero)
        textView.isRichText = true // Required for multiple colors
        textView.drawsBackground = false // Make text view transparent
        textView.backgroundColor = .clear
        textView.insertionPointColor = NSColor.white // Better visibility on glass
        textView.allowsUndo = true
        textView.autoresizingMask = [.width, .height]
        textView.font = NSFont.monospacedSystemFont(ofSize: 15, weight: .regular)
        textView.delegate = context.coordinator
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.textColor = .white
        
        scrollView.documentView = textView
        CodeStore.shared.textView = textView
        
        // Initial highlight
        if let textStorage = textView.textStorage {
            SyntaxHighlighter.shared.highlight(textStorage)
        }
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let textView = nsView.documentView as? NSTextView {
            if textView.string != text {
                context.coordinator.isUpdating = true
                let cursorPos = textView.selectedRange()
                textView.string = text
                // Restore cursor position after programmatic update
                if cursorPos.location <= (text as NSString).length {
                    textView.setSelectedRange(cursorPos)
                }
                if let textStorage = textView.textStorage {
                    SyntaxHighlighter.shared.highlight(textStorage)
                }
                context.coordinator.isUpdating = false
            }
            
            // Update line wrapping
            if isLineWrapping {
                textView.isHorizontallyResizable = false
                textView.textContainer?.widthTracksTextView = true
                textView.textContainer?.containerSize = NSSize(width: nsView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
            } else {
                textView.isHorizontallyResizable = true
                textView.textContainer?.widthTracksTextView = false
                textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditor
        var isUpdating = false
        
        init(_ parent: CodeEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard !isUpdating else { return }
            if let textView = notification.object as? NSTextView {
                self.parent.text = textView.string
                if let textStorage = textView.textStorage {
                    SyntaxHighlighter.shared.highlight(textStorage)
                }
                triggerAutocomplete(textView)
            }
        }
        
        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isUpdating else { return }
            if let textView = notification.object as? NSTextView {
                triggerAutocomplete(textView)
            }
        }
        
        private func triggerAutocomplete(_ textView: NSTextView) {
            let text = textView.string
            let location = textView.selectedRange().location
            let rect = getCursorRect(textView)
            
            CodeStore.shared.cursorScreenRect = rect
            CodeStore.shared.updateAutocomplete(for: text, cursorLocation: location)
        }
        
        private func getCursorRect(_ textView: NSTextView) -> NSRect {
            if let layoutManager = textView.layoutManager, let textContainer = textView.textContainer {
                let selectedRange = textView.selectedRange()
                let glyphRange = layoutManager.glyphRange(forCharacterRange: selectedRange, actualCharacterRange: nil)
                let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
                let containerOrigin = textView.textContainerOrigin
                return rect.offsetBy(dx: containerOrigin.x, dy: containerOrigin.y)
            }
            return .zero
        }
        
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if CodeStore.shared.showSuggestions {
                if commandSelector == #selector(NSResponder.insertTab(_:)) || commandSelector == #selector(NSResponder.insertNewline(_:)) {
                    if let first = CodeStore.shared.suggestions.first {
                        CodeStore.shared.applySuggestion(first)
                        return true
                    }
                }
                if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                    CodeStore.shared.showSuggestions = false
                    return true
                }
            }
            return false
        }
    }
}

struct JSFunctionHelpView: View {
    let doc: FunctionDoc
    var onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(doc.signature)
                    .font(.system(size: 15, design: .monospaced))
                    .bold()
                    .foregroundColor(.primary)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Text(doc.description)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .padding(.bottom, 2)
            
            if !doc.parameters.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(doc.parameters) { param in
                        HStack(alignment: .top) {
                            Text("• \(param.name):")
                                .font(.system(size: 13, design: .monospaced))
                                .bold()
                                .frame(width: 100, alignment: .leading)
                            Text(param.desc)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct JSSuggestionsView: View {
    let suggestions: [String]
    let onSelect: (String) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Text(suggestion)
                        .font(.system(size: 13, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(suggestion == suggestions.first ? Color.blue : Color.blue.opacity(0.1))
                        .foregroundColor(suggestion == suggestions.first ? .white : .primary)
                        .cornerRadius(4)
                        .onTapGesture {
                            onSelect(suggestion)
                        }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct SuggestionOverlay: View {
    @ObservedObject var codeStore = CodeStore.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let doc = codeStore.currentHelp {
                JSFunctionHelpView(doc: doc) {
                    codeStore.currentHelp = nil
                }
            } else if !codeStore.suggestions.isEmpty {
                JSSuggestionsView(suggestions: codeStore.suggestions) { suggestion in
                    codeStore.applySuggestion(suggestion)
                }
            }
        }
        .frame(minHeight: codeStore.showSuggestions ? 30 : 0)
        .transition(.opacity)
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

                        helpSection(
                            title: "cameraMode(mode)",
                            description: "Définit le mode de gestion de la caméra ('cinematic', 'navigate', 'free').",
                            example: "cameraMode('cinematic');"
                        )
                        
                        helpSection(
                            title: "setVelocity(id, vx, vy, vz)",
                            description: "Définit la vélocité linéaire d'un objet dynamique.",
                            example: "let id = spawn('box');\nsetPhysics(id, 'dynamic');\nsetVelocity(id, 0, 5, 0);"
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
        textField.font = .monospacedSystemFont(ofSize: 15, weight: .regular)
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
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(line.isResponse ? .blue : .primary)
                                .textSelection(.enabled)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id("bottom")
                }
                .onChange(of: log.count) { _, _ in
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: input) { _, newValue in
                updateSuggestions(for: newValue)
            }
            .background(Color.black.opacity(0.05))
            
            if let doc = codeStore.currentHelp {
                Divider()
                JSFunctionHelpView(doc: doc) {
                    codeStore.currentHelp = nil
                }
                .transition(.opacity)
            } else if !codeStore.suggestions.isEmpty {
                Divider()
                JSSuggestionsView(suggestions: codeStore.suggestions) { suggestion in
                    applySuggestion(suggestion)
                }
                .padding(.horizontal)
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
    
    @ObservedObject var codeStore = CodeStore.shared
    @State private var history: [String] = []
    @State private var historyIndex: Int = -1
    @State private var tempInput: String = ""
    
    func updateSuggestions(for text: String) {
        codeStore.updateAutocomplete(for: text, cursorLocation: text.count)
    }
    
    func applySuggestion(_ suggestion: String) {
        let parts = input.components(separatedBy: CharacterSet(charactersIn: " (.;\n"))
        guard let lastPart = parts.last else { return }
        let prefix = String(input.dropLast(lastPart.count))
        input = prefix + suggestion + "("
        codeStore.suggestions = []
        codeStore.currentHelp = codeStore.jsFunctionHelp[suggestion]
    }

    func handleAutocomplete() {
        if let first = codeStore.suggestions.first {
            applySuggestion(first)
        } else {
            // Fallback to the old logic if suggestions are empty but maybe we can still find something
            let parts = input.components(separatedBy: CharacterSet(charactersIn: " (.;\n"))
            guard let lastPart = parts.last, !lastPart.isEmpty else { return }
            let matches = codeStore.jsFunctions.filter { $0.lowercased().hasPrefix(lastPart.lowercased()) }
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
        codeStore.currentHelp = nil
        codeStore.suggestions = []
        codeStore.showSuggestions = false
        
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

class SceneInspectorWindowManager: ObservableObject {
    static let shared = SceneInspectorWindowManager()
    @Published var isVisible = false
    private var window: NSPanel?
    
    func toggle() {
        if let window = window, window.isVisible {
            window.orderOut(nil)
            isVisible = false
            // Force Redraw of UI to update toggle color
            objectWillChange.send()
        } else {
            open()
        }
    }
    
    func open() {
        if window == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 100, y: 100, width: 350, height: 600),
                styleMask: [.titled, .closable, .resizable, .miniaturizable, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.title = "Inspecteur de Scène"
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.contentView = NSHostingView(rootView: SceneInspectorViewStandalone())
            panel.center()
            panel.setFrameAutosaveName("SceneInspectorWindow")
            panel.isReleasedWhenClosed = false
            self.window = panel
        }
        window?.makeKeyAndOrderFront(nil)
        isVisible = true
        objectWillChange.send()
    }
}

// MARK: - Scene Inspector Views

struct SceneInspectorViewStandalone: View {
    @ObservedObject var sceneModel = SceneModel.shared
    
    var body: some View {
        VStack(spacing: 0) {
            List {
                if sceneModel.items.isEmpty {
                    Text("Aucun objet dans la scène")
                        .foregroundColor(.gray)
                        .italic()
                        .padding()
                } else {
                    ForEach(sceneModel.items) { item in
                        EntityInspectorRow(item: item)
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .frame(width: 320)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .padding(10)
        .shadow(radius: 10)
    }
}

struct EntityInspectorRow: View {
    @State var item: EntityItem
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Image(systemName: item.isLocked ? "lock.fill" : "cube")
                    .foregroundColor(item.isLocked ? .orange : .blue)
                Text(item.name)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                Spacer()
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
                .buttonStyle(.plain)
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    PropertyRow(label: "Pos", values: $item.position)
                    PropertyRow(label: "Rot", values: $item.rotation)
                    PropertyRow(label: "Scale", values: $item.scale)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Couleur").font(.caption).foregroundColor(.gray)
                        ColorPicker("", selection: Binding(
                            get: { Color(red: Double(item.color.x), green: Double(item.color.y), blue: Double(item.color.z), opacity: Double(item.color.w)) },
                            set: { newColor in
                                if let components = newColor.getComponents() {
                                    item.color = [Float(components.red), Float(components.green), Float(components.blue), Float(components.alpha)]
                                }
                            }
                        ))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Métallique").font(.caption).foregroundColor(.gray)
                            Spacer()
                            Text(String(format: "%.2f", item.metallic)).font(.caption).monospaced()
                        }
                        Slider(value: $item.metallic, in: 0...1)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Rugosité").font(.caption).foregroundColor(.gray)
                            Spacer()
                            Text(String(format: "%.2f", item.roughness)).font(.caption).monospaced()
                        }
                        Slider(value: $item.roughness, in: 0...1)
                    }
                    
                    HStack {
                        Text("Phys").font(.caption).foregroundColor(.gray).frame(width: 40, alignment: .leading)
                        Picker("", selection: $item.physicsMode) {
                            Text("Static").tag("static")
                            Text("Dynamic").tag("dynamic")
                            Text("Kinematic").tag("kinematic")
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    Toggle("Verrouillé", isOn: $item.isLocked)
                        .font(.caption)
                }
                .padding(.leading, 10)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.1))
                .cornerRadius(8)
                .onChange(of: item) { _, newValue in
                    RealityRenderer.shared.updateFromInspector(item: newValue)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct PropertyRow: View {
    let label: String
    @Binding var values: SIMD3<Float>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundColor(.gray)
            HStack(spacing: 5) {
                PropertyField(value: $values.x, "X")
                PropertyField(value: $values.y, "Y")
                PropertyField(value: $values.z, "Z")
            }
        }
    }
}

struct PropertyField: View {
    @Binding var value: Float
    let label: String
    
    init(value: Binding<Float>, _ label: String) {
        self._value = value
        self.label = label
    }
    
    var body: some View {
        HStack(spacing: 2) {
            Text(label).font(.system(size: 8, weight: .bold)).foregroundColor(.gray)
            TextField("", value: $value, format: .number)
                .textFieldStyle(.plain)
                .font(.system(size: 10, design: .monospaced))
                .padding(4)
                .background(Color.white.opacity(0.1))
                .cornerRadius(4)
        }
    }
}

extension Color {
    func getComponents() -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)? {
        let nsColor = NSColor(self)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else { return nil }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        rgbColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }
}
