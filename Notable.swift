import SwiftUI
import AppKit

// App delegate to configure window tabbing
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Enable automatic window tabbing globally
        NSWindow.allowsAutomaticWindowTabbing = true
    }
}

@main
struct Notable: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow
    
    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                NewNoteButton()
            }
            
            CommandGroup(after: .appSettings) {
                SettingsButton()
            }
            
            // Add New Tab to Window menu
            CommandGroup(after: .windowArrangement) {
                NewTabButton()
            }
        }
    }
}

struct NewTabButton: View {
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        Button("New Tab") {
            guard let currentWindow = NSApp.keyWindow else {
                openWindow(id: "main")
                return
            }
            
            // Store reference to current window before opening new one
            let targetWindow = currentWindow
            let existingWindowNumbers = Set(NSApp.windows.map { $0.windowNumber })
            
            // Set up observer BEFORE opening the window to catch it immediately
            var observer: NSObjectProtocol?
            observer = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: nil,
                queue: .main
            ) { notification in
                guard let newWindow = notification.object as? NSWindow,
                      !existingWindowNumbers.contains(newWindow.windowNumber),
                      newWindow != targetWindow else { return }
                
                // Remove observer immediately
                if let obs = observer {
                    NotificationCenter.default.removeObserver(obs)
                }
                
                // Add the new window as a tab to the original window
                targetWindow.addTabbedWindow(newWindow, ordered: .above)
            }
            
            // Open new window
            openWindow(id: "main")
        }
        .keyboardShortcut("t", modifiers: .command)
    }
}

struct NewNoteButton: View {
    @FocusedValue(\.notesViewModel) private var viewModel: NotesViewModel?

    var body: some View {
        Button("New Note") {
            Task {
                await viewModel?.createNote(title: "Untitled")
            }
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

