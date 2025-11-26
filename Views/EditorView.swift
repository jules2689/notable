import SwiftUI
import Combine
import AppKit

struct EditorView: View {
    var viewModel: NotesViewModel
    @Binding var editedContent: String
    @Binding var isSaved: Bool
    @Binding var openTabs: [TabItem]
    @Binding var selectedTabID: UUID?
    @Binding var columnVisibility: NavigationSplitViewVisibility

    var onSaveActionReady: ((@escaping () -> Void) -> Void)?
    var onSelectTab: (TabItem) -> Void
    var onCloseTab: (TabItem) -> Void
    var onNewTab: () -> Void
    
    @State private var autoSaveTask: Task<Void, Never>?
    @State private var lastSavedContent: String = ""
    @FocusState private var isEditorFocused: Bool
    @State private var hoveredTabID: UUID?
    @State private var editingTabID: UUID?
    @State private var editingTabTitle: String = ""
    @FocusState private var isTabTitleFocused: Bool
    @State private var draggedTabID: UUID?
    @State private var tabBarLeadingPadding: CGFloat = 0 // Padding for traffic lights (0 when sidebar open, 70 when closed)
    @State private var iconPickerTabID: TabID?
    
    // Wrapper for UUID to use with sheet(item:)
    struct TabID: Identifiable {
        let id: UUID
    }
    
    init(viewModel: NotesViewModel, editedContent: Binding<String>, isSaved: Binding<Bool>, openTabs: Binding<[TabItem]>, selectedTabID: Binding<UUID?>, columnVisibility: Binding<NavigationSplitViewVisibility>, onSaveActionReady: ((@escaping () -> Void) -> Void)?, onSelectTab: @escaping (TabItem) -> Void, onCloseTab: @escaping (TabItem) -> Void, onNewTab: @escaping () -> Void) {
        self.viewModel = viewModel
        self._editedContent = editedContent
        self._isSaved = isSaved
        self._openTabs = openTabs
        self._selectedTabID = selectedTabID
        self._columnVisibility = columnVisibility
        self.onSaveActionReady = onSaveActionReady
        self.onSelectTab = onSelectTab
        self.onCloseTab = onCloseTab
        self.onNewTab = onNewTab
        // Initialize tabBarLeadingPadding based on current sidebar state
        _tabBarLeadingPadding = State(initialValue: columnVisibility.wrappedValue == .detailOnly ? 70 : 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom tab bar at the top
            tabBar
            
            // Editor content
            editorContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.all, edges: .top)
        .background(Color(nsColor: .textBackgroundColor))
        .onChange(of: columnVisibility) { _, newValue in
            // Sync tab bar padding instantly (no animation) to match sidebar movement
            // This prevents bounce from conflicting animations
            tabBarLeadingPadding = newValue == .detailOnly ? 70 : 0
        }
        .onAppear {
            // Ensure padding matches current sidebar state (in case it changed before onAppear)
            // Do this without animation to avoid visual glitches on launch
            if tabBarLeadingPadding != (columnVisibility == .detailOnly ? 70 : 0) {
                tabBarLeadingPadding = columnVisibility == .detailOnly ? 70 : 0
            }
        }
        .sheet(item: $iconPickerTabID) { tabIDWrapper in
            if let tab = openTabs.first(where: { $0.id == tabIDWrapper.id }) {
                IconPickerView(
                    selectedIcon: Binding(
                        get: { tab.icon },
                        set: { newIcon in
                            updateTabIcon(tabID: tabIDWrapper.id, icon: newIcon)
                        }
                    ),
                    noteFileURL: tab.fileURL,
                    onCustomIconSelected: { _ in
                        // Icon file has been copied, updateTabIcon will handle the rest
                    }
                )
            }
        }
    }
    
    // MARK: - Tab Bar
    
    private var tabBar: some View {
        HStack(spacing: 0) {
            // Sidebar toggle button
            sidebarToggleButton
                .layoutPriority(3)
                .padding(.leading, 4) // Fixed 8px padding from tab bar edge
                .padding(.trailing, 8) // Proper spacing
            
            // Tabs - scrollable if needed (takes priority for space)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 1) {
                    ForEach(openTabs) { tab in
                        tabItem(tab)
                    }
                }
            }
            .layoutPriority(1)
            
            // Empty space = window drag area (fills remaining space)
            WindowDragView()
                .frame(minWidth: 0, maxWidth: .infinity)
            
