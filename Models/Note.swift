import Foundation

/// Represents a single note document stored as a markdown file
struct Note: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var content: String
    var fileURL: URL
    var createdAt: Date
    var modifiedAt: Date
    var tags: [String]

    init(
        id: UUID = UUID(),
        title: String,
        content: String = "",
        fileURL: URL,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.fileURL = fileURL
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.tags = tags
    }

    /// Creates a Note from a file URL by reading its contents
    init?(fromFileURL url: URL) {
        guard url.pathExtension == "md" else { return nil }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)

            self.id = UUID()
            self.fileURL = url
            self.title = url.deletingPathExtension().lastPathComponent
            self.content = content
            self.createdAt = attributes[.creationDate] as? Date ?? Date()
            self.modifiedAt = attributes[.modificationDate] as? Date ?? Date()
            self.tags = []
        } catch {
            return nil
        }
    }

    /// Returns the filename without extension
    var filename: String {
        fileURL.deletingPathExtension().lastPathComponent
    }

    /// Updates the modification date to now
    mutating func touch() {
        modifiedAt = Date()
    }
}
