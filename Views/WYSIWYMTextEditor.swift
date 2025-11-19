import SwiftUI
import AppKit

/// A WYSIWYM (What You See Is What You Mean) text editor that renders markdown inline
struct WYSIWYMTextEditor: NSViewRepresentable {
    @Binding var text: String
    var onTextChange: (String) -> Void
    @Binding var showSlashCommands: Bool
    @Binding var slashQuery: String
    @Binding var slashCommandPosition: NSPoint
    @Binding var commandToInsert: SlashCommand?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()

        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        // Configure text view
        textView.delegate = context.coordinator
        textView.font = .systemFont(ofSize: 14)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.allowsUndo = true

        // Enable rich text for attributed strings
        textView.isRichText = true
        textView.usesRuler = false
        textView.usesFontPanel = false

        // Set initial text with markdown styling
        context.coordinator.textView = textView
        context.coordinator.setTextWithMarkdownStyling(text)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Check if text has changed from outside (e.g., switching notes)
        if textView.string != text {
            let selectedRange = textView.selectedRange()
            context.coordinator.setTextWithMarkdownStyling(text)
            // Restore selection if valid
            if selectedRange.location <= text.count {
                textView.setSelectedRange(selectedRange)
            }
        }

        // Update bindings
        context.coordinator.showSlashCommands = $showSlashCommands
        context.coordinator.slashQuery = $slashQuery
        context.coordinator.slashCommandPosition = $slashCommandPosition
        context.coordinator.onTextChange = onTextChange
        context.coordinator.commandToInsert = $commandToInsert

        // Handle command insertion
        if let command = commandToInsert {
            context.coordinator.insertSlashCommand(command)
            DispatchQueue.main.async {
                commandToInsert = nil
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        var textView: NSTextView?
        var showSlashCommands: Binding<Bool>?
        var slashQuery: Binding<String>?
        var slashCommandPosition: Binding<NSPoint>?
        var onTextChange: ((String) -> Void)?
        var commandToInsert: Binding<SlashCommand?>?

        private var slashStartLocation: Int?
        private var isUpdatingFormatting = false

        init(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  !isUpdatingFormatting else { return }

            let newText = textView.string
            text = newText
            onTextChange?(newText)

            // Apply markdown styling
            applyMarkdownStyling(to: textView)

            // Check for slash command trigger
            checkForSlashCommand(in: textView)
        }

        func setTextWithMarkdownStyling(_ text: String) {
            guard let textView = textView else { return }

            isUpdatingFormatting = true
            let attributedString = parseMarkdown(text)
            textView.textStorage?.setAttributedString(attributedString)
            isUpdatingFormatting = false
        }

        private func applyMarkdownStyling(to textView: NSTextView) {
            guard let textStorage = textView.textStorage else { return }

            let selectedRange = textView.selectedRange()
            isUpdatingFormatting = true

            let text = textView.string
            let attributedString = parseMarkdown(text)

            textStorage.setAttributedString(attributedString)

            // Restore selection
            if selectedRange.location <= textStorage.length {
                textView.setSelectedRange(selectedRange)
            }

            isUpdatingFormatting = false
        }

        private func parseMarkdown(_ text: String) -> NSAttributedString {
            let attributedString = NSMutableAttributedString(string: text)
            let fullRange = NSRange(location: 0, length: attributedString.length)

            // Base font and color
            let baseFont = NSFont.systemFont(ofSize: 14)
            let textColor = NSColor.labelColor

            // Reset all attributes to base
            attributedString.addAttribute(.font, value: baseFont, range: fullRange)
            attributedString.addAttribute(.foregroundColor, value: textColor, range: fullRange)

            // Apply markdown patterns
            applyHeadings(to: attributedString)
            applyBoldItalic(to: attributedString)
            applyInlineCode(to: attributedString)
            applyCodeBlocks(to: attributedString)
            applyLinks(to: attributedString)
            applyLists(to: attributedString)

            return attributedString
        }

        // MARK: - Markdown Pattern Handlers

        private func applyHeadings(to attributedString: NSMutableAttributedString) {
            let text = attributedString.string
            let pattern = "^(#{1,6})\\s+(.+)$"

            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return }

            let matches = regex.matches(in: text, range: NSRange(location: 0, length: text.count))

            for match in matches {
                let levelRange = match.range(at: 1)
                let contentRange = match.range(at: 2)

                if let levelString = Range(levelRange, in: text) {
                    let level = text[levelString].count
                    let fontSize: CGFloat = {
                        switch level {
                        case 1: return 28
                        case 2: return 24
                        case 3: return 20
                        case 4: return 17
                        case 5: return 15
                        case 6: return 14
                        default: return 14
                        }
                    }()

                    let headingFont = NSFont.boldSystemFont(ofSize: fontSize)

                    // Style the heading markers (# symbols)
                    attributedString.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: levelRange)
                    attributedString.addAttribute(.font, value: NSFont.systemFont(ofSize: fontSize * 0.8), range: levelRange)

                    // Style the heading content
                    attributedString.addAttribute(.font, value: headingFont, range: contentRange)
                }
            }
        }