            // New tab button
            Button(action: onNewTab) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .layoutPriority(2)
            .buttonStyle(.plain)
            .quickTooltip("Create new tab")
        }
        .frame(maxWidth: .infinity, minHeight: 36, maxHeight: 36)
        .padding(.leading, 8 + tabBarLeadingPadding) // 8px base + dynamic padding for traffic lights
        .padding(.trailing, 8)
        .background(Color(nsColor: .windowBackgroundColor))
        .animation(nil, value: tabBarLeadingPadding) // No animation on padding to prevent bounce
    }
    
    private var sidebarToggleButton: some View {
        Button(action: {
            // Use completely linear animation to eliminate all bounce
            var transaction = Transaction(animation: .linear(duration: 0.35))
            transaction.disablesAnimations = false
            withTransaction(transaction) {
                if columnVisibility == .all {
                    columnVisibility = .detailOnly
                } else {
                    columnVisibility = .all
                }
                // tabBarLeadingPadding will be updated by onChange handler
            }
        }) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .quickTooltip("Toggle sidebar")
    }
    
    private func tabItem(_ tab: TabItem) -> some View {
        let isSelected = selectedTabID == tab.id
        let isHovered = hoveredTabID == tab.id
        let isEditing = editingTabID == tab.id
        
        return HStack(spacing: 4) {
            // Icon display/editor
            if isSelected && !tab.isEmpty && !isEditing {
                // Show icon picker button when selected
                Button(action: {
                    iconPickerTabID = TabID(id: tab.id)
                }) {
                    if let icon = tab.icon, !icon.isEmpty {
                        // Check if it's a custom icon (has file extension) or emoji
                        if icon.contains(".") {
                            // Custom icon - load from icons folder
                            IconImageView(iconName: icon, noteFileURL: tab.fileURL, size: 20)
                        } else {
                            // Emoji
                            Text(icon)
                                .font(.system(size: 16))
                        }
                    } else {
                        Image(systemName: "tag")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
                .quickTooltip("Change icon")
            } else if let icon = tab.icon, !icon.isEmpty {
                // Show icon when not selected
                if icon.contains(".") {
                    IconImageView(iconName: icon, noteFileURL: tab.fileURL, size: 18)
                } else {
                    Text(icon)
                        .font(.system(size: 14))
                }
            }
            
            if isEditing {
                TextField("Tab name", text: $editingTabTitle)
                    .font(.system(size: 12))
                    .textFieldStyle(.plain)
                    .frame(minWidth: 60)
                    .focused($isTabTitleFocused)
                    .onSubmit {
                        finishEditingTab(tab)
                    }
                    .onChange(of: isTabTitleFocused) { _, focused in
                        if !focused {
                            finishEditingTab(tab)
                        }
                    }
            } else {
                Text(tab.title)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .onTapGesture {
                        // Single click on title starts editing (if tab is already selected and has a note)
                        if isSelected && !tab.isEmpty {
                            startEditingTab(tab)
                        } else {
                            onSelectTab(tab)
                        }
                    }
            }
            
            if (isHovered || isSelected) && !isEditing {
                Button(action: { onCloseTab(tab) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 16, height: 16)
                        .background(
                            Circle()
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                        )
                }
                .buttonStyle(.plain)
                .quickTooltip("Close tab")
            } else if !isEditing {
                Color.clear.frame(width: 16, height: 16)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color(nsColor: .controlBackgroundColor) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color(nsColor: .separatorColor).opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if !isEditing {
                onSelectTab(tab)
            }
        }
        .onHover { isHovered in
            hoveredTabID = isHovered ? tab.id : nil
        }
        .opacity(draggedTabID == tab.id ? 0.5 : 1.0)
        .onDrag {
            draggedTabID = tab.id
            return NSItemProvider(object: tab.id.uuidString as NSString)
        }
        .onDrop(of: [.text], delegate: TabDropDelegate(
            tab: tab,
            draggedTabID: $draggedTabID,
            tabs: $openTabs
        ))
        .contextMenu {
            if let index = openTabs.firstIndex(where: { $0.id == tab.id }) {
                if index > 0 {
                    Button("Move Left") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            openTabs.move(fromOffsets: IndexSet(integer: index), toOffset: index - 1)
                        }
                    }
                }
                if index < openTabs.count - 1 {
                    Button("Move Right") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            openTabs.move(fromOffsets: IndexSet(integer: index), toOffset: index + 2)
                        }
                    }
                }
                Divider()
                if !tab.isEmpty {
                    Button("Change Icon...") {
                        iconPickerTabID = TabID(id: tab.id)
                    }
                    Divider()
                }
                Button("Close Tab") {
                    onCloseTab(tab)
                }
                if openTabs.count > 1 {
                    Button("Close Other Tabs") {
                        let tabsToClose = openTabs.filter { $0.id != tab.id }
                        for t in tabsToClose {
                            onCloseTab(t)
                        }
                    }
                }
            }
        }
    }
    
    private func startEditingTab(_ tab: TabItem) {
        editingTabTitle = tab.title
        editingTabID = tab.id
        // Focus the text field after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isTabTitleFocused = true
        }
    }
    
    private func finishEditingTab(_ tab: TabItem) {
        guard editingTabID == tab.id else { return }
        
        let newTitle = editingTabTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !newTitle.isEmpty && newTitle != tab.title {
            // Update the tab title and rename the note if it exists
            if let index = openTabs.firstIndex(where: { $0.id == tab.id }) {
                openTabs[index] = TabItem(
                    id: tab.id,
                    noteID: tab.noteID,
                    title: newTitle,
                    fileURL: tab.fileURL,
                    isFileMissing: tab.isFileMissing,
                    icon: tab.icon
                )
                
                // If this tab has a note, rename it
                if let fileURL = tab.fileURL {
                    Task {
                        if let note = findNoteByURL(fileURL) {
                            await viewModel.renameNote(note, to: newTitle)
                        }
                    }
                }
            }
        }
        
        editingTabID = nil
        editingTabTitle = ""
    }
    
    private func findNoteByURL(_ fileURL: URL) -> Note? {
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
        // Search in allNoteItems (complete hierarchy) instead of noteItems (filtered for sidebar)
        return searchItems(viewModel.allNoteItems)
    }
    
    private func updateTabIcon(tabID: UUID?, icon: String?) {
        guard let tabID = tabID,
              let index = openTabs.firstIndex(where: { $0.id == tabID }) else {
            return
        }
        
        // Update tab icon
        var updatedTab = openTabs[index]
        updatedTab.icon = icon
        openTabs[index] = updatedTab
        
        // Update note icon if tab has a note
        if let fileURL = updatedTab.fileURL,
           var note = findNoteByURL(fileURL) {
            note.icon = icon
            viewModel.currentNote = note
            
            // Save the note with updated icon
            Task {
                await viewModel.saveCurrentNote()
            }
        }
        
        iconPickerTabID = nil
    }
    
    // MARK: - Editor Content
    
    private var editorContent: some View {
        Group {
            if let note = viewModel.currentNote {
                RichTextEditor(
                    text: $editedContent,
                    noteID: note.id,
                    onTextChange: { _ in scheduleAutoSave() }
                )
                .id(note.id)
                .focused($isEditorFocused)
                .onAppear {
                    editedContent = note.content
                    lastSavedContent = note.content
                    isSaved = true
                    isEditorFocused = true
                    onSaveActionReady? { [self] in
                        Task { await saveNote() }
                    }
                }
                .onChange(of: viewModel.currentNote) { oldNote, newNote in
                    if let newNote = newNote {
                        autoSaveTask?.cancel()
                        editedContent = newNote.content
                        lastSavedContent = newNote.content
                        isSaved = true
                    } else if oldNote != nil {
                        editedContent = ""
                        lastSavedContent = ""
                        isSaved = true
                    }
                }
                .onChange(of: editedContent) { _, _ in
                    isSaved = editedContent == lastSavedContent
                }
            } else {
                // Check if current tab is a missing file
                if let selectedID = selectedTabID,
                   let selectedTab = openTabs.first(where: { $0.id == selectedID }),
                   selectedTab.isFileMissing {
                    missingFileState(filename: selectedTab.title)
                } else {
                    emptyState
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "note.text")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)
            
            Text("No note selected")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            Text("Select a note from the sidebar or create a new one")
                .font(.body)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func missingFileState(filename: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
            
            Text(filename)
                .font(.title2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func scheduleAutoSave() {
        autoSaveTask?.cancel()
        autoSaveTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await saveNote(isAutoSave: true)
        }
    }
    
    private func saveNote(isAutoSave: Bool = false) async {
        guard var note = viewModel.currentNote else { return }
        guard editedContent != lastSavedContent else { return }
        
        note.content = editedContent
        viewModel.currentNote = note
        await viewModel.saveCurrentNote()
        
        lastSavedContent = editedContent
        isSaved = true
    }
}

// MARK: - Tab Drop Delegate

struct TabDropDelegate: DropDelegate {
    let tab: TabItem
    @Binding var draggedTabID: UUID?
    @Binding var tabs: [TabItem]
    
    func dropEntered(info: DropInfo) {
        guard let draggedID = draggedTabID,
              draggedID != tab.id,
              let fromIndex = tabs.firstIndex(where: { $0.id == draggedID }),
              let toIndex = tabs.firstIndex(where: { $0.id == tab.id }),
              fromIndex != toIndex else {
            return
        }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            tabs.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        draggedTabID = nil
        return true
    }
    
    func dropExited(info: DropInfo) {
        // Don't clear draggedTabID here - it's still being dragged
    }
}

#Preview {
    EditorView(
        viewModel: NotesViewModel(),
        editedContent: .constant("Preview content"),
        isSaved: .constant(true),
        openTabs: .constant([]),
        selectedTabID: .constant(nil),
        columnVisibility: .constant(.all),
        onSaveActionReady: nil,
        onSelectTab: { _ in },
        onCloseTab: { _ in },
        onNewTab: { }
    )
    .frame(width: 600, height: 400)
}
