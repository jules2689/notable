import Foundation

/// Represents the user's notes workspace/library
struct Workspace: Codable {
    var rootURL: URL
    var lastOpenedNoteID: UUID?
    var recentNotes: [UUID]
    var expandedFolders: Set<UUID>

    init(
        rootURL: URL,
        lastOpenedNoteID: UUID? = nil,
        recentNotes: [UUID] = [],
        expandedFolders: Set<UUID> = []
    ) {
        self.rootURL = rootURL
        self.lastOpenedNoteID = lastOpenedNoteID
        self.recentNotes = recentNotes
        self.expandedFolders = expandedFolders
    }

    /// Default location for notes in user's Documents folder
    static var defaultNotesURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Notes", isDirectory: true)
    }

    /// Creates a default workspace
    static var `default`: Workspace {
        Workspace(rootURL: defaultNotesURL)
    }

    /// Adds a note to recent notes list (max 10)
    mutating func addToRecent(noteID: UUID) {
        recentNotes.removeAll { $0 == noteID }
        recentNotes.insert(noteID, at: 0)
        if recentNotes.count > 10 {
            recentNotes = Array(recentNotes.prefix(10))
        }
    }

    /// Toggles folder expansion state
    mutating func toggleFolder(_ folderID: UUID) {
        if expandedFolders.contains(folderID) {
            expandedFolders.remove(folderID)
        } else {
            expandedFolders.insert(folderID)
        }
    }
}
