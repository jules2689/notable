import SwiftUI
import AppKit

/// A custom text editor that supports slash commands
struct SlashCommandTextEditor: NSViewRepresentable {
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
        textView.string = text

        // Store coordinator reference
        context.coordinator.textView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        if textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text
            // Restore selection if valid
            if selectedRange.location <= text.count {
                textView.setSelectedRange(selectedRange)
            }
        }

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

        init(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }

            let newText = textView.string
            text = newText
            onTextChange?(newText)

            // Check for slash command trigger
            checkForSlashCommand(in: textView)
        }

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

                            // Convert to scroll view coordinates (the parent of textView)
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

                textView.string = newText
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

extension SlashCommandTextEditor.Coordinator {
    func handleKeyDown(_ event: NSEvent) -> Bool {
        guard showSlashCommands?.wrappedValue == true else {
            return false
        }

        // Let the parent view handle keyboard navigation
        return false
    }
}
