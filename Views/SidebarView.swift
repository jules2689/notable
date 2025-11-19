import SwiftUI
import AppKit

struct SidebarView: View {
    var viewModel: NotesViewModel
    @Binding var searchText: String
    @State private var draggedItem: NoteItem?

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
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.noteItems) { item in
                            HierarchicalNoteItemRow(
                                item: item,
                                viewModel: viewModel,
                                level: 0,
                                draggedItem: $draggedItem
                            )
                        }
                    }
                }
             }
         }
         .background(Color(nsColor: .textBackgroundColor))
         .navigationTitle("")
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
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
        )
        .cornerRadius(8)
    }
}

// MARK: - Hierarchical Note Item Row

struct HierarchicalNoteItemRow: View {
    let item: NoteItem
    var viewModel: NotesViewModel
    let level: Int
    @Binding var draggedItem: NoteItem?
    @State private var showingRenameAlert = false
    @State private var showingDeleteAlert = false
    @State private var newName = ""
    @State private var isTargeted = false
    
    private var isExpanded: Bool {
        if case .folder(let folder) = item {
            return viewModel.isFolderExpanded(folder)
        }
        return false
    }
    
    private var folder: Folder? {
        if case .folder(let folder) = item {
            return folder
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            HStack(spacing: 4) {
                // Indentation for nested items
                if level > 0 {
                    ForEach(0..<level, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 16)
                    }
                }
                
                // Expand/collapse button for folders
                if item.isFolder, let folder = folder {
                    Button {
                        viewModel.toggleFolderExpansion(folder)
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)
                } else {
                    // Spacer for non-folder items to align with folders
                    Spacer()
                        .frame(width: 16)
                }
                
                Image(systemName: item.isFolder ? "folder.fill" : "doc.text.fill")
                    .foregroundStyle(item.isFolder ? .blue : .secondary)
                    .font(.system(size: 14))

                Text(item.name)
                    .lineLimit(1)

                Spacer()

                // Show item count for folders
                if item.isFolder, let folder = folder {
                    Text("\(folder.children.count)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
            .background(
                Group {
                    if viewModel.selectedNoteItem?.id == item.id {
                        Color.accentColor.opacity(0.2)
                    } else if isTargeted && item.isFolder {
                        Color.accentColor.opacity(0.15)
                    } else {
                        Color.clear
                    }
                }
            )
            .onDrag {
                draggedItem = item
                // Create NSItemProvider for drag with the item's ID as a simple string
                let provider = NSItemProvider(object: item.id.uuidString as NSString)
                provider.suggestedName = item.name
                return provider
            }
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
            
            // Recursively show children if folder is expanded
            if item.isFolder, let folder = folder, isExpanded {
                ForEach(folder.children) { childItem in
                    HierarchicalNoteItemRow(
                        item: childItem,
                        viewModel: viewModel,
                        level: level + 1,
                        draggedItem: $draggedItem
                    )
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            switch item {
            case .note(let note):
                viewModel.selectNote(note)
            case .folder(let folder):
                // Toggle expansion when clicking on folder
                viewModel.toggleFolderExpansion(folder)
            }
        }
        .onDrop(of: [.text], isTargeted: $isTargeted) { providers in
            guard item.isFolder else {
                return false
            }
            
            guard case .folder(let targetFolder) = item else {
                return false
            }
            
            // Use the dragged item from state (most reliable)
            if let dropped = draggedItem {
                if !isDescendant(dropped, of: item) {
                    viewModel.moveItem(dropped, to: targetFolder)
                    draggedItem = nil
                    return true
                }
            }
            
            return false
        }
    }
    
    /// Checks if an item is a descendant of another item (to prevent circular moves)
    private func isDescendant(_ item: NoteItem, of ancestor: NoteItem) -> Bool {
        if item.id == ancestor.id {
            return true
        }
        
        guard case .folder(let ancestorFolder) = ancestor else {
            return false
        }
        
        for child in ancestorFolder.children {
            if isDescendant(item, of: child) {
                return true
            }
        }
        
        return false
    }
}

#Preview {
    SidebarView(
        viewModel: NotesViewModel(),
        searchText: .constant("")
    )
    .frame(width: 250)
}
