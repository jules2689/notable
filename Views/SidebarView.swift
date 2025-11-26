import SwiftUI
import AppKit

struct SidebarView: View {
    var viewModel: NotesViewModel
    @Binding var searchText: String
    @Binding var editedContent: String
    @Binding var isSaved: Bool
    var onSave: () -> Void
    @State private var draggedItem: NoteItem?
    @AppStorage("showWordCount") private var showWordCount: Bool = true
    @AppStorage("showReadTime") private var showReadTime: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            WindowDragView()
                .frame(maxWidth: .infinity, minHeight: 36, maxHeight: 36)

            // Header with search and add button
            HStack(spacing: 8) {
                SearchBar(text: $searchText, onSearch: { query in
                    Task {
                        await viewModel.searchNotes(query: query)
                    }
                })
                
                Menu {
                    Button {
                        Task {
                            await viewModel.createNote(title: "Untitled")
                        }
                    } label: {
                        Label("New Note", systemImage: "doc.badge.plus")
                    }

                    Button {
                        Task {
                            await viewModel.createFolder(name: "New Folder")
                        }
                    } label: {
                        Label("New Folder", systemImage: "folder.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                        .cornerRadius(6)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
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
            
            // Sticky footer with save status, word count, and read time
            if viewModel.currentNote != nil {
                SidebarFooter(
                    content: editedContent,
                    isSaved: isSaved,
                    showWordCount: showWordCount,
                    showReadTime: showReadTime,
                    onSave: onSave
                )
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .padding(.top, -36)
    }
}

// MARK: - Sidebar Footer

struct SidebarFooter: View {
    let content: String
    let isSaved: Bool
    let showWordCount: Bool
    let showReadTime: Bool
    let onSave: () -> Void
    
    private var wordCount: Int {
        let words = content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return words.count
    }
    
    private var estimatedReadTime: String {
        // Average reading speed is about 200-250 words per minute
        let wordsPerMinute = 200
        let minutes = max(1, wordCount / wordsPerMinute)
        if minutes == 1 {
            return "1 min read"
        } else {
            return "\(minutes) min read"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            ViewThatFits {
                // Try horizontal layout first (save status on left, word count/read time on right)
                HStack(spacing: 12) {
                    // Save status button
                    Button {
                        onSave()
                    } label: {
                        HStack(spacing: 4) {
                            if isSaved {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.green)
                                Text("Saved")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            } else {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .foregroundStyle(.orange)
                                Text("Unsaved")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaved)
                    
                    Spacer()
                    
                    // Word count and read time
                    HStack(spacing: 8) {
                        if showWordCount {
                            let pluralWords = wordCount != 1 ? "words" : "word"
                            HStack(spacing: 2) {
                                Image(systemName: "text.word.spacing")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                                Text("\(wordCount) \(pluralWords)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if showReadTime {
                            HStack(spacing: 2) {
                                Image(systemName: "clock")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                                Text(estimatedReadTime)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                // Fall back to vertical layout if horizontal doesn't fit
                VStack(alignment: .leading, spacing: 4) {
                    // Save status button
                    Button {
                        onSave()
                    } label: {
                        HStack(spacing: 4) {
                            if isSaved {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.green)
                                Text("Saved")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            } else {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .foregroundStyle(.orange)
                                Text("Unsaved")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaved)
                    
                    // Word count and read time
                    if showWordCount {
                        let pluralWords = wordCount != 1 ? "words" : "word"
                        HStack(spacing: 2) {
                            Image(systemName: "text.word.spacing")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                            Text("\(wordCount) \(pluralWords)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if showReadTime {
                        HStack(spacing: 2) {
                            Image(systemName: "clock")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                            Text(estimatedReadTime)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .textBackgroundColor))
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
                        Task {
                            await viewModel.renameNote(note, to: newName)
                        }
                    } else if item.isFolder, case .folder(let folder) = item {
                        Task {
                            await viewModel.renameFolder(folder, to: newName)
                        }
                    }
                }
            }
            .alert("Delete \(item.isFolder ? "Folder" : "Note")?", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if item.isNote, case .note(let note) = item {
                        Task {
                            await viewModel.deleteNote(note)
                        }
                    } else if item.isFolder, case .folder(let folder) = item {
                        Task {
                            await viewModel.deleteFolder(folder)
                        }
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
                let isShiftHeld = NSEvent.modifierFlags.contains(.shift)
                print("📝 SidebarView: Selecting note \(note.title), shift=\(isShiftHeld)")
                viewModel.selectNote(note)
                
                // Shift-click opens in new tab, regular click updates current tab
                if isShiftHeld {
                    NotificationCenter.default.post(name: .noteOpenInNewTab, object: note)
                } else {
                    NotificationCenter.default.post(name: .noteSelectedFromSidebar, object: note)
                }
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
                    Task {
                        await viewModel.moveItem(dropped, to: targetFolder)
                    }
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
        searchText: .constant(""),
        editedContent: .constant("Sample content for preview"),
        isSaved: .constant(true),
        onSave: {}
    )
    .frame(width: 250)
}
