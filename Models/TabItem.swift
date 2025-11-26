import SwiftUI

/// A tab item representing an open note or empty tab
struct TabItem: Identifiable, Equatable {
    let id: UUID
    var noteID: UUID?
    var title: String
    var fileURL: URL?
    
    /// Whether this is an empty tab with no note
    var isEmpty: Bool {
        noteID == nil
    }
    
    /// Create an empty tab
    static func empty() -> TabItem {
        TabItem(id: UUID(), noteID: nil, title: "New Tab", fileURL: nil)
    }
    
    /// Create a tab for a note
    static func forNote(_ note: Note) -> TabItem {
        TabItem(id: UUID(), noteID: note.id, title: note.title, fileURL: note.fileURL)
    }
    
    // Use default Equatable (compares all fields) so SwiftUI detects title changes
}

