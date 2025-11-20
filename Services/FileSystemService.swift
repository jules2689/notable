import Foundation

/// Service responsible for all file system operations for notes and folders
@Observable
class FileSystemService {
    private let fileManager = FileManager.default
    var workspace: Workspace
    private let storageManager = StorageLocationManager.shared

    init(workspace: Workspace? = nil) {
        // Use storage manager to get the root URL
        let rootURL = storageManager.rootURL
        self.workspace = workspace ?? Workspace(rootURL: rootURL)
        // Ensure security-scoped access is started
        _ = storageManager.startAccessingSecurityScopedResource()
    }
    
    /// Updates the workspace root URL based on current storage location settings
    func updateStorageLocation() {
        // Ensure security-scoped access is started before updating
        ensureSecurityScopedAccess()
        workspace.rootURL = storageManager.rootURL
    }
    
    /// Ensures security-scoped resource access is started (for custom locations)
    private func ensureSecurityScopedAccess() {
        _ = storageManager.startAccessingSecurityScopedResource()
    }

    // MARK: - Directory Operations

    /// Ensures the notes directory exists
    func ensureNotesDirectoryExists() throws {
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

    /// Loads the entire note hierarchy from the workspace root
    func loadNoteHierarchy() throws -> [NoteItem] {
        // Ensure security-scoped access is started
        _ = storageManager.startAccessingSecurityScopedResource()
        try ensureNotesDirectoryExists()
        return try loadItems(at: workspace.rootURL)
    }

    /// Recursively loads notes and folders from a directory
    private func loadItems(at url: URL) throws -> [NoteItem] {
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
    func saveNote(_ note: Note) throws {
        ensureSecurityScopedAccess()
        try note.content.write(to: note.fileURL, atomically: true, encoding: .utf8)

        // Update file modification date
        try fileManager.setAttributes(
            [.modificationDate: note.modifiedAt],
            ofItemAtPath: note.fileURL.path
        )
    }

    /// Creates a new note with the given title in the specified directory
    func createNote(title: String, in directory: URL? = nil) throws -> Note {
        ensureSecurityScopedAccess()
        let parentURL = directory ?? workspace.rootURL
        try ensureNotesDirectoryExists()

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
    func deleteNote(_ note: Note) throws {
        ensureSecurityScopedAccess()
        try fileManager.removeItem(at: note.fileURL)
    }

    /// Renames a note
    func renameNote(_ note: Note, to newTitle: String) throws -> Note {
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
    func createFolder(name: String, in directory: URL? = nil) throws -> Folder {
        ensureSecurityScopedAccess()
        let parentURL = directory ?? workspace.rootURL
        try ensureNotesDirectoryExists()

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
    func searchNotes(query: String) throws -> [Note] {
        let items = try loadNoteHierarchy()
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
