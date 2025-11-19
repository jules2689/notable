import Foundation

/// Represents a slash command that can be inserted into the editor
struct SlashCommand: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String  // SF Symbol name
    let category: Category
    let template: String

    enum Category: String, CaseIterable {
        case components = "Components"
        case formatting = "Formatting"
        case blocks = "Blocks"

        var icon: String {
            switch self {
            case .components: return "square.stack.3d.up"
            case .formatting: return "textformat"
            case .blocks: return "square.grid.2x2"
            }
        }
    }

    /// All available slash commands
    static let all: [SlashCommand] = [
        // Callout commands
        SlashCommand(
            name: "Info Callout",
            description: "Create an informational callout box",
            icon: "info.circle.fill",
            category: .components,
            template: "{% callout info | Your message here %}"
        ),
        SlashCommand(
            name: "Warning Callout",
            description: "Create a warning callout box",
            icon: "exclamationmark.triangle.fill",
            category: .components,
            template: "{% callout warning | Your warning message %}"
        ),
        SlashCommand(
            name: "Error Callout",
            description: "Create an error callout box",
            icon: "xmark.circle.fill",
            category: .components,
            template: "{% callout error | Your error message %}"
        ),
        SlashCommand(
            name: "Success Callout",
            description: "Create a success callout box",
            icon: "checkmark.circle.fill",
            category: .components,
            template: "{% callout success | Your success message %}"
        ),

        // Embed commands
        SlashCommand(
            name: "Iframe Embed",
            description: "Embed a webpage or external content",
            icon: "rectangle.inset.filled",
            category: .components,
            template: "{% iframe https://example.com %}"
        ),
        SlashCommand(
            name: "Map",
            description: "Embed a location or address",
            icon: "map.fill",
            category: .components,
            template: "{% map Address or location %}"
        ),

        // Markdown blocks
        SlashCommand(
            name: "Code Block",
            description: "Insert a code block with syntax highlighting",
            icon: "curlybraces",
            category: .blocks,
            template: "```javascript\n// Your code here\n```"
        ),
        SlashCommand(
            name: "Table",
            description: "Insert a markdown table",
            icon: "tablecells",
            category: .blocks,
            template: """
            | Column 1 | Column 2 | Column 3 |
            |----------|----------|----------|
            | Cell 1   | Cell 2   | Cell 3   |
            | Cell 4   | Cell 5   | Cell 6   |
            """
        ),
        SlashCommand(
            name: "Task List",
            description: "Insert a task list",
            icon: "checklist",
            category: .blocks,
            template: """
            - [ ] Task 1
            - [ ] Task 2
            - [ ] Task 3
            """
        ),
        SlashCommand(
            name: "Quote",
            description: "Insert a blockquote",
            icon: "quote.bubble",
            category: .formatting,
            template: "> Your quote here"
        ),
        SlashCommand(
            name: "Horizontal Rule",
            description: "Insert a horizontal divider line",
            icon: "minus",
            category: .formatting,
            template: "\n---\n"
        ),
    ]

    /// Filter commands by search query
    static func filtered(by query: String) -> [SlashCommand] {
        guard !query.isEmpty else {
            return all
        }

        let lowercasedQuery = query.lowercased()
        return all.filter { command in
            command.name.lowercased().contains(lowercasedQuery) ||
            command.description.lowercased().contains(lowercasedQuery) ||
            command.category.rawValue.lowercased().contains(lowercasedQuery)
        }
    }
}
