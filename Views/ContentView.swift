import SwiftUI
import AppKit

// Define a focused value key for the view model
struct NotesViewModelKey: FocusedValueKey {
    typealias Value = NotesViewModel
}

// Define a focused value key for showing settings
struct ShowingSettingsKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

// Define focused value key for save action
struct SaveActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var notesViewModel: NotesViewModel? {
        get { self[NotesViewModelKey.self] }
        set { self[NotesViewModelKey.self] = newValue }
    }
    
    var showingSettings: Binding<Bool>? {
        get { self[ShowingSettingsKey.self] }
        set { self[ShowingSettingsKey.self] = newValue }
    }
    
    var saveAction: (() -> Void)? {
        get { self[SaveActionKey.self] }
        set { self[SaveActionKey.self] = newValue }
    }
}

struct ContentView: View {
    @State private var viewModel = NotesViewModel()
    @State private var searchText = ""
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showingSettings = false
    @State private var editedContent = ""
    @State private var isSaved = true
    @State private var saveAction: (() -> Void)?
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    
    // Tab management
    @State private var openTabs: [TabItem] = []
    @State private var selectedTabID: UUID?
    @State private var isSelectingTab = false  // Prevent onChange from updating tabs during tab switch

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                viewModel: viewModel,
                searchText: $searchText,
                editedContent: $editedContent,
                isSaved: $isSaved,
                onSave: { saveAction?() }
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 400)
        } detail: {
            EditorView(
                viewModel: viewModel,
                editedContent: $editedContent,
                isSaved: $isSaved,
                openTabs: $openTabs,
                selectedTabID: $selectedTabID,
                onSaveActionReady: { action in
                    saveAction = action
                },
                onSelectTab: selectTab,
                onCloseTab: closeTab,
                onNewTab: createNewTab
            )
            .toolbar(.hidden)
            .navigationSplitViewColumnWidth(min: 400, ideal: 800)
        }
        .toolbar(.hidden)
        .navigationSplitViewStyle(.balanced)
        .preferredColorScheme(appearanceMode.effectiveColorScheme())
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .focusedValue(\.notesViewModel, viewModel)
        .focusedValue(\.showingSettings, $showingSettings)
        .focusedValue(\.saveAction, saveAction)
        .onReceive(NotificationCenter.default.publisher(for: .closeCurrentTab)) { _ in
            closeCurrentTab()
        }
        .onReceive(NotificationCenter.default.publisher(for: .newTab)) { _ in
            createNewTab()
        }
        .onReceive(NotificationCenter.default.publisher(for: .noteSelectedFromSidebar)) { notification in
            print("📝 Received noteSelectedFromSidebar notification")
            if let note = notification.object as? Note {
                print("📝 Note found: \(note.title)")
                updateCurrentTabWithNote(note)
            } else {
                print("📝 Failed to cast notification.object to Note")
            }
        }
        .onChange(of: viewModel.currentNote?.id) { oldID, newID in
            // Only update tab when selecting from sidebar, not when switching tabs
            guard !isSelectingTab else {
                print("📝 onChange: Skipping (isSelectingTab)")
                return
            }
            print("📝 onChange currentNote: old=\(String(describing: oldID)), new=\(String(describing: newID))")
            if let note = viewModel.currentNote {
                print("📝 onChange: Updating tab for \(note.title)")
                updateCurrentTabWithNote(note)
            }
        }
    }
    
    // MARK: - Tab Management
    
    private func closeCurrentTab() {
        guard let currentTabID = selectedTabID,
              let currentTab = openTabs.first(where: { $0.id == currentTabID }) else { return }
        closeTab(currentTab)
    }
    
    private func createNewTab() {
        let newTab = TabItem.empty()
        openTabs.append(newTab)
        selectedTabID = newTab.id
        viewModel.currentNote = nil
        viewModel.selectedNoteItem = nil
    }
    
    private func updateCurrentTabWithNote(_ note: Note) {
        print("📝 updateCurrentTabWithNote: \(note.title), tabs: \(openTabs.count), selectedID: \(String(describing: selectedTabID))")
        
        if openTabs.isEmpty {
            print("📝 Creating first tab for \(note.title)")
            let newTab = TabItem.forNote(note)
            openTabs.append(newTab)
            selectedTabID = newTab.id
            return
        }
        
        if let currentTabID = selectedTabID,
           let currentIndex = openTabs.firstIndex(where: { $0.id == currentTabID }) {
            print("📝 Updating tab at index \(currentIndex) with \(note.title)")
            openTabs[currentIndex] = TabItem(
                id: currentTabID,
                noteID: note.id,
                title: note.title,
                fileURL: note.fileURL
            )
        } else {
            print("📝 No current tab, creating new for \(note.title)")
            let newTab = TabItem.forNote(note)
            openTabs.append(newTab)
            selectedTabID = newTab.id
        }
    }
    
    private func selectTab(_ tab: TabItem) {
        isSelectingTab = true  // Prevent onChange from updating this tab
        selectedTabID = tab.id
        
        if tab.isEmpty {
            viewModel.currentNote = nil
            viewModel.selectedNoteItem = nil
        } else if let fileURL = tab.fileURL, let note = findNote(by: fileURL) {
            print("📝 selectTab: Loading note \(note.title) for tab")
            viewModel.selectNote(note)
        }
        
        // Reset flag after a short delay to ensure onChange has processed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isSelectingTab = false
        }
    }
    
    private func closeTab(_ tab: TabItem) {
        guard let index = openTabs.firstIndex(where: { $0.id == tab.id }) else { return }
        
        openTabs.remove(at: index)
        
        if selectedTabID == tab.id {
            if !openTabs.isEmpty {
                let newIndex = min(index, openTabs.count - 1)
                selectTab(openTabs[newIndex])
            } else {
                selectedTabID = nil
                viewModel.currentNote = nil
                viewModel.selectedNoteItem = nil
            }
        }
    }
    
    private func findNote(by fileURL: URL) -> Note? {
        func searchItems(_ items: [NoteItem]) -> Note? {
            for item in items {
                switch item {
                case .note(let note):
                    if note.fileURL == fileURL {
                        return note
                    }
                case .folder(let folder):
                    if let found = searchItems(folder.children) {
                        return found
                    }
                }
            }
            return nil
        }
        return searchItems(viewModel.noteItems)
    }
}

#Preview {
    ContentView()
}
