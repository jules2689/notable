import Foundation

/// Utility for parsing and encoding metadata files for folders
struct MetadataParser {
    /// Parses metadata from a .metadata file
    /// Returns: Dictionary of key-value pairs, or nil if file doesn't exist or is invalid
    static func parse(from url: URL) -> [String: String]? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        
        var metadata: [String: String] = [:]
        let lines = content.components(separatedBy: .newlines)
        
        // Simple key: value format (similar to YAML)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                // Skip empty lines and comments
                continue
            }
            
            // Split on first colon
            if let colonIndex = trimmed.firstIndex(of: ":") {
                let key = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(trimmed[trimmed.index(after: colonIndex)...])
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                
                if !key.isEmpty {
                    metadata[key] = value
                }
            }
        }
        
        return metadata.isEmpty ? nil : metadata
    }
    
    /// Encodes metadata dictionary into a .metadata file format
    static func encode(_ metadata: [String: String]) -> String {
        guard !metadata.isEmpty else {
            return ""
        }
        
        var result = ""
        
        // Write metadata key-value pairs
        for (key, value) in metadata.sorted(by: { $0.key < $1.key }) {
            // Escape value if it contains special characters
            let escapedValue = escapeYAMLValue(value)
            result += "\(key): \(escapedValue)\n"
        }
        
        return result
    }
    
    /// Writes metadata to a .metadata file
    static func write(_ metadata: [String: String], to url: URL) throws {
        let content = encode(metadata)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
    
    /// Escapes a YAML value if needed
    private static func escapeYAMLValue(_ value: String) -> String {
        // If value contains special characters, wrap in quotes
        if value.contains(":") || value.contains("\n") || value.contains("\"") || value.contains("'") {
            // Escape quotes and wrap in double quotes
            let escaped = value.replacingOccurrences(of: "\"", with: "\\\"")
            return "\"\(escaped)\""
        }
        return value
    }
}

