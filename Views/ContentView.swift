import SwiftUI
import AppKit

// Extension to make NavigationSplitViewVisibility storable
extension NavigationSplitViewVisibility: RawRepresentable {
    public var rawValue: String {
        switch self {
        case .automatic: return "automatic"
        case .doubleColumn: return "doubleColumn"
        case .all: return "all"
        case .detailOnly: return "detailOnly"
        default: return "all"
        }
    }
    
    public init?(rawValue: String) {
        switch rawValue {
        case "automatic": self = .automatic
        case "doubleColumn": self = .doubleColumn
        case "all": self = .all
        case "detailOnly": self = .detailOnly
        default: self = .all
        }
    }
}

// PreferenceKey to track sidebar width
struct SidebarWidthKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 250
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

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
    @AppStorage("sidebarVisibility") private var columnVisibility: NavigationSplitViewVisibility = .all
    @AppStorage("sidebarWidth") private var sidebarWidth: Double = 250
    @State private var showingSettings = false
    @State private var editedContent = ""
    @State private var isSaved = true
    @State private var saveAction: (() -> Void)?
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    
    // Tab management
    @AppStorage("openTabs") private var openTabsData: Data = Data()
    @State private var openTabs: [TabItem] = []
    @AppStorage("selectedTabID") private var selectedTabIDString: String = ""
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
            .navigationSplitViewColumnWidth(min: 100, ideal: sidebarWidth, max: 400)
            .background(
                GeometryReader { geometry in
                    Color.clear.preference(key: SidebarWidthKey.self, value: geometry.size.width)
                }
            )
            .onPreferenceChange(SidebarWidthKey.self) { width in
                // Persist the actual sidebar width when it changes
                if width > 0 && columnVisibility == .all {
                    sidebarWidth = width
                }
            }
        } detail: {
            EditorView(
                viewModel: viewModel,
                editedContent: $editedContent,
                isSaved: $isSaved,
                openTabs: $openTabs,
                selectedTabID: $selectedTabID,
                columnVisibility: $columnVisibility,
                onSaveActionReady: { action in
                    saveAction = action
                },
                onSelectTab: selectTab,
                onCloseTab: closeTab,
                onNewTab: createNewTab
            )
            .navigationSplitViewColumnWidth(min: 400, ideal: 800)
        }
        .navigationSplitViewStyle(.balanced)
        .transaction { transaction in
            // Override NavigationSplitView's default animation to use linear (no bounce)
            if transaction.animation != nil {
                transaction.animation = .linear(duration: 0.35)
            }
        }
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
        .onReceive(NotificationCenter.default.publisher(for: .noteOpenInNewTab)) { notification in
            print("📝 Received noteOpenInNewTab notification (shift-click)")
            if let note = notification.object as? Note {
                openNoteInNewTab(note)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .moveTabLeft)) { _ in
            moveCurrentTab(direction: -1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .moveTabRight)) { _ in
            moveCurrentTab(direction: 1)
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
        .onChange(of: openTabs) { _, _ in
            // Persist tabs whenever they change
            persistTabs()
        }
        .onChange(of: selectedTabID) { _, newID in
            // Persist selected tab ID
            selectedTabIDString = newID?.uuidString ?? ""
        }
        .onAppear {
            // Restore tabs on app launch after notes are loaded
            Task {
                // Wait for notes to load
                while viewModel.isLoading {
                    try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                }
                await MainActor.run {
                    restoreTabs()
                }
            }
        }
        .onChange(of: viewModel.noteItems) { _, newItems in
            // When notes finish loading, verify and update restored tabs
            if !openTabs.isEmpty {
                // Re-verify tabs against newly loaded notes
                var updatedTabs = openTabs
                for (index, tab) in updatedTabs.enumerated() {
                    if tab.isFileMissing, let fileURL = tab.fileURL {
                        // Check if the missing file now exists
                        if findNote(by: fileURL) != nil {
                            // File was found, update tab to normal state
                            if let note = findNote(by: fileURL) {
                                updatedTabs[index] = TabItem.forNote(note)
                            }
                        }
                    } else if !tab.isEmpty, let fileURL = tab.fileURL {
                        // Verify existing tabs still have valid files
                        if findNote(by: fileURL) == nil {
                            // File no longer exists, mark as missing
                            let filename = fileURL.lastPathComponent
                            updatedTabs[index] = TabItem.forMissingFile(filename: filename, fileURL: fileURL)
                        }
                    }
                }
                openTabs = updatedTabs
            } else if !openTabsData.isEmpty {
                // Tabs haven't been restored yet, restore them now
                restoreTabs()
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
    
    private func openNoteInNewTab(_ note: Note) {
        isSelectingTab = true  // Prevent onChange from interfering
        let newTab = TabItem.forNote(note)
        openTabs.append(newTab)
        selectedTabID = newTab.id
        
        // Reset flag after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isSelectingTab = false
        }
    }
    
    private func moveCurrentTab(direction: Int) {
        guard let currentTabID = selectedTabID,
              let currentIndex = openTabs.firstIndex(where: { $0.id == currentTabID }) else { return }
        
        let newIndex = currentIndex + direction
        guard newIndex >= 0 && newIndex < openTabs.count else { return }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            openTabs.move(fromOffsets: IndexSet(integer: currentIndex), toOffset: direction > 0 ? newIndex + 1 : newIndex)
        }
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
                fileURL: note.fileURL,
                isFileMissing: false // Clear missing file flag if note was found
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
        
        if tab.isFileMissing {
            // Missing file tab - show empty state with message
            viewModel.currentNote = nil
            viewModel.selectedNoteItem = nil
        } else if tab.isEmpty {
            // Empty tab
            viewModel.currentNote = nil
            viewModel.selectedNoteItem = nil
        } else if let fileURL = tab.fileURL, let note = findNote(by: fileURL) {
            // Valid note file
            print("📝 selectTab: Loading note \(note.title) for tab")
            viewModel.selectNote(note)
        } else if let fileURL = tab.fileURL {
            // File URL exists but note not found - mark as missing
            let filename = fileURL.lastPathComponent
            if let index = openTabs.firstIndex(where: { $0.id == tab.id }) {
                openTabs[index] = TabItem.forMissingFile(filename: filename, fileURL: fileURL)
            }
            viewModel.currentNote = nil
            viewModel.selectedNoteItem = nil
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
    
    // MARK: - Tab Persistence
    
    private func persistTabs() {
        // Encode tabs to JSON and store in AppStorage
        if let encoded = try? JSONEncoder().encode(openTabs) {
            openTabsData = encoded
        }
    }
    
    private func restoreTabs() {
        // Decode tabs from AppStorage
        guard !openTabsData.isEmpty,
              let decoded = try? JSONDecoder().decode([TabItem].self, from: openTabsData) else {
            // No persisted tabs, start fresh
            return
        }
        
        // Verify each tab's file exists and update state accordingly
        var restoredTabs: [TabItem] = []
        for tab in decoded {
            if tab.isFileMissing {
                // Keep missing file tabs as-is
                restoredTabs.append(tab)
            } else if let fileURL = tab.fileURL {
                // Check if file exists on disk
                let fileManager = FileManager.default
                let fileExists = fileManager.fileExists(atPath: fileURL.path)
                
                // Also check if note exists in the loaded note hierarchy
                let noteExistsInHierarchy = findNote(by: fileURL) != nil
                
                if fileExists && noteExistsInHierarchy {
                    // File exists and is in hierarchy, restore tab normally
                    restoredTabs.append(tab)
                } else {
                    // File doesn't exist or not in hierarchy, mark as missing
                    let filename = fileURL.lastPathComponent
                    let missingTab = TabItem.forMissingFile(filename: filename, fileURL: fileURL)
                    restoredTabs.append(missingTab)
                }
            } else {
                // Empty tab, restore as-is
                restoredTabs.append(tab)
            }
        }
        
        openTabs = restoredTabs
        
        // Restore selected tab ID
        if !selectedTabIDString.isEmpty, let uuid = UUID(uuidString: selectedTabIDString) {
            // Verify the selected tab still exists
            if restoredTabs.contains(where: { $0.id == uuid }) {
                selectedTabID = uuid
            } else if !restoredTabs.isEmpty {
                // Selected tab no longer exists, select first tab
                selectedTabID = restoredTabs.first?.id
            }
        } else if !restoredTabs.isEmpty {
            // No selected tab, select first tab
            selectedTabID = restoredTabs.first?.id
        }
        
        // Load the selected tab's content if it has a valid file
        if let selectedID = selectedTabID,
           let selectedTab = restoredTabs.first(where: { $0.id == selectedID }),
           !selectedTab.isEmpty,
           !selectedTab.isFileMissing,
           let fileURL = selectedTab.fileURL,
           let note = findNote(by: fileURL) {
            viewModel.selectNote(note)
        } else if let selectedID = selectedTabID,
                  let selectedTab = restoredTabs.first(where: { $0.id == selectedID }),
                  selectedTab.isFileMissing {
            // Tab is missing file, clear current note
            viewModel.currentNote = nil
            viewModel.selectedNoteItem = nil
        }
    }
}

#Preview {
    ContentView()
}
