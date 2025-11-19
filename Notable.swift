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
