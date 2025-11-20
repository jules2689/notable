import SwiftUI

@main
struct Notable: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                NewNoteButton()
            }
            
            CommandGroup(after: .appSettings) {
                SettingsButton()
            }
        }
    }
}

struct NewNoteButton: View {
    @FocusedValue(\.notesViewModel) private var viewModel: NotesViewModel?

    var body: some View {
        Button("New Note") {
            viewModel?.createNote(title: "Untitled")
        }
        .keyboardShortcut("n", modifiers: .command)
        .disabled(viewModel == nil)
    }
}

struct SettingsButton: View {
    @FocusedValue(\.showingSettings) private var showingSettings: Binding<Bool>?

    var body: some View {
        Button("Settings...") {
            showingSettings?.wrappedValue = true
        }
        .keyboardShortcut(",", modifiers: .command)
        .disabled(showingSettings == nil)
    }
}
