import Foundation

/// Service responsible for all file system operations for notes and folders
@Observable
@MainActor
class FileSystemService: @unchecked Sendable {
    private let fileManager = FileManager.default
    var workspace: Workspace
    private let storageManager = StorageLocationManager.shared
    private var webdavService: WebDAVService?

    init(workspace: Workspace? = nil) {
        // Use storage manager to get the root URL
        let rootURL = storageManager.rootURL
        self.workspace = workspace ?? Workspace(rootURL: rootURL)
        // Ensure security-scoped access is started
        _ = storageManager.startAccessingSecurityScopedResource()
        // Initialize WebDAV service if needed
        updateWebDAVService()
    }
    
    /// Updates WebDAV service configuration
    private func updateWebDAVService() {
        if storageManager.storageType == .webdav {
            webdavService = WebDAVService(
                serverURL: storageManager.webdavServerURL,
                username: storageManager.webdavUsername,
                password: storageManager.webdavPassword
            )
        } else {
            webdavService = nil
        }
    }
    
    /// Updates the workspace root URL based on current storage location settings
    func updateStorageLocation() {
        // Ensure security-scoped access is started before updating
        ensureSecurityScopedAccess()
        workspace.rootURL = storageManager.rootURL
        // Update WebDAV service configuration
        updateWebDAVService()
    }
    
    /// Ensures security-scoped resource access is started (for custom locations)
    private func ensureSecurityScopedAccess() {
        _ = storageManager.startAccessingSecurityScopedResource()
    }

    // MARK: - Directory Operations

