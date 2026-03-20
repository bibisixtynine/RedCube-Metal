import Foundation
import Network
import AppKit

class CommandLog: ObservableObject {
    static let shared = CommandLog()
    @Published var entries: [String] = []
    
    func log(_ message: String) {
        print("API Log: \(message)")
        DispatchQueue.main.async {
            self.entries.insert(message, at: 0)
            if self.entries.count > 200 {
                self.entries.removeLast()
            }
        }
    }
}

class APIServer {
    static let shared = APIServer()
    private var listener: NWListener?
    
    // Callbacks to main app
    var onRunJS: ((String) -> Void)?
    var onReload: (() -> Void)?
    var onRunEditorCode: (() -> Void)?
    var onTogglePause: (() -> Void)?
    var onLoadPath: ((String) -> Bool)?
    var onSavePath: ((String) -> Bool)?
    var onGetHelp: (() -> String)?
    var onCallFunction: ((String) -> Void)?
    var onTakeScreenshot: ((@escaping (Data?) -> Void) -> Void)?

    func start(port: UInt16 = 8080) {
        do {
            listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
        } catch {
            print("Failed to create listener: \(error)")
            return
        }
        
        listener?.stateUpdateHandler = { state in
            print("API Server state: \(state)")
        }
        
        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }
        
        listener?.start(queue: .main)
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .main)
        receive(connection: connection)
    }
    
    private func receive(connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, context, isComplete, error in
            if let data = content, !data.isEmpty {
                self?.processRequest(data, connection: connection)
            }
            if error != nil || isComplete {
                // Keep connected for a bit? No, HTTP 1.1 single request for simplicity.
            }
        }
    }
    
    private func processRequest(_ data: Data, connection: NWConnection) {
        guard let requestString = String(data: data, encoding: .utf8) else { return }
        let lines = requestString.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else { return }
        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else { return }
        
        let method = parts[0]
        let fullPath = parts[1]
        
        let urlComponents = URLComponents(string: fullPath)
        let path = urlComponents?.path ?? fullPath
        let queryItems = urlComponents?.queryItems
        
        // Find body if any (simplified)
        var body = ""
        if let bodyRange = requestString.range(of: "\r\n\r\n") {
            body = String(requestString[bodyRange.upperBound...])
        }
        
        CommandLog.shared.log("\(method) \(path) \(body)")

        switch (method, path) {
        case ("POST", "/js"):
            onRunJS?(body)
            sendResponse(connection: connection, content: "OK")
            
        case ("POST", "/reload"):
            onReload?()
            sendResponse(connection: connection, content: "OK")
            
        case ("POST", "/run"):
            onRunEditorCode?()
            sendResponse(connection: connection, content: "OK")
            
        case ("POST", "/pause"):
            onTogglePause?()
            sendResponse(connection: connection, content: "OK")
            
        case ("GET", "/load"):
            if let pathParam = queryItems?.first(where: { $0.name == "path" })?.value {
                let success = onLoadPath?(pathParam) ?? false
                sendResponse(connection: connection, content: success ? "OK" : "Error loading file")
            } else {
                sendResponse(connection: connection, content: "Missing path parameter", status: "400 Bad Request")
            }
            
        case ("POST", "/save"):
            if let pathParam = queryItems?.first(where: { $0.name == "path" })?.value {
                let success = onSavePath?(pathParam) ?? false
                sendResponse(connection: connection, content: success ? "OK" : "Error saving file")
            } else {
                sendResponse(connection: connection, content: "Missing path parameter", status: "400 Bad Request")
            }
            
        case ("GET", "/help"):
            let help = onGetHelp?() ?? "No help available"
            sendResponse(connection: connection, content: help)
            
        case ("GET", "/doc"):
            sendResponse(connection: connection, content: apiDocumentation, contentType: "text/markdown")
            
        case ("POST", "/call"):
            onCallFunction?(body)
            sendResponse(connection: connection, content: "OK")
            
        case ("GET", "/screenshot"):
            onTakeScreenshot? { imageData in
                if let imageData = imageData {
                    self.sendResponse(connection: connection, content: imageData, contentType: "image/png")
                } else {
                    self.sendResponse(connection: connection, content: "Failed to capture screenshot", status: "500 Internal Server Error")
                }
            }
            
        default:
            sendResponse(connection: connection, content: "Not Found", status: "404 Not Found")
        }
    }
    
    private func sendResponse(connection: NWConnection, content: Any, status: String = "200 OK", contentType: String = "text/plain") {
        var bodyData: Data
        if let string = content as? String {
            bodyData = string.data(using: .utf8) ?? Data()
        } else if let data = content as? Data {
            bodyData = data
        } else {
            bodyData = Data()
        }
        
        let response = "HTTP/1.1 \(status)\r\n" +
                       "Content-Type: \(contentType)\r\n" +
                       "Content-Length: \(bodyData.count)\r\n" +
                       "Access-Control-Allow-Origin: *\r\n" +
                       "Connection: close\r\n" +
                       "\r\n"
        
        guard let headerData = response.data(using: .utf8) else { return }
        let fullData = headerData + bodyData
        
        connection.send(content: fullData, completion: .contentProcessed({ _ in
            connection.cancel()
        }))
    }
    
    private let apiDocumentation = """
    # MetalJS API Documentation
    
    Control MetalJS externally via HTTP (localhost:8080).
    
    ### Endpoints
    
    - `POST /js`: Execute JavaScript code.
      - **Body**: JavaScript code string.
    - `POST /reload`: Reset the scene and re-run editor code.
    - `POST /run`: Run the current editor code.
    - `POST /pause`: Toggle animation pause.
    - `GET /load?path=...`: Load a JS file from an absolute path.
    - `POST /save?path=...`: Save editor code to an absolute path.
    - `GET /help`: Get the built-in JavaScript help.
    - `GET /doc`: Get this documentation in Markdown.
    - `POST /call`: Execute a JS function (e.g., `myFunc()`).
      - **Body**: Function call string.
    - `GET /screenshot`: Returns a PNG image of the scene.
    """
}
