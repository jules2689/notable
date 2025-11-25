import SwiftUI
import Combine

struct EditorView: View {
    var viewModel: NotesViewModel
    @Binding var editedContent: String
    @Binding var isSaved: Bool
    var onSaveActionReady: ((@escaping () -> Void) -> Void)?
    @State private var autoSaveTask: Task<Void, Never>?
    @State private var lastSavedContent: String = ""
    @State private var renameTask: Task<Void, Never>?
    @State private var pendingTitle: String = ""
    @FocusState private var isEditorFocused: Bool
    @State private var contentOpacity: Double = 1.0

    var body: some View {
        VStack(spacing: 0) {
            if let note = viewModel.currentNote {
                // Rich text editor with full rendering
                RichTextEditor(
                    text: $editedContent,
                    noteID: note.id,
                    onTextChange: { newText in
                        scheduleAutoSave()
                    }
                )
                .id(note.id) // Force recreate editor when note changes
                .opacity(contentOpacity)
                .focused($isEditorFocused)
                .onAppear {
                    editedContent = note.content
                    lastSavedContent = note.content
                    isSaved = true
                    isEditorFocused = true
                    // Ensure content is visible on first load (no animation needed)
                    contentOpacity = 1.0
                    // Provide save action to parent
                    onSaveActionReady? { [self] in
                        Task {
                            await saveNote()
                        }
                    }
                }
                .onChange(of: viewModel.currentNote) { oldNote, newNote in
                    // Watch for when the note object itself changes (e.g., after reload)
                    if let newNote = newNote {
                        // Always update when note changes
                        autoSaveTask?.cancel()
                        
                        // Update content immediately to avoid race conditions with the editor
                        editedContent = newNote.content
                        lastSavedContent = newNote.content
                        isSaved = true
                        
                        // Manage opacity for smooth transition only if it's a different note file
                        let isDifferentNote = oldNote?.fileURL != newNote.fileURL
                        
                        if isDifferentNote {
                            // For different notes, we can do a quick fade
                            contentOpacity = 0
                            withAnimation(.easeOut(duration: 0.2)) {
                                contentOpacity = 1.0
                            }
                        } else {
                            // For same note (reload), just ensure visible
                            contentOpacity = 1.0
                        }
                    } else if oldNote != nil {
                        // Note was deselected
                        editedContent = ""
                        lastSavedContent = ""
                        isSaved = true
                        contentOpacity = 0
                    }
                }
                .onChange(of: editedContent) { _, _ in
                    // Update save status when content changes
                    isSaved = editedContent == lastSavedContent
                }
            } else {
                // Empty state
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.all, edges: .top)
    }

    // MARK: - Actions

    private func scheduleAutoSave() {
        // Cancel any existing auto-save task
        autoSaveTask?.cancel()

        // Schedule a new auto-save after 2 seconds of inactivity
        autoSaveTask = Task {
            try? await Task.sleep(for: .seconds(2))

            // Check if task was cancelled
            guard !Task.isCancelled else { return }

            // Perform auto-save
            await saveNote(isAutoSave: true)
        }
    }

    private func saveNote(isAutoSave: Bool = false) async {
        guard var note = viewModel.currentNote else { return }

        // Don't save if content hasn't changed
        guard editedContent != lastSavedContent else { return }

        note.content = editedContent
        viewModel.currentNote = note
        await viewModel.saveCurrentNote()

        // Update last saved content and status
        lastSavedContent = editedContent
        isSaved = true
    }
}

#Preview {
    EditorView(
        viewModel: NotesViewModel(),
        editedContent: .constant("Preview content"),
        isSaved: .constant(true),
        onSaveActionReady: nil
    )
    .frame(width: 600, height: 400)
}