    /// Ensures the notes directory exists
    func ensureNotesDirectoryExists() async throws {
        if storageManager.storageType == .webdav {
            // For WebDAV, ensure the Notes directory exists on the server
            try await ensureWebDAVDirectoryExists()
            return
        }
        
        // Ensure security-scoped access is started
        ensureSecurityScopedAccess()
        
        if !fileManager.fileExists(atPath: workspace.rootURL.path) {
            try fileManager.createDirectory(
                at: workspace.rootURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }
    
    /// Ensures WebDAV directory exists
    private func ensureWebDAVDirectoryExists() async throws {
        guard let webdav = webdavService else {
            throw FileSystemError.failedToCreateFolder
        }
        
        try await webdav.createDirectory(at: "Notes")
    }

    /// Loads the entire note hierarchy from the workspace root
    func loadNoteHierarchy() async throws -> [NoteItem] {
        if storageManager.storageType == .webdav {
            return try await loadWebDAVItems()
        }
        
        // Ensure security-scoped access is started
        _ = storageManager.startAccessingSecurityScopedResource()
        try await ensureNotesDirectoryExists()
        
        let rootURL = workspace.rootURL
        
        return try await Task.detached(priority: .userInitiated) {
            try await FileSystemService.loadItems(at: rootURL)
        }.value
    }
    
    /// Loads items from WebDAV
    private func loadWebDAVItems() async throws -> [NoteItem] {
        guard let webdav = webdavService else {
            throw FileSystemError.failedToCreateFolder
        }
        
        // Ensure directory exists first (synchronously)
        try await ensureWebDAVDirectoryExists()
        
        let webdavItems = try await webdav.listDirectory(at: "Notes")
        
        // Convert items synchronously after getting them from WebDAV
        return try await convertWebDAVItemsToNoteItems(webdavItems, basePath: "Notes")
    }
    
    /// Converts WebDAV items to NoteItems
    private func convertWebDAVItemsToNoteItems(_ webdavItems: [WebDAVItem], basePath: String) async throws -> [NoteItem] {
        var noteItems: [NoteItem] = []
        
        for item in webdavItems {
            // Skip the base path itself
            let normalizedPath = item.path.hasPrefix("/") ? String(item.path.dropFirst()) : item.path
            let normalizedBase = basePath.hasPrefix("/") ? String(basePath.dropFirst()) : basePath
            
            if normalizedPath == normalizedBase || normalizedPath == basePath || item.path == "/\(basePath)" {
                continue
            }
            
            // Extract relative path from basePath
            var relativePath = normalizedPath
            if normalizedPath.hasPrefix(normalizedBase) {
                relativePath = String(normalizedPath.dropFirst(normalizedBase.count))
                if relativePath.hasPrefix("/") {
                    relativePath = String(relativePath.dropFirst())
                }
            }
            
            // Create a virtual URL for the item
            let virtualURL = storageManager.rootURL.appendingPathComponent(relativePath)
            
            if item.isDirectory {
                // Create folder
                let folder = Folder(
                    name: item.name,
                    fileURL: virtualURL,
                    children: [],
                    createdAt: item.lastModified ?? Date(),
                    modifiedAt: item.lastModified ?? Date()
                )
                noteItems.append(.folder(folder))
            } else if item.name.hasSuffix(".md") {
                // Load note content
                if let note = try await loadWebDAVNote(path: item.path, virtualURL: virtualURL) {
                    noteItems.append(.note(note))
                }
            }
        }
        
        // Sort: folders first, then notes, alphabetically
        return noteItems.sorted { item1, item2 in
            if item1.isFolder && !item2.isFolder {
                return true
            } else if !item1.isFolder && item2.isFolder {
                return false
            } else {
                return item1.name.localizedStandardCompare(item2.name) == .orderedAscending
            }
        }
    }
    
    /// Loads a note from WebDAV
    private func loadWebDAVNote(path: String, virtualURL: URL) async throws -> Note? {
        guard let webdav = webdavService else { return nil }
        
        let data = try await webdav.downloadFile(from: path)
        
        guard let rawContent = String(data: data, encoding: .utf8) else { return nil }
        
        // Parse frontmatter
        let (frontmatter, body) = FrontmatterParser.parse(rawContent)
        
        return Note(
            title: virtualURL.deletingPathExtension().lastPathComponent,
            content: body,
            fileURL: virtualURL,
            createdAt: Date(),
            modifiedAt: Date(),
            icon: frontmatter["icon"]?.isEmpty == false ? frontmatter["icon"] : nil
        )
    }

    /// Recursively loads notes and folders from a directory
    private static func loadItems(at url: URL) throws -> [NoteItem] {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        var items: [NoteItem] = []

        for itemURL in contents {
            // Skip hidden files and system files
            if itemURL.lastPathComponent.hasPrefix(".") {
                continue
            }

            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDirectory) else {
                continue
            }

            if isDirectory.boolValue {
                // Load folder and its children
                if var folder = Folder(fromDirectoryURL: itemURL) {
                    folder.children = try loadItems(at: itemURL)
                    items.append(.folder(folder))
                }
            } else if itemURL.pathExtension == "md" {
                // Load note
                if let note = Note(fromFileURL: itemURL) {
                    items.append(.note(note))
                }
            }
        }

        // Sort: folders first, then notes, alphabetically
        return items.sorted { item1, item2 in
            if item1.isFolder && !item2.isFolder {
                return true
            } else if !item1.isFolder && item2.isFolder {
                return false
            } else {
                return item1.name.localizedStandardCompare(item2.name) == .orderedAscending
            }
        }
    }

    // MARK: - Note Operations

    /// Saves a note to disk
    func saveNote(_ note: Note) async throws {
        if storageManager.storageType == .webdav {
            try await saveWebDAVNote(note)
            return
        }
        
        ensureSecurityScopedAccess()
        
        // Build frontmatter if icon exists
        var frontmatter: [String: String] = [:]
        if let icon = note.icon, !icon.isEmpty {
            frontmatter["icon"] = icon
        }
        
        // Encode content with frontmatter
        let fullContent = FrontmatterParser.encode(frontmatter: frontmatter, body: note.content)
        
        try fullContent.write(to: note.fileURL, atomically: true, encoding: .utf8)

        // Update file modification date
        try fileManager.setAttributes(
            [.modificationDate: note.modifiedAt],
            ofItemAtPath: note.fileURL.path
        )
    }
    
    /// Saves a note to WebDAV
    private func saveWebDAVNote(_ note: Note) async throws {
        guard let webdav = webdavService else {
            throw FileSystemError.failedToCreateNote
        }
        
        // Build frontmatter if icon exists
        var frontmatter: [String: String] = [:]
        if let icon = note.icon, !icon.isEmpty {
            frontmatter["icon"] = icon
        }
        
        // Encode content with frontmatter
        let fullContent = FrontmatterParser.encode(frontmatter: frontmatter, body: note.content)
        
        // Convert virtual URL to WebDAV path
        let webdavPath = getWebDAVPath(from: note.fileURL)
        let data = fullContent.data(using: .utf8) ?? Data()
        
        try await webdav.uploadFile(data: data, to: webdavPath)
    }
    
    /// Converts a virtual URL to WebDAV path
    private func getWebDAVPath(from url: URL) -> String {
        // Get the path component relative to rootURL
        let rootPath = storageManager.rootURL.path
        let itemPath = url.path
        
        // Extract relative path
        var relativePath = itemPath
        if itemPath.hasPrefix(rootPath) {
            relativePath = String(itemPath.dropFirst(rootPath.count))
            if relativePath.hasPrefix("/") {
                relativePath = String(relativePath.dropFirst())
            }
        }
        
        // Build WebDAV path
        var webdavPath = "Notes"
        if !relativePath.isEmpty {
            webdavPath += "/" + relativePath
        }
        
        return webdavPath.replacingOccurrences(of: "//", with: "/")
    }
    
    /// Creates a new note in WebDAV
    private func createWebDAVNote(title: String, in directory: URL?) async throws -> Note {
        guard let webdav = webdavService else {
            throw FileSystemError.failedToCreateNote
        }
        
        let parentURL = directory ?? workspace.rootURL
        let sanitizedTitle = sanitizeFilename(title)
        var filename = "\(sanitizedTitle).md"
        var fileURL = parentURL.appendingPathComponent(filename)
        var webdavPath = getWebDAVPath(from: fileURL)
        
        // Check for existing files and make unique
        var counter = 1
        var foundUnique = false
        
        while !foundUnique {
            let exists: Bool
            do {
                _ = try await webdav.downloadFile(from: webdavPath)
                // File exists, try next
                exists = true
            } catch {
                // File doesn't exist, we can use this name
                exists = false
            }
            
            if !exists {
                foundUnique = true
            } else {
                filename = "\(sanitizedTitle)-\(counter).md"
                fileURL = parentURL.appendingPathComponent(filename)
                webdavPath = getWebDAVPath(from: fileURL)
                counter += 1
            }
        }
        
        // Create empty file
        let initialContent = Data()
        try await webdav.uploadFile(data: initialContent, to: webdavPath)
        
        return Note(
            title: sanitizedTitle,
            content: "",
            fileURL: fileURL,
            createdAt: Date(),
            modifiedAt: Date()
        )
    }

    /// Creates a new note with the given title in the specified directory
    func createNote(title: String, in directory: URL? = nil) async throws -> Note {
        if storageManager.storageType == .webdav {
            return try await createWebDAVNote(title: title, in: directory)
        }
        
        ensureSecurityScopedAccess()
        let parentURL = directory ?? workspace.rootURL
        try await ensureNotesDirectoryExists()

        // Sanitize filename
        let sanitizedTitle = sanitizeFilename(title)
        var filename = "\(sanitizedTitle).md"
        var fileURL = parentURL.appendingPathComponent(filename)

        // Ensure unique filename
        var counter = 1
        while fileManager.fileExists(atPath: fileURL.path) {
            filename = "\(sanitizedTitle)-\(counter).md"
            fileURL = parentURL.appendingPathComponent(filename)
            counter += 1
        }

        // Create empty file
        let initialContent = ""
        try initialContent.write(to: fileURL, atomically: true, encoding: .utf8)

        guard let note = Note(fromFileURL: fileURL) else {
            throw FileSystemError.failedToCreateNote
        }

        return note
    }

    /// Deletes a note from disk
    func deleteNote(_ note: Note) async throws {
        if storageManager.storageType == .webdav {
            try await deleteWebDAVItem(note.fileURL)
            return
        }
        
        ensureSecurityScopedAccess()
        try fileManager.removeItem(at: note.fileURL)
    }
    
    /// Deletes an item from WebDAV
    private func deleteWebDAVItem(_ url: URL) async throws {
        guard let webdav = webdavService else {
            throw FileSystemError.failedToCreateNote
        }
        
        let webdavPath = getWebDAVPath(from: url)
        try await webdav.deleteItem(at: webdavPath)
    }
    
    /// Renames a note in WebDAV
    private func renameWebDAVNote(_ note: Note, to newTitle: String) async throws -> Note {
        guard let webdav = webdavService else {
            throw FileSystemError.failedToRenameNote
        }
        
        let sanitizedTitle = sanitizeFilename(newTitle)
        let newFilename = "\(sanitizedTitle).md"
        let newURL = note.fileURL.deletingLastPathComponent().appendingPathComponent(newFilename)
        
        // Get current filename without extension for comparison
        let currentFilename = note.fileURL.lastPathComponent
        let currentNameWithoutExt = currentFilename.replacingOccurrences(of: ".md", with: "", options: .caseInsensitive)
        
        // If the sanitized new title matches the current filename (case-insensitive), no rename is needed
        if sanitizedTitle.caseInsensitiveCompare(currentNameWithoutExt) == .orderedSame {
            return note
        }
        
        let sourcePath = getWebDAVPath(from: note.fileURL)
        let destinationPath = getWebDAVPath(from: newURL)
        
        do {
            try await webdav.moveItem(from: sourcePath, to: destinationPath)
        } catch let error as WebDAVError {
            if case .fileAlreadyExists = error {
                throw FileSystemError.fileAlreadyExists
            }
            throw error
        }
        
        // Create a new note object with the updated URL, preserving the ID
        return Note(
            id: note.id,
            title: sanitizedTitle,
            content: note.content,
            fileURL: newURL,
            createdAt: note.createdAt,
            modifiedAt: note.modifiedAt,
            tags: note.tags
        )
    }

    /// Renames a note
    func renameNote(_ note: Note, to newTitle: String) async throws -> Note {
        if storageManager.storageType == .webdav {
            return try await renameWebDAVNote(note, to: newTitle)
        }
        
        ensureSecurityScopedAccess()
        let sanitizedTitle = sanitizeFilename(newTitle)
        let newFilename = "\(sanitizedTitle).md"
        let newURL = note.fileURL.deletingLastPathComponent().appendingPathComponent(newFilename)

        // Get current filename without extension for comparison
        let currentFilename = note.fileURL.lastPathComponent
        let currentNameWithoutExt = currentFilename.replacingOccurrences(of: ".md", with: "", options: .caseInsensitive)
        
        // If the sanitized new title matches the current filename (case-insensitive), no rename is needed
        if sanitizedTitle.caseInsensitiveCompare(currentNameWithoutExt) == .orderedSame {
            return note
        }

        // If the new URL is the same as the current URL, no rename is needed
        if newURL == note.fileURL {
            return note
        }

        // Check if file already exists at the new path
        if fileManager.fileExists(atPath: newURL.path) {
            // Check if it's the same file by comparing resource identifiers
            let currentResourceValues = try? note.fileURL.resourceValues(forKeys: [.fileResourceIdentifierKey])
            let newResourceValues = try? newURL.resourceValues(forKeys: [.fileResourceIdentifierKey])
            
            // Compare resource identifiers using NSObject's isEqual method
            let currentIdentifier = currentResourceValues?.fileResourceIdentifier
            let newIdentifier = newResourceValues?.fileResourceIdentifier
            
            // If both have identifiers and they're equal, it's the same file
            if let current = currentIdentifier as? NSObject,
               let new = newIdentifier as? NSObject,
               current.isEqual(new) {
                // Same file, no rename needed - return the note with updated title
                var updatedNote = note
                updatedNote.title = sanitizedTitle
                return updatedNote
            }
            
            // If they're different files, throw error
            throw FileSystemError.fileAlreadyExists
        }

        do {
            try fileManager.moveItem(at: note.fileURL, to: newURL)
        } catch {
            // If move fails because destination exists (race condition), check if it's the same file
            if (error as NSError).domain == NSCocoaErrorDomain && (error as NSError).code == NSFileWriteFileExistsError {
                // Check if it's the same file
                let currentResourceValues = try? note.fileURL.resourceValues(forKeys: [.fileResourceIdentifierKey])
                let newResourceValues = try? newURL.resourceValues(forKeys: [.fileResourceIdentifierKey])
                
                if let current = currentResourceValues?.fileResourceIdentifier as? NSObject,
                   let new = newResourceValues?.fileResourceIdentifier as? NSObject,
                   current.isEqual(new) {
                    // Same file, return updated note
                    var updatedNote = note
                    updatedNote.title = sanitizedTitle
                    return updatedNote
                }
            }
            throw error
        }

        guard let renamedNote = Note(fromFileURL: newURL) else {
            throw FileSystemError.failedToRenameNote
        }

        return renamedNote
    }

    // MARK: - Folder Operations

    /// Creates a new folder in the specified directory
    func createFolder(name: String, in directory: URL? = nil) async throws -> Folder {
        ensureSecurityScopedAccess()
        let parentURL = directory ?? workspace.rootURL
        try await ensureNotesDirectoryExists()

        let sanitizedName = sanitizeFilename(name)
        var folderURL = parentURL.appendingPathComponent(sanitizedName, isDirectory: true)

        // Ensure unique folder name
        var counter = 1
        while fileManager.fileExists(atPath: folderURL.path) {
            let uniqueName = "\(sanitizedName)-\(counter)"
            folderURL = parentURL.appendingPathComponent(uniqueName, isDirectory: true)
            counter += 1
        }

        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: false)

        guard let folder = Folder(fromDirectoryURL: folderURL) else {
            throw FileSystemError.failedToCreateFolder
        }

        return folder
    }

