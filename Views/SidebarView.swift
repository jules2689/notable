import SwiftUI

struct SidebarView: View {
    var viewModel: NotesViewModel
    @Binding var searchText: String

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            SearchBar(text: $searchText, onSearch: { query in
                viewModel.searchNotes(query: query)
            })
            .padding(.horizontal, 8)
            .padding(.vertical, 8)

            // Notes list
            if viewModel.isLoading {
                Spacer()
                ProgressView("Loading notes...")
                Spacer()
            } else if viewModel.noteItems.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No notes yet")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Create your first note to get started")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            } else {
                List(selection: Binding(
                    get: { viewModel.selectedNoteItem },
                    set: { newValue in
                        if let item = newValue {
                            switch item {
                            case .note(let note):
                                viewModel.selectNote(note)
                            case .folder(let folder):
                                viewModel.selectFolder(folder)
                            }
                        }
                    }
                )) {
                    ForEach(viewModel.noteItems) { item in
                        NoteItemRow(item: item, viewModel: viewModel)
                            .tag(item)
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .navigationTitle("Notes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        viewModel.createNote(title: "Untitled")
                    } label: {
                        Label("New Note", systemImage: "doc.badge.plus")
                    }

                    Button {
                        viewModel.createFolder(name: "New Folder")
                    } label: {
                        Label("New Folder", systemImage: "folder.badge.plus")
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
    }
}

// MARK: - Search Bar

struct SearchBar: View {
    @Binding var text: String
    var onSearch: (String) -> Void

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search notes...", text: $text)
                .textFieldStyle(.plain)
                .onChange(of: text) { _, newValue in
                    onSearch(newValue)
                }

            if !text.isEmpty {
                Button {
                    text = ""
                    onSearch("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Note Item Row

struct NoteItemRow: View {
    let item: NoteItem
    var viewModel: NotesViewModel
    @State private var showingRenameAlert = false
    @State private var showingDeleteAlert = false
    @State private var newName = ""
    @State private var isTargeted = false

    var body: some View {
        HStack {
            Image(systemName: item.isFolder ? "folder.fill" : "doc.text.fill")
                .foregroundStyle(item.isFolder ? .blue : .secondary)
                .font(.system(size: 14))

            Text(item.name)
                .lineLimit(1)

            Spacer()

            // Show item count for folders
            if item.isFolder, case .folder(let folder) = item {
                Text("\(folder.children.count)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .background(isTargeted ? Color.accentColor.opacity(0.2) : Color.clear)
        .contextMenu {
            if item.isNote {
                Button {
                    newName = item.name
                    showingRenameAlert = true
                } label: {
                    Label("Rename", systemImage: "pencil")
                }

                Divider()

                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } else if item.isFolder {
                Button {
                    newName = item.name
                    showingRenameAlert = true
                } label: {
                    Label("Rename", systemImage: "pencil")
                }

                Divider()

                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .draggable(item) {
            // Drag preview
            HStack {
                Image(systemName: item.isFolder ? "folder.fill" : "doc.text.fill")
                    .foregroundStyle(item.isFolder ? .blue : .secondary)
                Text(item.name)
            }
            .padding(8)
            .background(.background)
            .cornerRadius(8)
        }
        .dropDestination(for: NoteItem.self) { droppedItems, location in
            // Only allow dropping on folders
            guard item.isFolder, case .folder(let folder) = item else {
                return false
            }

            // Move each dropped item to this folder
            for droppedItem in droppedItems {
                // Don't allow dropping a folder into itself
                if droppedItem.id != item.id {
                    viewModel.moveItem(droppedItem, to: folder)
                }
            }

            return true
        } isTargeted: { isTargeted in
            self.isTargeted = isTargeted
        }
        .alert("Rename \(item.isFolder ? "Folder" : "Note")", isPresented: $showingRenameAlert) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) { }
            Button("Rename") {
                if item.isNote, case .note(let note) = item {
                    viewModel.renameNote(note, to: newName)
                } else if item.isFolder, case .folder(let folder) = item {
                    viewModel.renameFolder(folder, to: newName)
                }
            }
        }
        .alert("Delete \(item.isFolder ? "Folder" : "Note")?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if item.isNote, case .note(let note) = item {
                    viewModel.deleteNote(note)
                } else if item.isFolder, case .folder(let folder) = item {
                    viewModel.deleteFolder(folder)
                }
            }
        } message: {
            if item.isFolder {
                Text("This will permanently delete the folder and all its contents.")
            } else {
                Text("This will permanently delete this note.")
            }
        }
    }
}

#Preview {
    SidebarView(
        viewModel: NotesViewModel(),
        searchText: .constant("")
    )
    .frame(width: 250)
}
