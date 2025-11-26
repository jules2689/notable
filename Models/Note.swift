import Foundation
import CryptoKit

/// Represents a single note document stored as a markdown file
struct Note: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var content: String
    var fileURL: URL
    var createdAt: Date
    var modifiedAt: Date
    var tags: [String]
    var icon: String? // Emoji string or custom icon filename

    init(
        id: UUID = UUID(),
        title: String,
        content: String = "",
        fileURL: URL,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        tags: [String] = [],
        icon: String? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.fileURL = fileURL
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.tags = tags
        self.icon = icon
    }

    /// Creates a Note from a file URL by reading its contents
    init?(fromFileURL url: URL, id: UUID? = nil) {
        guard url.pathExtension == "md" else { return nil }

        do {
            let rawContent = try String(contentsOf: url, encoding: .utf8)
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)

            if let id = id {
                self.id = id
            } else {
                // Generate stable ID from file path using MD5 hash
                // This ensures that reloading the same file results in the same ID
                let path = url.standardized.path
                if let data = path.data(using: .utf8) {
                    let hash = Insecure.MD5.hash(data: data)
                    self.id = hash.withUnsafeBytes { ptr in
                        let uuidT = ptr.load(as: uuid_t.self)
                        return UUID(uuid: uuidT)
                    }
                } else {
                    self.id = UUID()
                }
            }
            
            // Parse frontmatter
            let (frontmatter, body) = FrontmatterParser.parse(rawContent)
            
            self.fileURL = url
            self.title = url.deletingPathExtension().lastPathComponent
            self.content = body // Store body without frontmatter
            self.createdAt = attributes[.creationDate] as? Date ?? Date()
            self.modifiedAt = attributes[.modificationDate] as? Date ?? Date()
            self.tags = []
            self.icon = frontmatter["icon"]?.isEmpty == false ? frontmatter["icon"] : nil
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
