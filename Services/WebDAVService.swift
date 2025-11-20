import Foundation

/// Service for WebDAV operations
@Observable
final class WebDAVService: @unchecked Sendable {
    var serverURL: URL?
    var username: String?
    var password: String?
    
    private let session: URLSession
    
    init(serverURL: URL? = nil, username: String? = nil, password: String? = nil) {
        self.serverURL = serverURL
        self.username = username
        self.password = password
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - Authentication
    
    /// Creates basic authentication header
    private func createAuthHeader() -> String? {
        guard let username = username, let password = password else { return nil }
        let credentials = "\(username):\(password)"
        guard let data = credentials.data(using: .utf8) else { return nil }
        let base64 = data.base64EncodedString()
        return "Basic \(base64)"
    }
    
    /// Creates a request with authentication
    private func createRequest(url: URL, method: String, body: Data? = nil) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("1", forHTTPHeaderField: "Depth")
        
        if let authHeader = createAuthHeader() {
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = body
            request.setValue("application/xml", forHTTPHeaderField: "Content-Type")
        }
        
        return request
    }
    
    // MARK: - Connection Test
    
    /// Tests the WebDAV connection
    func testConnection() async throws -> Bool {
        guard let serverURL = serverURL else {
            throw WebDAVError.invalidConfiguration
        }
        
        let url = serverURL
        var request = createRequest(url: url, method: "PROPFIND")
        request.setValue("0", forHTTPHeaderField: "Depth")
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WebDAVError.invalidResponse
        }
        
        // Accept both 200 (OK) and 207 (Multi-Status) for PROPFIND
        if httpResponse.statusCode == 200 || httpResponse.statusCode == 207 {
            return true
        } else if httpResponse.statusCode == 401 {
            throw WebDAVError.authenticationFailed
        } else if httpResponse.statusCode == 404 {
            // Directory doesn't exist, but connection works
            return true
        } else {
            throw WebDAVError.serverError(httpResponse.statusCode)
        }
    }
    
    // MARK: - Directory Operations
    
    /// Creates a directory (MKCOL)
    func createDirectory(at path: String) async throws {
        guard let serverURL = serverURL else {
            throw WebDAVError.invalidConfiguration
        }
        
        let url = serverURL.appendingPathComponent(path)
        let request = createRequest(url: url, method: "MKCOL")
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WebDAVError.invalidResponse
        }
        
        if httpResponse.statusCode == 201 {
            return // Success
        } else if httpResponse.statusCode == 405 {
            // Already exists
            return
        } else if httpResponse.statusCode == 401 {
            throw WebDAVError.authenticationFailed
        } else {
            throw WebDAVError.serverError(httpResponse.statusCode)
        }
    }
    
    /// Lists directory contents (PROPFIND)
    func listDirectory(at path: String) async throws -> [WebDAVItem] {
        guard let serverURL = serverURL else {
            throw WebDAVError.invalidConfiguration
        }
        
        let url = serverURL.appendingPathComponent(path)
        var request = createRequest(url: url, method: "PROPFIND")
        request.setValue("1", forHTTPHeaderField: "Depth")
        
        let propfindBody = """
        <?xml version="1.0" encoding="utf-8" ?>
        <D:propfind xmlns:D="DAV:">
            <D:prop>
                <D:displayname/>
                <D:resourcetype/>
                <D:getcontentlength/>
                <D:getlastmodified/>
            </D:prop>
        </D:propfind>
        """.data(using: .utf8)
        
        request.httpBody = propfindBody
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WebDAVError.invalidResponse
        }
        
        guard httpResponse.statusCode == 207 else {
            if httpResponse.statusCode == 401 {
                throw WebDAVError.authenticationFailed
            }
            throw WebDAVError.serverError(httpResponse.statusCode)
        }
        
        return try parsePROPFINDResponse(data: data, basePath: path)
    }
    
    // MARK: - File Operations
    
    /// Uploads a file (PUT)
    func uploadFile(data: Data, to path: String) async throws {
        guard let serverURL = serverURL else {
            throw WebDAVError.invalidConfiguration
        }
        
        let url = serverURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = data
        
        if let authHeader = createAuthHeader() {
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        }
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WebDAVError.invalidResponse
        }
        
        guard httpResponse.statusCode == 201 || httpResponse.statusCode == 204 else {
            if httpResponse.statusCode == 401 {
                throw WebDAVError.authenticationFailed
            }
            throw WebDAVError.serverError(httpResponse.statusCode)
        }
    }
    
    /// Downloads a file (GET)
    func downloadFile(from path: String) async throws -> Data {
        guard let serverURL = serverURL else {
            throw WebDAVError.invalidConfiguration
        }
        
        let url = serverURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let authHeader = createAuthHeader() {
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WebDAVError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw WebDAVError.authenticationFailed
            } else if httpResponse.statusCode == 404 {
                throw WebDAVError.fileNotFound
            }
            throw WebDAVError.serverError(httpResponse.statusCode)
        }
        
        return data
    }
    
    /// Deletes a file or directory (DELETE)
    func deleteItem(at path: String) async throws {
        guard let serverURL = serverURL else {
            throw WebDAVError.invalidConfiguration
        }
        
        let url = serverURL.appendingPathComponent(path)
        let request = createRequest(url: url, method: "DELETE")
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WebDAVError.invalidResponse
        }
        
        guard httpResponse.statusCode == 204 || httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw WebDAVError.authenticationFailed
            } else if httpResponse.statusCode == 404 {
                throw WebDAVError.fileNotFound
            }
            throw WebDAVError.serverError(httpResponse.statusCode)
        }
    }
    
    /// Moves/renames a file (MOVE)
    func moveItem(from sourcePath: String, to destinationPath: String) async throws {
        guard let serverURL = serverURL else {
            throw WebDAVError.invalidConfiguration
        }
        
        let sourceURL = serverURL.appendingPathComponent(sourcePath)
        let destinationURL = serverURL.appendingPathComponent(destinationPath)
        
        var request = URLRequest(url: sourceURL)
        request.httpMethod = "MOVE"
        request.setValue(destinationURL.absoluteString, forHTTPHeaderField: "Destination")
        request.setValue("T", forHTTPHeaderField: "Overwrite")
        
        if let authHeader = createAuthHeader() {
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        }
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WebDAVError.invalidResponse
        }
        
        guard httpResponse.statusCode == 201 || httpResponse.statusCode == 204 else {
            if httpResponse.statusCode == 401 {
                throw WebDAVError.authenticationFailed
            } else if httpResponse.statusCode == 409 {
                throw WebDAVError.fileAlreadyExists
            }
            throw WebDAVError.serverError(httpResponse.statusCode)
        }
    }
    
    // MARK: - XML Parsing
    
    private func parsePROPFINDResponse(data: Data, basePath: String) throws -> [WebDAVItem] {
        let parser = WebDAVXMLParser()
        return try parser.parse(data: data, basePath: basePath)
    }
}

