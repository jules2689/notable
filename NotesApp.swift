import SwiftUI

@main
struct NotesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Note") {
                    // TODO: Implement new note creation
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}
