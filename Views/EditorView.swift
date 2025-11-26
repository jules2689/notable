import SwiftUI
import Combine

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
        .frame(height: 36)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private func tabItem(_ tab: TabItem) -> some View {
        let isSelected = selectedTabID == tab.id
        let isHovered = hoveredTabID == tab.id
        
        return HStack(spacing: 6) {
            Text(tab.title)
                .font(.system(size: 12))
                .lineLimit(1)
                .foregroundStyle(isSelected ? .primary : .secondary)
            
            if isHovered || isSelected {
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
            } else {
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
        .onTapGesture { onSelectTab(tab) }
        .onHover { isHovered in
            hoveredTabID = isHovered ? tab.id : nil
        }
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
