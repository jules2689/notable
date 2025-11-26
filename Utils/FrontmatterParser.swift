import Foundation

/// Utility for parsing and encoding YAML frontmatter in markdown files
struct FrontmatterParser {
    /// Parses frontmatter from markdown content
    /// Returns: (frontmatter: [String: String], body: String)
    static func parse(_ content: String) -> (frontmatter: [String: String], body: String) {
        // Check if content starts with frontmatter delimiter
        guard content.hasPrefix("---") else {
            return ([:], content)
        }
        
        // Find the end of frontmatter (second ---)
        let lines = content.components(separatedBy: .newlines)
        guard lines.count > 0 else {
            return ([:], content)
        }
        
        // First line should be "---"
        guard lines[0].trimmingCharacters(in: .whitespaces) == "---" else {
            return ([:], content)
        }
        
        // Find the closing "---"
        var frontmatterEndIndex: Int?
        for i in 1..<lines.count {
            if lines[i].trimmingCharacters(in: .whitespaces) == "---" {
                frontmatterEndIndex = i
                break
            }
        }
        
        guard let endIndex = frontmatterEndIndex else {
            // No closing delimiter, treat as no frontmatter
            return ([:], content)
        }
        
        // Extract frontmatter lines (between first and second ---)
        let frontmatterLines = Array(lines[1..<endIndex])
        var frontmatter: [String: String] = [:]
        
        // Simple YAML parsing (key: value format)
        for line in frontmatterLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                continue
            }
            
            // Split on first colon
            if let colonIndex = trimmed.firstIndex(of: ":") {
                let key = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(trimmed[trimmed.index(after: colonIndex)...])
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                
                if !key.isEmpty {
                    frontmatter[key] = value
                }
            }
        }
        
        // Extract body (everything after the closing ---)
        let bodyLines = Array(lines[(endIndex + 1)...])
        let body = bodyLines.joined(separator: "\n")
        
        return (frontmatter, body)
    }
    
    /// Encodes frontmatter and body into markdown content
    static func encode(frontmatter: [String: String], body: String) -> String {
        guard !frontmatter.isEmpty else {
            return body
        }
        
        var result = "---\n"
        
        // Write frontmatter key-value pairs
        for (key, value) in frontmatter.sorted(by: { $0.key < $1.key }) {
            // Escape value if it contains special characters
            let escapedValue = escapeYAMLValue(value)
            result += "\(key): \(escapedValue)\n"
        }
        
        result += "---\n"
        
        // Add body
        if !body.isEmpty {
            result += body
        }
        
        return result
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