    /// Deletes a folder and all its contents
    func deleteFolder(_ folder: Folder) throws {
        ensureSecurityScopedAccess()
        try fileManager.removeItem(at: folder.fileURL)
    }

    /// Renames a folder
    func renameFolder(_ folder: Folder, to newName: String) throws -> Folder {
        ensureSecurityScopedAccess()
        let sanitizedName = sanitizeFilename(newName)
        let newURL = folder.fileURL.deletingLastPathComponent().appendingPathComponent(sanitizedName, isDirectory: true)

        // Check if folder already exists
        if fileManager.fileExists(atPath: newURL.path) {
            throw FileSystemError.fileAlreadyExists
        }

        try fileManager.moveItem(at: folder.fileURL, to: newURL)

        guard let renamedFolder = Folder(fromDirectoryURL: newURL) else {
            throw FileSystemError.failedToRenameFolder
        }

        return renamedFolder
    }

    // MARK: - Move Operations

    /// Moves a note or folder to a new directory
    func moveItem(_ item: NoteItem, to destination: URL) throws -> NoteItem {
        ensureSecurityScopedAccess()
        let itemURL = item.fileURL
        let newURL = destination.appendingPathComponent(itemURL.lastPathComponent)

        // Check if destination already exists
        if fileManager.fileExists(atPath: newURL.path) {
            throw FileSystemError.fileAlreadyExists
        }

        try fileManager.moveItem(at: itemURL, to: newURL)

        guard let movedItem = NoteItem.from(url: newURL) else {
            throw FileSystemError.failedToMoveItem
        }

        return movedItem
    }