// MARK: - WebDAV Item

struct WebDAVItem {
    let path: String
    let name: String
    let isDirectory: Bool
    let size: Int64?
    let lastModified: Date?
}

// MARK: - WebDAV Errors

enum WebDAVError: LocalizedError {
    case invalidConfiguration
    case invalidResponse
    case authenticationFailed
    case fileNotFound
    case fileAlreadyExists
    case serverError(Int)
    case parseError
    
    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "WebDAV configuration is invalid"
        case .invalidResponse:
            return "Invalid response from server"
        case .authenticationFailed:
            return "Authentication failed. Please check your credentials."
        case .fileNotFound:
            return "File or directory not found"
        case .fileAlreadyExists:
            return "File or directory already exists"
        case .serverError(let code):
            return "Server error: \(code)"
        case .parseError:
            return "Failed to parse server response"
        }
    }
}

// MARK: - WebDAV XML Parser

class WebDAVXMLParser: NSObject, XMLParserDelegate {
    private var items: [WebDAVItem] = []
    private var currentItem: (path: String, name: String, isDirectory: Bool, size: Int64?, lastModified: Date?)?
    private var currentElement: String?
    private var currentText: String = ""
    private var basePath: String = ""
    private var inResourcetype = false
    private var inCollection = false
    
    init(basePath: String = "") {
        self.basePath = basePath
    }
    
    func parse(data: Data, basePath: String) throws -> [WebDAVItem] {
        self.items = []
        self.basePath = basePath
        self.inResourcetype = false
        self.inCollection = false
        let parser = XMLParser(data: data)
        parser.delegate = self
        
        guard parser.parse() else {
            throw WebDAVError.parseError
        }
        
        return items
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        currentText = ""
        
        if elementName == "D:response" {
            currentItem = (path: "", name: "", isDirectory: false, size: nil, lastModified: nil)
            inResourcetype = false
            inCollection = false
        } else if elementName == "D:resourcetype" {
            inResourcetype = true
        } else if elementName == "D:collection" {
            inCollection = true
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard var item = currentItem else { return }
        
        switch elementName {
        case "D:href":
            let path = currentText.removingPercentEncoding ?? currentText
            item.path = path
            // Extract name from path
            if let url = URL(string: path) {
                item.name = url.lastPathComponent
            } else {
                item.name = URL(fileURLWithPath: path).lastPathComponent
            }
        case "D:collection":
            inCollection = false
            item.isDirectory = true
        case "D:resourcetype":
            inResourcetype = false
            if inCollection {
                item.isDirectory = true
            }
        case "D:getcontentlength":
            if let size = Int64(currentText) {
                item.size = size
            }
        case "D:getlastmodified":
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            item.lastModified = formatter.date(from: currentText)
        case "D:response":
            if !item.path.isEmpty {
                let normalizedPath = item.path.hasPrefix("/") ? String(item.path.dropFirst()) : item.path
                let normalizedBase = basePath.hasPrefix("/") ? String(basePath.dropFirst()) : basePath
                
                if normalizedPath != normalizedBase && normalizedPath != basePath && item.path != "/\(basePath)" {
                    items.append(WebDAVItem(
                        path: item.path,
                        name: item.name,
                        isDirectory: item.isDirectory,
                        size: item.size,
                        lastModified: item.lastModified
                    ))
                }
            }
            currentItem = nil
        default:
            break
        }
        
        currentItem = item
        currentElement = nil
        currentText = ""
    }
}

