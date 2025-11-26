import SwiftUI
import Combine
import AppKit

// NSView that enables window dragging when clicked
class WindowDragNSView: NSView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
    
    override var mouseDownCanMoveWindow: Bool { true }
}

// SwiftUI wrapper for window drag area
struct WindowDragView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = WindowDragNSView()
        view.wantsLayer = true
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct EditorView: View {
    var viewModel: NotesViewModel
    @Binding var editedContent: String
    @Binding var isSaved: Bool
    @Binding var openTabs: [TabItem]
    @Binding var selectedTabID: UUID?
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
    @State private var draggedTab: TabItem?

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
        ZStack {
            // Window drag area (invisible, covers entire tab bar for dragging)
            WindowDragView()
            
            HStack(spacing: 0) {
                // Tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 1) {
                        ForEach(openTabs) { tab in
                            tabItem(tab)
                        }
                    }
                    .padding(.leading, 8)
                }
                
                Spacer()
                
                // New tab button
                Button(action: onNewTab) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            }
        }
        .frame(height: 36)
        .background(Color(nsColor: .windowBackgroundColor))
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
                        // Single click on title starts editing (if tab is already selected)
                        if isSelected {
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
        .opacity(draggedTab?.id == tab.id ? 0.5 : 1.0)
        .draggable(tab.id.uuidString) {
            // Drag preview
            HStack(spacing: 4) {
                Text(tab.title)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
            .onAppear {
                draggedTab = tab
            }
        }
        .dropDestination(for: String.self) { items, location in
            guard let draggedTab = draggedTab,
                  draggedTab.id != tab.id,
                  let fromIndex = openTabs.firstIndex(where: { $0.id == draggedTab.id }),
                  let toIndex = openTabs.firstIndex(where: { $0.id == tab.id }) else {
                return false
            }
            withAnimation(.easeInOut(duration: 0.2)) {
                openTabs.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
            }
            self.draggedTab = nil
            return true
        }
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

#Preview {
    EditorView(
        viewModel: NotesViewModel(),
        editedContent: .constant("Preview content"),
        isSaved: .constant(true),
        openTabs: .constant([]),
        selectedTabID: .constant(nil),
        onSaveActionReady: nil,
        onSelectTab: { _ in },
        onCloseTab: { _ in },
        onNewTab: { }
    )
    .frame(width: 600, height: 400)
}
