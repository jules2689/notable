import Foundation

/// Represents a folder that can contain notes and other folders
struct Folder: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var fileURL: URL
    var children: [NoteItem]
    var createdAt: Date
    var modifiedAt: Date
    var icon: String? // Emoji string or custom icon filename

    init(
        id: UUID = UUID(),
        name: String,
        fileURL: URL,
        children: [NoteItem] = [],
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        icon: String? = nil
    ) {
        self.id = id
        self.name = name
        self.fileURL = fileURL
        self.children = children
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.icon = icon
    }

    /// Creates a Folder from a directory URL
    init?(fromDirectoryURL url: URL) {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return nil
        }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)

            self.id = UUID()
            self.name = url.lastPathComponent
            self.fileURL = url
            self.children = []
            self.createdAt = attributes[.creationDate] as? Date ?? Date()
            self.modifiedAt = attributes[.modificationDate] as? Date ?? Date()
            
            // Load icon from .metadata file
            let metadataURL = url.appendingPathComponent(".metadata")
            if let metadata = MetadataParser.parse(from: metadataURL) {
                self.icon = metadata["icon"]?.isEmpty == false ? metadata["icon"] : nil
            } else {
                self.icon = nil
            }
        } catch {
            return nil
        }
    }

    /// Returns all notes in this folder (non-recursive)
    var notes: [Note] {
        children.compactMap { item in
            if case .note(let note) = item {
                return note
            }
            return nil
        }
    }

    /// Returns all subfolders in this folder (non-recursive)
    var folders: [Folder] {
        children.compactMap { item in
            if case .folder(let folder) = item {
                return folder
            }
            return nil
        }
    }

    /// Adds a note or folder to this folder's children
    mutating func addChild(_ item: NoteItem) {
        children.append(item)
        modifiedAt = Date()
    }

    /// Removes a note or folder from this folder's children
    mutating func removeChild(_ item: NoteItem) {
        children.removeAll { $0.id == item.id }
        modifiedAt = Date()
    }
}
