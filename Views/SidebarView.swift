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

            Divider()

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

    var body: some View {
        HStack {
            Image(systemName: item.isFolder ? "folder.fill" : "doc.text.fill")
                .foregroundStyle(item.isFolder ? .blue : .secondary)
                .font(.system(size: 14))

            Text(item.name)
                .lineLimit(1)

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

#Preview {
    SidebarView(
        viewModel: NotesViewModel(),
        searchText: .constant("")
    )
    .frame(width: 250)
}
