import SwiftUI

struct HelpNoteView: View {
    var viewModel: NotesViewModel?
    @Environment(\.dismiss) private var dismiss
    @State private var helpContent: String = ""
    @State private var markdownBlocks: [MarkdownBlock] = []
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(Array(markdownBlocks.enumerated()), id: \.offset) { _, block in
                        renderBlock(block)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Notable Help")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .frame(width: 700, height: 600)
            .onAppear {
                loadHelpContent()
            }
        }
    }
    
    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(text)
                .font(level == 1 ? .largeTitle : (level == 2 ? .title : .title3))
                .fontWeight(.bold)
                .padding(.top, level == 1 ? 0 : 8)
                .textSelection(.enabled)
        case .paragraph(let text):
            Text(parseInlineMarkdown(text))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        case .list(let items, let ordered):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 8) {
                        if ordered {
                            Text("\(index + 1).")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                        } else {
                            Text("•")
                                .foregroundColor(.secondary)
                        }
                        Text(parseInlineMarkdown(item))
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.leading, 8)
        }
    }
    
    private func parseInlineMarkdown(_ text: String) -> AttributedString {
        do {
            return try AttributedString(markdown: text)
        } catch {
            return AttributedString(text)
        }
    }
    
    private func loadHelpContent() {
        helpContent = """
# Notable Help Guide

## Overview

Notable is a markdown-based note-taking application designed for macOS. It provides a clean interface for organizing and editing notes with support for folders, tabs, and rich text editing.

## Getting Started

### Creating Notes

To create a new note, use the plus button in the sidebar header or press Command-N. New notes are created as markdown files with the .md extension. The note title is derived from the filename, and you can rename notes by editing the filename.

### Organizing Notes

Notes can be organized into folders. Create a new folder using the plus button menu in the sidebar. You can drag and drop notes and folders to reorganize your workspace. The folder structure is reflected in the file system, with folders corresponding to directories.

### Editing Notes

The editor supports markdown syntax and provides a rich text editing experience. Content is automatically saved as you type. The save status is displayed in the sidebar footer, along with word count and estimated reading time.

## Tab Management

Notable supports multiple tabs for working with several notes simultaneously. Each tab represents an open note or an empty editing space.

### Creating Tabs

Create a new tab by clicking the plus button in the tab bar or pressing Command-T. New tabs start empty and can be used to create new notes or open existing ones.

### Switching Between Tabs

Click any tab to switch to it. You can also use Command-Shift-Left Bracket to move the current tab left, or Command-Shift-Right Bracket to move it right.

### Closing Tabs

Close the current tab by pressing Command-W or clicking the close button on the tab. If the tab contains unsaved changes, they will be saved automatically before closing.

## Search

The search bar in the sidebar allows you to quickly find notes by title or content. As you type, the sidebar filters to show matching notes. The search is case-insensitive and matches partial text.

## Settings

Access settings by pressing Command-Comma or selecting Settings from the app menu. The settings panel allows you to configure:

- Appearance: Choose between light, dark, or system appearance
- Storage Location: Configure where notes are stored, including support for WebDAV servers
- Display Options: Toggle word count and reading time display in the sidebar footer

### Storage Options

Notable supports three storage options:

1. Default Location: Notes are stored in the app's default directory
2. Custom Location: Choose a specific folder on your Mac for note storage
3. WebDAV: Sync notes with a WebDAV server for cloud storage and synchronization

When using WebDAV, configure the server URL, username, and password in settings. The app will test the connection before saving the configuration.

## Keyboard Shortcuts

- Command-N: Create a new note
- Command-S: Save the current note
- Command-T: Create a new tab
- Command-W: Close the current tab
- Command-Shift-[: Move current tab left
- Command-Shift-]: Move current tab right
- Command-Comma: Open settings
- Command-?: Open this help guide

## File Management

Notes are stored as plain markdown files. This means you can access your notes directly in the file system, edit them with other applications, or use version control systems like Git to track changes.

The file structure mirrors your folder organization. Each folder in Notable corresponds to a directory, and notes are stored as .md files within those directories.

## Tips

- Use folders to organize related notes into projects or categories
- Take advantage of tabs to keep multiple notes open for reference while editing
- The sidebar can be toggled using the sidebar button in the tab bar
- Notes are saved automatically, but you can manually save using Command-S
- Word count and reading time are calculated based on the current note content

## Troubleshooting

If you encounter issues with note loading or saving, check the storage location settings. For WebDAV connections, verify that the server URL and credentials are correct. The app will display error messages if operations fail.

Logs are stored in the app's container directory and can be accessed from the settings panel for debugging purposes.
"""
        
        // Parse markdown into blocks
        markdownBlocks = parseMarkdown(helpContent)
    }
    
    private func parseMarkdown(_ content: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = content.components(separatedBy: .newlines)
        var i = 0
        
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            
            if line.isEmpty {
                i += 1
                continue
            }
            
            // Check for headings
            if line.hasPrefix("#") {
                let level = line.prefix(while: { $0 == "#" }).count
                let text = String(line.dropFirst(level).trimmingCharacters(in: .whitespaces))
                blocks.append(.heading(level: level, text: text))
                i += 1
                continue
            }
            
            // Check for ordered list
            if line.range(of: #"^\d+\.\s+"#, options: .regularExpression) != nil {
                var listItems: [String] = []
                
                while i < lines.count {
                    let currentLine = lines[i].trimmingCharacters(in: .whitespaces)
                    if currentLine.range(of: #"^\d+\.\s+"#, options: .regularExpression) != nil {
                        // Extract text after "number. " by removing the prefix
                        let item = currentLine.replacingOccurrences(of: #"^\d+\.\s+"#, with: "", options: .regularExpression)
                        listItems.append(item)
                        i += 1
                    } else if currentLine.isEmpty {
                        i += 1
                        break
                    } else {
                        break
                    }
                }
                
                if !listItems.isEmpty {
                    blocks.append(.list(items: listItems, ordered: true))
                    continue
                }
            }
            
            // Check for unordered list
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                var listItems: [String] = []
                
                while i < lines.count {
                    let currentLine = lines[i].trimmingCharacters(in: .whitespaces)
                    if currentLine.hasPrefix("- ") {
                        listItems.append(String(currentLine.dropFirst(2)))
                        i += 1
                    } else if currentLine.hasPrefix("* ") {
                        listItems.append(String(currentLine.dropFirst(2)))
                        i += 1
                    } else if currentLine.isEmpty {
                        i += 1
                        break
                    } else {
                        break
                    }
                }
                
                if !listItems.isEmpty {
                    blocks.append(.list(items: listItems, ordered: false))
                    continue
                }
            }
            
            // Regular paragraph
            var paragraphLines: [String] = [line]
            i += 1
            
            while i < lines.count {
                let nextLine = lines[i].trimmingCharacters(in: .whitespaces)
                if nextLine.isEmpty || nextLine.hasPrefix("#") || nextLine.hasPrefix("- ") || nextLine.hasPrefix("* ") || nextLine.range(of: #"^\d+\.\s+"#, options: .regularExpression) != nil {
                    break
                }
                paragraphLines.append(nextLine)
                i += 1
            }
            
            let paragraphText = paragraphLines.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            if !paragraphText.isEmpty {
                blocks.append(.paragraph(text: paragraphText))
            }
        }
        
        return blocks
    }
}

enum MarkdownBlock {
    case heading(level: Int, text: String)
    case paragraph(text: String)
    case list(items: [String], ordered: Bool)
}

