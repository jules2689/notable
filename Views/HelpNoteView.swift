import SwiftUI

struct HelpNoteView: View {
    var viewModel: NotesViewModel?
    @Environment(\.dismiss) private var dismiss
    @State private var helpContent: String = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(helpContent)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
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
    }
}

