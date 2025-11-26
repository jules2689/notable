import SwiftUI
import AppKit

// Notification for tab actions
extension Notification.Name {
    static let closeCurrentTab = Notification.Name("closeCurrentTab")
    static let newTab = Notification.Name("newTab")
    static let noteSelectedFromSidebar = Notification.Name("noteSelectedFromSidebar")
    static let noteOpenInNewTab = Notification.Name("noteOpenInNewTab")
    static let moveTabLeft = Notification.Name("moveTabLeft")
    static let moveTabRight = Notification.Name("moveTabRight")
}

// App delegate to configure window appearance (using custom tabs instead of native)
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var eventMonitor: Any?
    
    nonisolated func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            // Completely disable automatic window tabbing
            NSWindow.allowsAutomaticWindowTabbing = false
            
            // Configure all windows with delay to ensure SwiftUI has set them up
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                for window in NSApp.windows {
                    self.configureWindow(window)
                }
            }
            
            // Remove help search field from menu (with delay to ensure menu is set up)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.removeHelpSearchField()
            }
            
            // Observe new windows being created
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidBecomeMain(_:)),
                name: NSWindow.didBecomeMainNotification,
                object: nil
            )
            
            // Also observe when windows appear or update
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidUpdate(_:)),
                name: NSWindow.didUpdateNotification,
                object: nil
            )
            
            // Observe menu updates to remove help search if it reappears
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(menuDidChange(_:)),
                name: NSMenu.didChangeItemNotification,
                object: nil
            )
            
            // Intercept CMD-W, CMD-T, CMD-Shift-[, CMD-Shift-] to handle tabs
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.modifierFlags.contains(.command) {
                    if event.charactersIgnoringModifiers == "w" {
                        NotificationCenter.default.post(name: .closeCurrentTab, object: nil)
                        return nil
                    }
                    if event.charactersIgnoringModifiers == "t" {
                        NotificationCenter.default.post(name: .newTab, object: nil)
                        return nil
                    }
                    // CMD+Shift+[ to move tab left
                    if event.modifierFlags.contains(.shift) && event.charactersIgnoringModifiers == "[" {
                        NotificationCenter.default.post(name: .moveTabLeft, object: nil)
                        return nil
                    }
                    // CMD+Shift+] to move tab right
                    if event.modifierFlags.contains(.shift) && event.charactersIgnoringModifiers == "]" {
                        NotificationCenter.default.post(name: .moveTabRight, object: nil)
                        return nil
                    }
                }
                return event
            }
        }
    }
    
    nonisolated func applicationWillTerminate(_ notification: Notification) {
        Task { @MainActor in
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
    
    @objc func windowDidBecomeMain(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            configureWindow(window)
        }
    }
    
    @objc func windowDidUpdate(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            // Re-apply window configuration to ensure titlebar stays hidden
            configureWindow(window)
            if window.toolbar != nil {
                window.toolbar = nil
            }
            hideNewTabButton(in: window)
        }
    }
    
    private func hideNewTabButton(in window: NSWindow) {
        guard let titlebarView = window.standardWindowButton(.closeButton)?.superview?.superview else { return }
        findAndHideNewTabButton(in: titlebarView)
    }
    
    private func findAndHideNewTabButton(in view: NSView) {
        let className = String(describing: type(of: view))
        if className.contains("Button") && !className.contains("_NSThemeWidget") {
            // Check if it's positioned to the right (the + button is on the right side)
            if let superview = view.superview, view.frame.origin.x > superview.bounds.width / 2 {
                if view.frame.width < 40 && view.frame.height < 40 {
                    // Hide both the button and its superview to remove the line
                    view.isHidden = true
                    view.superview?.isHidden = true
                }
            }
        }
        for subview in view.subviews {
            findAndHideNewTabButton(in: subview)
        }
    }
    
    private func configureWindow(_ window: NSWindow) {
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.styleMask.insert(.fullSizeContentView)
        window.tabbingMode = .disallowed
        window.toolbar = nil
        window.tab.title = ""
        window.isMovable = false  // Disable native dragging so tab dragging works
    }
    
    private func removeHelpSearchField() {
        guard let helpMenu = NSApp.mainMenu?.item(withTitle: "Help")?.submenu else { return }
        
        // Find and remove the help search field
        // The search field is typically an NSMenuItem with a custom view containing NSSearchField
        var itemsToRemove: [NSMenuItem] = []
        
        for item in helpMenu.items {
            // Check if the item has a view with a search field
            if let view = item.view {
                // Check if the view itself is a search field or contains one
                if view.isKind(of: NSSearchField.self) {
                    itemsToRemove.append(item)
                } else {
                    // Check subviews recursively
                    func hasSearchField(in view: NSView) -> Bool {
                        if view.isKind(of: NSSearchField.self) {
                            return true
                        }
                        return view.subviews.contains(where: hasSearchField)
                    }
                    if hasSearchField(in: view) {
                        itemsToRemove.append(item)
                    }
                }
            }
        }
        
        // Remove all found search field items
        for item in itemsToRemove {
            helpMenu.removeItem(item)
        }
    }
    
    @objc func menuDidChange(_ notification: Notification) {
        // Re-remove help search field if it reappears
        removeHelpSearchField()
    }
}

@main
struct Notable: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            // Remove "Show Tab Bar" menu item  
            CommandGroup(replacing: .toolbar) { }
            
            CommandGroup(replacing: .newItem) {
                NewNoteButton()
            }
            
            // Add Close to File menu (after New)
            CommandGroup(after: .newItem) {
                Button("Close") {
                    NotificationCenter.default.post(name: .closeCurrentTab, object: nil)
                }
                .keyboardShortcut("w", modifiers: .command)
            }
            
            CommandGroup(replacing: .saveItem) {
                SaveButton()
            }
            
            // Add Settings to the app menu (after About)
            CommandGroup(after: .appInfo) {
                Divider()
                SettingsButton()
            }
            
            // Help menu
            CommandGroup(replacing: .help) {
                HelpButton()
                Divider()
                KeyboardShortcutsButton()
                Divider()
                Button("Report a Bug") {
                    if let url = URL(string: "https://github.com/jules2689/notable/issues") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
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

struct SaveButton: View {
    @FocusedValue(\.saveAction) private var saveAction: (() -> Void)?

    var body: some View {
        Button("Save") {
            saveAction?()
        }
        .keyboardShortcut("s", modifiers: .command)
        .disabled(saveAction == nil)
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

struct HelpButton: View {
    @FocusedValue(\.notesViewModel) private var viewModel: NotesViewModel?
    @FocusedValue(\.showingHelp) private var showingHelp: Binding<Bool>?

    var body: some View {
        Button("Notable Help") {
            showingHelp?.wrappedValue = true
        }
        .keyboardShortcut("?", modifiers: .command)
        .disabled(viewModel == nil || showingHelp == nil)
    }
}

struct KeyboardShortcutsButton: View {
    @FocusedValue(\.showingKeyboardShortcuts) private var showingKeyboardShortcuts: Binding<Bool>?

    var body: some View {
        Button("Keyboard Shortcuts") {
            showingKeyboardShortcuts?.wrappedValue = true
        }
        .keyboardShortcut("/", modifiers: .command)
        .disabled(showingKeyboardShortcuts == nil)
    }
}

