import SwiftUI

struct KeyboardShortcutsView: View {
    @Environment(\.dismiss) private var dismiss
    
    struct Shortcut: Identifiable {
        let id = UUID()
        let action: String
        let shortcut: String
    }
    
    let shortcuts: [Shortcut] = [
        Shortcut(action: "New Note", shortcut: "⌘N"),
        Shortcut(action: "Save", shortcut: "⌘S"),
        Shortcut(action: "New Tab", shortcut: "⌘T"),
        Shortcut(action: "Close Tab", shortcut: "⌘W"),
        Shortcut(action: "Move Tab Left", shortcut: "⌘⇧["),
        Shortcut(action: "Move Tab Right", shortcut: "⌘⇧]"),
        Shortcut(action: "Settings", shortcut: "⌘,"),
        Shortcut(action: "Keyboard Shortcuts", shortcut: "⌘/"),
        Shortcut(action: "Notable Help", shortcut: "⌘?")
    ]
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(shortcuts) { shortcut in
                    HStack {
                        Text(shortcut.action)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(shortcut.shortcut)
                            .textSelection(.enabled)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 8)
            .frame(width: 500)
            .fixedSize(horizontal: false, vertical: true)
            .navigationTitle("Keyboard Shortcuts")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