    // MARK: - Search Operations

    /// Searches all notes for the given query
    func searchNotes(query: String) async throws -> [Note] {
        let items = try await loadNoteHierarchy()
        let lowercasedQuery = query.lowercased()

        var results: [Note] = []
        searchNotesRecursive(in: items, query: lowercasedQuery, results: &results)

        return results
    }

    private func searchNotesRecursive(in items: [NoteItem], query: String, results: inout [Note]) {
        for item in items {
            switch item {
            case .note(let note):
                // Search in title and content
                if note.title.lowercased().contains(query) ||
                   note.content.lowercased().contains(query) {
                    results.append(note)
                }
            case .folder(let folder):
                // Recursively search in folder contents
                searchNotesRecursive(in: folder.children, query: query, results: &results)
            }
        }
    }

    // MARK: - Helpers

    /// Sanitizes a filename by removing invalid characters
    private func sanitizeFilename(_ filename: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return filename
            .components(separatedBy: invalidCharacters)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Errors

enum FileSystemError: LocalizedError {
    case failedToCreateNote
    case failedToCreateFolder
    case failedToRenameNote
    case failedToRenameFolder
    case failedToMoveItem
    case fileAlreadyExists

    var errorDescription: String? {
        switch self {
        case .failedToCreateNote:
            return "Failed to create note"
        case .failedToCreateFolder:
            return "Failed to create folder"
        case .failedToRenameNote:
            return "Failed to rename note"
        case .failedToRenameFolder:
            return "Failed to rename folder"
        case .failedToMoveItem:
            return "Failed to move item"
        case .fileAlreadyExists:
            return "A file or folder with that name already exists"
        }
    }
}
