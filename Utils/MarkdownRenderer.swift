import Foundation
import AppKit
import Down

/// Utility for rendering GitHub Flavored Markdown to various formats
class MarkdownRenderer {

    /// Renders markdown to HTML string
    /// Note: Down library may not fully support GFM extensions like tables
    /// We rely on JavaScript libraries (like marked.js) for full GFM support
    static func toHTML(_ markdown: String) -> String? {
        do {
            let down = Down(markdownString: markdown)

            // Try with default options first
            var options = DownOptions()
            // Don't use smart quotes
            options.remove(.smart)

            return try down.toHTML(options)
        } catch {
            // Fallback to basic rendering
            do {
                let down = Down(markdownString: markdown)
                return try down.toHTML()
            } catch {
                print("Markdown to HTML conversion failed: \(error)")
                return nil
            }
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
