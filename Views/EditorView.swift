import SwiftUI
import Combine

struct EditorView: View {
    var viewModel: NotesViewModel
    @State private var editedContent: String = ""
    @State private var autoSaveTask: Task<Void, Never>?
    @State private var lastSavedContent: String = ""
    @State private var renameTask: Task<Void, Never>?
    @State private var pendingTitle: String = ""
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
        .toolbarBackground(Color(nsColor: .textBackgroundColor), for: .windowToolbar)
        .toolbar {
            // Editable title on the left side of the title bar
            ToolbarItem(placement: .navigation) {
                if viewModel.currentNote != nil {
                    TextField("Note Title", text: Binding(
                        get: { 
                            if pendingTitle.isEmpty {
                                return viewModel.currentNote?.title ?? ""
                            }
                            return pendingTitle
                        },
                        set: { newTitle in
                            pendingTitle = newTitle
                            
                            // Debounce rename to avoid multiple calls while typing
                            renameTask?.cancel()
                            renameTask = Task {
                                // Wait 0.5 seconds after user stops typing
                                try? await Task.sleep(for: .milliseconds(500))
                                
                                // Check if task was cancelled
                                guard !Task.isCancelled else { return }
                                
                                // Get the current note at the time of execution (may have changed)
                                await MainActor.run {
                                    guard let note = viewModel.currentNote else { return }
                                    
                                    // Only rename if title actually changed and is not empty
                                    let trimmedTitle = newTitle.trimmingCharacters(in: .whitespaces)
                                    if !trimmedTitle.isEmpty && trimmedTitle != note.title {
                                        Task {
                                            await viewModel.renameNote(note, to: trimmedTitle)
                                        }
                                    }
                                    pendingTitle = "" // Clear pending after rename attempt
                                }
                            }
                        }
                    ))
                    .textFieldStyle(.plain)
                    .font(.title2)
                    .frame(maxWidth: 300)
                    .onSubmit {
                        // Rename immediately on submit (Enter key)
                        renameTask?.cancel()
                        if let note = viewModel.currentNote,
                           !pendingTitle.trimmingCharacters(in: .whitespaces).isEmpty,
                           pendingTitle != note.title {
                            Task {
                                await viewModel.renameNote(note, to: pendingTitle)
                            }
                            pendingTitle = "" // Clear pending after rename
                        }
                    }
                    .onChange(of: viewModel.currentNote?.id) { _, _ in
                        // Reset pending title when note changes
                        pendingTitle = ""
                    }
                }
            }

            // Save status indicator on the right (clickable to save)
            ToolbarItem(placement: .automatic) {
                if viewModel.currentNote != nil {
                    if editedContent != lastSavedContent {
                        Button {
                            Task {
                                await saveNote()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .foregroundStyle(.orange)
                                Text("Unsaved")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut("s", modifiers: .command)
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

        // Update last saved content
        lastSavedContent = editedContent
    }
}

#Preview {
    EditorView(viewModel: NotesViewModel())
        .frame(width: 600, height: 400)
}