        private func applyBoldItalic(to attributedString: NSMutableAttributedString) {
            let text = attributedString.string

            // Bold: **text** or __text__
            applyPattern("\\*\\*(.+?)\\*\\*|__(.+?)__", to: attributedString) { range in
                let font = NSFont.boldSystemFont(ofSize: 14)
                return [.font: font]
            }

            // Italic: *text* or _text_ (but not ** or __)
            applyPattern("(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*)|(?<!_)_(?!_)(.+?)(?<!_)_(?!_)", to: attributedString) { range in
                let font = NSFont.systemFont(ofSize: 14).italic()
                return [.font: font, .obliqueness: 0.15 as NSNumber]
            }
        }

        private func applyInlineCode(to attributedString: NSMutableAttributedString) {
            let text = attributedString.string

            // Inline code: `code`
            applyPattern("`([^`]+)`", to: attributedString) { range in
                let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
                let backgroundColor = NSColor.controlBackgroundColor
                return [
                    .font: font,
                    .backgroundColor: backgroundColor,
                    .foregroundColor: NSColor.systemPink
                ]
            }
        }

        private func applyCodeBlocks(to attributedString: NSMutableAttributedString) {
            let text = attributedString.string

            // Code blocks: ```language\ncode\n```
            let pattern = "```[\\w]*\\n[\\s\\S]*?```"

            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

            let matches = regex.matches(in: text, range: NSRange(location: 0, length: text.count))

            for match in matches {
                let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
                let backgroundColor = NSColor.controlBackgroundColor

                attributedString.addAttribute(.font, value: font, range: match.range)
                attributedString.addAttribute(.backgroundColor, value: backgroundColor, range: match.range)
                attributedString.addAttribute(.foregroundColor, value: NSColor.systemGreen, range: match.range)
            }
        }

        private func applyLinks(to attributedString: NSMutableAttributedString) {
            let text = attributedString.string

            // Markdown links: [text](url)
            let pattern = "\\[([^\\]]+)\\]\\(([^\\)]+)\\)"

            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

            let matches = regex.matches(in: text, range: NSRange(location: 0, length: text.count))

            for match in matches {
                let linkTextRange = match.range(at: 1)

                // Style the link text
                attributedString.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: linkTextRange)
                attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: linkTextRange)

