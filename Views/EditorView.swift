import SwiftUI
import Combine

struct EditorView: View {
    var viewModel: NotesViewModel
    @State private var editedContent: String = ""
    @State private var autoSaveTask: Task<Void, Never>?
    @State private var lastSavedContent: String = ""
    @FocusState private var isEditorFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if let note = viewModel.currentNote {
                // Rich text editor with full rendering
                RichTextEditor(
                    text: $editedContent,
                    onTextChange: { newText in
                        scheduleAutoSave()
                    }
                )
                .focused($isEditorFocused)
                .onAppear {
                    editedContent = note.content
                    lastSavedContent = note.content
                    isEditorFocused = true
                }
                .onChange(of: note.id) { _, _ in
                    // Cancel any pending auto-save when switching notes
                    autoSaveTask?.cancel()
                    editedContent = note.content
                    lastSavedContent = note.content
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
        .navigationTitle("") // Gets rid of the default navigation title
        .toolbar {
            // Editable title on the left side of the title bar
            ToolbarItem(placement: .navigation) {
                if viewModel.currentNote != nil {
                    TextField("Note Title", text: Binding(
                        get: { viewModel.currentNote?.title ?? "" },
                        set: { newTitle in
                            if let note = viewModel.currentNote {
                                viewModel.renameNote(note, to: newTitle)
                            }
                        }
                    ))
                    .textFieldStyle(.plain)
                    .font(.headline)
                    .frame(maxWidth: 300)
                }
            }

            // Save status indicator on the right
            ToolbarItem(placement: .automatic) {
                if viewModel.currentNote != nil {
                    if editedContent != lastSavedContent {
                        HStack(spacing: 4) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundStyle(.orange)
                            Text("Unsaved")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if editedContent == lastSavedContent && !editedContent.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.green)
                            Text("Saved")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Save button on the right
            ToolbarItem(placement: .primaryAction) {
                if viewModel.currentNote != nil {
                    Button {
                        saveNote()
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .keyboardShortcut("s", modifiers: .command)
                }
            }
        }
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

            // Perform auto-save on main actor
            await MainActor.run {
                saveNote(isAutoSave: true)
            }
        }
    }

    private func saveNote(isAutoSave: Bool = false) {
        guard var note = viewModel.currentNote else { return }

        // Don't save if content hasn't changed
        guard editedContent != lastSavedContent else { return }

        note.content = editedContent
        viewModel.currentNote = note
        viewModel.saveCurrentNote()

        // Update last saved content
        lastSavedContent = editedContent
    }
}

#Preview {
    EditorView(viewModel: NotesViewModel())
        .frame(width: 600, height: 400)
}
