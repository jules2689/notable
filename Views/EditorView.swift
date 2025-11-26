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
    @State var tabBarLeading: CGFloat = 0

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
    }
    
    // MARK: - Tab Bar
    
    private var tabBar: some View {
        HStack(spacing: 0) {
            // Sidebar toggle button
            sidebarToggleButton
                .layoutPriority(3)
                .padding(.leading, tabBarLeading)
                .animation(.easeInOut(duration: 1.5), value: tabBarLeading)
            
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
        }
        .frame(maxWidth: .infinity, minHeight: 36, maxHeight: 36)
        .padding(.leading, 8)
        .padding(.trailing, 8)
        .animation(.easeInOut(duration: 1.5), value: tabBarLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private var sidebarToggleButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0)) {
                if columnVisibility == .all {
                    columnVisibility = .detailOnly
                    tabBarLeading = 86
                } else {
                    columnVisibility = .all
                    tabBarLeading = 8
                }
            }
        }) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func tabItem(_ tab: TabItem) -> some View {
        let isSelected = selectedTabID == tab.id
        let isHovered = hoveredTabID == tab.id
        let isEditing = editingTabID == tab.id
        
        return HStack(spacing: 4) {
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
                    fileURL: tab.fileURL
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
        return searchItems(viewModel.noteItems)
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
                emptyState
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
