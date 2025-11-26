import SwiftUI
import Foundation

/// A tab item representing an open note or empty tab
struct TabItem: Identifiable, Equatable, Codable {
    let id: UUID
    var noteID: UUID?
    var title: String
    var fileURL: URL?
    var isFileMissing: Bool = false // True if the note file was not found on disk
    
    /// Whether this is an empty tab with no note
    var isEmpty: Bool {
        noteID == nil && !isFileMissing
    }
    
    /// Create an empty tab
    static func empty() -> TabItem {
        TabItem(id: UUID(), noteID: nil, title: "New Tab", fileURL: nil, isFileMissing: false)
    }
    
    /// Create a tab for a note
    static func forNote(_ note: Note) -> TabItem {
        TabItem(id: UUID(), noteID: note.id, title: note.title, fileURL: note.fileURL, isFileMissing: false)
    }
    
    /// Create a tab for a missing note file
    static func forMissingFile(filename: String, fileURL: URL) -> TabItem {
        TabItem(
            id: UUID(),
            noteID: nil,
            title: "\(filename) was not found on disk",
            fileURL: fileURL,
            isFileMissing: true
        )
    }
    
    // Custom Codable implementation to handle URL encoding
    enum CodingKeys: String, CodingKey {
        case id
        case noteID
        case title
        case fileURL
        case isFileMissing
    }
    
    init(id: UUID, noteID: UUID?, title: String, fileURL: URL?, isFileMissing: Bool = false) {
        self.id = id
        self.noteID = noteID
        self.title = title
        self.fileURL = fileURL
        self.isFileMissing = isFileMissing
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        noteID = try container.decodeIfPresent(UUID.self, forKey: .noteID)
        title = try container.decode(String.self, forKey: .title)
        if let urlString = try container.decodeIfPresent(String.self, forKey: .fileURL) {
            fileURL = URL(string: urlString)
        } else {
            fileURL = nil
        }
        isFileMissing = try container.decodeIfPresent(Bool.self, forKey: .isFileMissing) ?? false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(noteID, forKey: .noteID)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(fileURL?.absoluteString, forKey: .fileURL)
        try container.encode(isFileMissing, forKey: .isFileMissing)
    }
    
    // Use default Equatable (compares all fields) so SwiftUI detects title changes
}

