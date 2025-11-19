import Foundation
import CoreTransferable
import UniformTypeIdentifiers

/// Represents an item in the sidebar navigation (either a Note or Folder)
enum NoteItem: Identifiable, Codable, Hashable, Transferable {
    case note(Note)
    case folder(Folder)

    var id: UUID {
        switch self {
        case .note(let note):
            return note.id
        case .folder(let folder):
            return folder.id
        }
    }

    var name: String {
        switch self {
        case .note(let note):
            return note.title
        case .folder(let folder):
            return folder.name
        }
    }

    var fileURL: URL {
        switch self {
        case .note(let note):
            return note.fileURL
        case .folder(let folder):
            return folder.fileURL
        }
    }

    var modifiedAt: Date {
        switch self {
        case .note(let note):
            return note.modifiedAt
        case .folder(let folder):
            return folder.modifiedAt
        }
    }

    var isFolder: Bool {
        if case .folder = self {
            return true
        }
        return false
    }

    var isNote: Bool {
        if case .note = self {
            return true
        }
        return false
    }

    // MARK: - Transferable Conformance

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .noteItem)
    }
}

extension NoteItem {
    /// Creates a NoteItem from a file system URL
    static func from(url: URL) -> NoteItem? {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return nil
        }

        if isDirectory.boolValue {
            guard let folder = Folder(fromDirectoryURL: url) else { return nil }
            return .folder(folder)
        } else {
            guard let note = Note(fromFileURL: url) else { return nil }
            return .note(note)
        }
    }
}

// MARK: - UTType Extension

extension UTType {
    static let noteItem = UTType(exportedAs: "com.notable.noteitem")
}
