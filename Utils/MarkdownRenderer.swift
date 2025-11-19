import Foundation
import AppKit
import Down

/// Utility for rendering GitHub Flavored Markdown to various formats
class MarkdownRenderer {

    /// Renders markdown to HTML string
    static func toHTML(_ markdown: String) -> String? {
        do {
            let down = Down(markdownString: markdown)
            return try down.toHTML()
        } catch {
            print("Markdown to HTML conversion failed: \(error)")
            return nil
        }
    }

    /// Renders markdown to NSAttributedString for display
    static func toAttributedString(_ markdown: String) -> NSAttributedString? {
        do {
            let down = Down(markdownString: markdown)
            return try down.toAttributedString()
        } catch {
            print("Markdown to AttributedString conversion failed: \(error)")
            return nil
        }
    }

}
