import Foundation
import AppKit
import Down

/// Utility for rendering GitHub Flavored Markdown to various formats
class MarkdownRenderer {

    /// Renders markdown to HTML string with GitHub Flavored Markdown extensions
    static func toHTML(_ markdown: String) -> String? {
        do {
            let down = Down(markdownString: markdown)

            // Enable GitHub Flavored Markdown options and extensions
            var options = DownOptions()
            options.insert(.smartQuotes)
            options.insert(.validateUTF8)
            options.insert(.githubPreLang)

            return try down.toHTML(.default, extensions: .all)
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