                // Dim the markdown syntax
                let fullRange = match.range
                if let textRange = Range(fullRange, in: text) {
                    let linkText = text[textRange]
                    // Find bracket and parenthesis positions
                    if let openBracket = linkText.firstIndex(of: "["),
                       let closeBracket = linkText.firstIndex(of: "]"),
                       let openParen = linkText.firstIndex(of: "("),
                       let closeParen = linkText.lastIndex(of: ")") {

                        let openBracketOffset = linkText.distance(from: linkText.startIndex, to: openBracket)
                        let closeBracketOffset = linkText.distance(from: linkText.startIndex, to: closeBracket)
                        let openParenOffset = linkText.distance(from: linkText.startIndex, to: openParen)
                        let closeParenOffset = linkText.distance(from: linkText.startIndex, to: closeParen)

                        // Dim brackets and parentheses
                        let dimColor = NSColor.secondaryLabelColor
                        let smallFont = NSFont.systemFont(ofSize: 11)

                        attributedString.addAttribute(.foregroundColor, value: dimColor, range: NSRange(location: fullRange.location + openBracketOffset, length: 1))
                        attributedString.addAttribute(.foregroundColor, value: dimColor, range: NSRange(location: fullRange.location + closeBracketOffset, length: 1))
                        attributedString.addAttribute(.foregroundColor, value: dimColor, range: NSRange(location: fullRange.location + openParenOffset, length: closeParenOffset - openParenOffset + 1))

                        attributedString.addAttribute(.font, value: smallFont, range: NSRange(location: fullRange.location + openBracketOffset, length: 1))
                        attributedString.addAttribute(.font, value: smallFont, range: NSRange(location: fullRange.location + closeBracketOffset, length: 1))
                        attributedString.addAttribute(.font, value: smallFont, range: NSRange(location: fullRange.location + openParenOffset, length: closeParenOffset - openParenOffset + 1))
                    }
                }
            }
        }

        private func applyLists(to attributedString: NSMutableAttributedString) {
            let text = attributedString.string

            // Unordered lists: - item or * item
            let pattern = "^[\\s]*[-*]\\s+(.+)$"

            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return }

            let matches = regex.matches(in: text, range: NSRange(location: 0, length: text.count))

            for match in matches {
                let markerRange = NSRange(location: match.range.location, length: 2)

                // Style the list marker
                attributedString.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: markerRange)
            }
        }

        private func applyPattern(_ pattern: String, to attributedString: NSMutableAttributedString, attributes: (NSRange) -> [NSAttributedString.Key: Any]) {
            let text = attributedString.string

            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

            let matches = regex.matches(in: text, range: NSRange(location: 0, length: text.count))

            for match in matches {
                // Find the content range (first captured group)
                let contentRange = match.numberOfRanges > 1 ? match.range(at: 1) : match.range

                if contentRange.location != NSNotFound {
                    let attrs = attributes(contentRange)
                    for (key, value) in attrs {
                        attributedString.addAttribute(key, value: value, range: contentRange)
                    }

                    // Dim the markdown syntax markers
                    let fullRange = match.range
                    let markerColor = NSColor.tertiaryLabelColor
                    let markerFont = NSFont.systemFont(ofSize: 11)

                    // Style opening marker
                    if contentRange.location > fullRange.location {
                        let openingLength = contentRange.location - fullRange.location
                        let openingRange = NSRange(location: fullRange.location, length: openingLength)
                        attributedString.addAttribute(.foregroundColor, value: markerColor, range: openingRange)
                        attributedString.addAttribute(.font, value: markerFont, range: openingRange)
                    }

                    // Style closing marker
                    let contentEnd = contentRange.location + contentRange.length
                    let fullEnd = fullRange.location + fullRange.length
                    if contentEnd < fullEnd {
                        let closingLength = fullEnd - contentEnd
                        let closingRange = NSRange(location: contentEnd, length: closingLength)
                        attributedString.addAttribute(.foregroundColor, value: markerColor, range: closingRange)
                        attributedString.addAttribute(.font, value: markerFont, range: closingRange)
                    }
                }
            }
        }

        // MARK: - Slash Command Support

        @MainActor
        private func checkForSlashCommand(in textView: NSTextView) {
            let cursorPosition = textView.selectedRange().location
            let text = textView.string

            guard cursorPosition > 0 && cursorPosition <= text.count else {
                dismissSlashCommands()
                return
            }

            // Look backwards from cursor to find "/" at start of line or after whitespace
            let searchStart = text.index(text.startIndex, offsetBy: max(0, cursorPosition - 50))
            let searchEnd = text.index(text.startIndex, offsetBy: cursorPosition)
            let searchRange = searchStart..<searchEnd
            let searchText = String(text[searchRange])

            // Find the last "/" in the search range
            if let lastSlashIndex = searchText.lastIndex(of: "/") {
                let beforeSlash = lastSlashIndex > searchText.startIndex ? searchText.index(before: lastSlashIndex) : nil
                let isAtLineStart = beforeSlash == nil || beforeSlash.map { searchText[$0].isNewline } ?? true
                let isAfterWhitespace = beforeSlash.map { searchText[$0].isWhitespace } ?? false

                if isAtLineStart || isAfterWhitespace {
                    // Calculate the query after the slash
                    let queryStart = searchText.index(after: lastSlashIndex)
                    let query = String(searchText[queryStart...])

                    // Check if query contains newline (slash command should be on same line)
                    if !query.contains(where: { $0.isNewline }) {
                        // Calculate absolute position of slash
                        let slashOffset = searchText.distance(from: searchText.startIndex, to: lastSlashIndex)
                        let absoluteSlashLocation = max(0, cursorPosition - searchText.count) + slashOffset

                        slashStartLocation = absoluteSlashLocation
                        slashQuery?.wrappedValue = query

                        // Get position for popup
                        if let layoutManager = textView.layoutManager,
                           let textContainer = textView.textContainer {
                            let glyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: absoluteSlashLocation, length: 1), actualCharacterRange: nil)
                            let glyphRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

                            // Convert to text view coordinates
                            var rectInTextView = glyphRect
                            rectInTextView.origin.x += textContainer.lineFragmentPadding
                            rectInTextView.origin.y += textView.textContainerInset.height

                            // Convert to scroll view coordinates
                            if let scrollView = textView.enclosingScrollView {
                                let rectInScrollView = textView.convert(rectInTextView, to: scrollView)

                                // Store the position (bottom-left of the character)
                                let position = NSPoint(x: rectInScrollView.minX, y: rectInScrollView.maxY + 4)
                                slashCommandPosition?.wrappedValue = position
                            }
                        }

                        showSlashCommands?.wrappedValue = true
                        return
                    }
                }
            }

            // No valid slash command found
            dismissSlashCommands()
        }

        private func dismissSlashCommands() {
            showSlashCommands?.wrappedValue = false
            slashStartLocation = nil
            slashQuery?.wrappedValue = ""
        }

        @MainActor
        func insertSlashCommand(_ command: SlashCommand) {
            guard let textView = textView,
                  let slashStart = slashStartLocation else { return }

            let currentText = textView.string
            let cursorPosition = textView.selectedRange().location

            // Calculate range to replace (from slash to cursor)
            let replaceRange = NSRange(location: slashStart, length: cursorPosition - slashStart)

            // Replace the slash and query with the command template
            if let range = Range(replaceRange, in: currentText) {
                var newText = currentText
                newText.replaceSubrange(range, with: command.template)

                isUpdatingFormatting = true
                let attributedString = parseMarkdown(newText)
                textView.textStorage?.setAttributedString(attributedString)
                isUpdatingFormatting = false

                text = newText
                onTextChange?(newText)

                // Position cursor at end of inserted template
                let newCursorPosition = slashStart + command.template.count
                textView.setSelectedRange(NSRange(location: newCursorPosition, length: 0))
            }

            dismissSlashCommands()
        }
    }
}

// MARK: - Helper Extensions

extension NSFont {
    func italic() -> NSFont {
        let descriptor = fontDescriptor.withSymbolicTraits(.italic)
        return NSFont(descriptor: descriptor, size: pointSize) ?? self
    }
}
