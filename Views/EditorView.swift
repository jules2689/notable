import SwiftUI
import Combine

enum EditorMode: String, CaseIterable {
    case edit = "Edit"
    case preview = "Preview"
    case split = "Split"
}

struct EditorView: View {
    var viewModel: NotesViewModel
    @State private var editedContent: String = ""
    @State private var editorMode: EditorMode = .edit
    @State private var autoSaveTask: Task<Void, Never>?
    @State private var lastSavedContent: String = ""
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

                    // Mode picker
                    Picker("View Mode", selection: $editorMode) {
                        ForEach(EditorMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                    .padding(.trailing)

                    // Save indicator
                    if editedContent != lastSavedContent {
                        HStack(spacing: 4) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundStyle(.orange)
                            Text("Unsaved")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.trailing)
                    } else if editedContent == lastSavedContent && !editedContent.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.green)
                            Text("Saved")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.trailing)
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor))

                Divider()

                // Content area based on mode
                Group {
                    switch editorMode {
                    case .edit:
                        editView
                    case .preview:
                        previewView
                    case .split:
                        splitView
                    }
                }
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

    // MARK: - View Modes

    private var editView: some View {
        TextEditor(text: $editedContent)
            .font(.body)
            .focused($isEditorFocused)
            .padding()
            .onChange(of: editedContent) { oldValue, newValue in
                scheduleAutoSave()
            }
    }

    private var previewView: some View {
        ScrollView {
            MarkdownView(markdown: editedContent)
                .frame(maxWidth: .infinity, minHeight: 400)
        }
    }

    private var splitView: some View {
        HSplitView {
            TextEditor(text: $editedContent)
                .font(.body)
                .focused($isEditorFocused)
                .padding()
                .onChange(of: editedContent) { oldValue, newValue in
                    scheduleAutoSave()
                }
                .frame(minWidth: 300)

            MarkdownView(markdown: editedContent)
                .frame(minWidth: 300)
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
