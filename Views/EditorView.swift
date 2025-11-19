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

    // Slash command state
    @State private var showSlashCommands: Bool = false
    @State private var slashQuery: String = ""
    @State private var slashCommandPosition: NSPoint = .zero
    @State private var selectedCommandIndex: Int = 0
    @State private var commandToInsert: SlashCommand? = nil

    var body: some View {
        VStack(spacing: 0) {
            if let note = viewModel.currentNote {
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

            // View mode picker on the right
            ToolbarItem(placement: .automatic) {
                if viewModel.currentNote != nil {
                    Picker("View Mode", selection: $editorMode) {
                        ForEach(EditorMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
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

    // MARK: - View Modes

    private var editView: some View {
        SlashCommandTextEditor(
            text: $editedContent,
            onTextChange: { newText in
                scheduleAutoSave()
            },
            showSlashCommands: $showSlashCommands,
            slashQuery: $slashQuery,
            slashCommandPosition: $slashCommandPosition,
            commandToInsert: $commandToInsert
        )
        .focused($isEditorFocused)
        .overlay(alignment: .topLeading) {
            // Slash command popup
            if showSlashCommands {
                let filteredCommands = SlashCommand.filtered(by: slashQuery)
                SlashCommandView(
                    commands: filteredCommands,
                    onSelect: { command in
                        insertSlashCommand(command)
                    },
                    onDismiss: {
                        showSlashCommands = false
                        selectedCommandIndex = 0
                    },
                    selectedIndex: $selectedCommandIndex
                )
                .offset(x: slashCommandPosition.x, y: slashCommandPosition.y)
                .onChange(of: slashQuery) { _, _ in
                    selectedCommandIndex = 0
                }
            }
        }
        .onKeyPress(.downArrow) {
            guard showSlashCommands else { return .ignored }
            let commands = SlashCommand.filtered(by: slashQuery)
            selectedCommandIndex = min(selectedCommandIndex + 1, commands.count - 1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            guard showSlashCommands else { return .ignored }
            selectedCommandIndex = max(selectedCommandIndex - 1, 0)
            return .handled
        }
        .onKeyPress(.return) {
            guard showSlashCommands else { return .ignored }
            let commands = SlashCommand.filtered(by: slashQuery)
            if !commands.isEmpty && selectedCommandIndex < commands.count {
                insertSlashCommand(commands[selectedCommandIndex])
            }
            return .handled
        }
        .onKeyPress(.escape) {
            guard showSlashCommands else { return .ignored }
            showSlashCommands = false
            selectedCommandIndex = 0
            return .handled
        }
    }

    private var previewView: some View {
        MarkdownView(markdown: editedContent)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var splitView: some View {
        HSplitView {
            SlashCommandTextEditor(
                text: $editedContent,
                onTextChange: { newText in
                    scheduleAutoSave()
                },
                showSlashCommands: $showSlashCommands,
                slashQuery: $slashQuery,
                slashCommandPosition: $slashCommandPosition,
                commandToInsert: $commandToInsert
            )
            .focused($isEditorFocused)
            .overlay(alignment: .topLeading) {
                // Slash command popup
                if showSlashCommands {
                    let filteredCommands = SlashCommand.filtered(by: slashQuery)
                    SlashCommandView(
                        commands: filteredCommands,
                        onSelect: { command in
                            insertSlashCommand(command)
                        },
                        onDismiss: {
                            showSlashCommands = false
                            selectedCommandIndex = 0
                        },
                        selectedIndex: $selectedCommandIndex
                    )
                    .offset(x: slashCommandPosition.x, y: slashCommandPosition.y)
                    .onChange(of: slashQuery) { _, _ in
                        selectedCommandIndex = 0
                    }
                }
            }
            .onKeyPress(.downArrow) {
                guard showSlashCommands else { return .ignored }
                let commands = SlashCommand.filtered(by: slashQuery)
                selectedCommandIndex = min(selectedCommandIndex + 1, commands.count - 1)
                return .handled
            }
            .onKeyPress(.upArrow) {
                guard showSlashCommands else { return .ignored }
                selectedCommandIndex = max(selectedCommandIndex - 1, 0)
                return .handled
            }
            .onKeyPress(.return) {
                guard showSlashCommands else { return .ignored }
                let commands = SlashCommand.filtered(by: slashQuery)
                if !commands.isEmpty && selectedCommandIndex < commands.count {
                    insertSlashCommand(commands[selectedCommandIndex])
                }
                return .handled
            }
            .onKeyPress(.escape) {
                guard showSlashCommands else { return .ignored }
                showSlashCommands = false
                selectedCommandIndex = 0
                return .handled
            }
            .frame(minWidth: 300)

            MarkdownView(markdown: editedContent)
                .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
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

    private func insertSlashCommand(_ command: SlashCommand) {
        // Set the command to insert, which will trigger the coordinator to insert it
        commandToInsert = command
        showSlashCommands = false
        selectedCommandIndex = 0
    }
}

#Preview {
    EditorView(viewModel: NotesViewModel())
        .frame(width: 600, height: 400)
}
