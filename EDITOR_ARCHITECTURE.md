# Editor Architecture

## Active Editor

The application uses **RichTextEditor** as the primary text editing component.

### Implementation Details

- **Location**: `Views/RichTextEditor.swift`
- **Type**: WKWebView-based editor using HTML/JavaScript
- **HTML Resource**: `Resources/RichEditor.html`
- **Usage**: Used in `EditorView.swift` (line 15)

### Architecture

The `RichTextEditor` is a SwiftUI `NSViewRepresentable` that wraps a `WKWebView`. The editor functionality is implemented in JavaScript within the `RichEditor.html` file, which provides:

- Contenteditable HTML editing
- Markdown support
- Real-time text change notifications via message handlers
- Table editing capabilities
- Slash command support (handled in JavaScript)

### Communication

The Swift code communicates with the JavaScript editor through:
- **Message Handlers**: `ready` and `textChange`
- **JavaScript Evaluation**: `window.setContent()` to set editor content
- **Coordinator Pattern**: Handles bidirectional communication between Swift and JavaScript

### Integration

The editor is integrated into the app through `EditorView`, which:
- Manages the edited content state
- Handles auto-save functionality
- Provides save status indicators
- Manages note switching

## Historical Note

Previously, the project included two alternative editor implementations that have been removed:
- `WYSIWYMTextEditor` - NSTextView-based editor with inline markdown rendering
- `SlashCommandTextEditor` - NSTextView-based editor with slash command support

These were unused and have been removed from the project.

