import SwiftUI

struct EditorView: View {
    var viewModel: NotesViewModel
    @State private var editedContent: String = ""
    @FocusState private var isEditorFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if let note = viewModel.currentNote {
                // Title bar
                HStack {
                    TextField("Note Title", text: Binding(
                        get: { note.title },
                        set: { newTitle in
                            viewModel.renameNote(note, to: newTitle)
                        }
                    ))
                    .font(.title)
                    .textFieldStyle(.plain)
                    .padding()

                    Spacer()

                    // Save indicator
                    if editedContent != note.content {
                        Text("Unsaved")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.trailing)
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor))

                Divider()

                // Editor
                TextEditor(text: $editedContent)
                    .font(.body)
                    .focused($isEditorFocused)
                    .padding()
                    .onChange(of: editedContent) { oldValue, newValue in
                        // Auto-save with debounce would go here
                        if var updatedNote = viewModel.currentNote {
                            updatedNote.content = newValue
                            viewModel.currentNote = updatedNote
                        }
                    }
                    .onAppear {
                        editedContent = note.content
                        isEditorFocused = true
                    }
                    .onChange(of: note.id) { _, _ in
                        editedContent = note.content
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
        .toolbar {
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

    private func saveNote() {
        if var note = viewModel.currentNote {
            note.content = editedContent
            viewModel.currentNote = note
            viewModel.saveCurrentNote()
        }
    }
}

#Preview {
    EditorView(viewModel: NotesViewModel())
        .frame(width: 600, height: 400)
}
