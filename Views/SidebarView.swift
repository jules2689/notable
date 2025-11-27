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
            HStack(spacing: 2) {
                SearchBar(text: $searchText, onSearch: { query in
                    Task {
                        await viewModel.searchNotes(query: query)
                    }
                })
                
                Menu {
                    Button("New Note", systemImage: "doc.badge.plus") {
                        Task {
                            await viewModel.createNote(title: "Untitled")
                        }
                    }

                    Button("New Folder", systemImage: "folder.badge.plus") {
                        Task {
                            await viewModel.createFolder(name: "New Folder")
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .menuIndicator(.hidden)
                .buttonStyle(.plain)
                .quickTooltip("Create new note or folder")
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)

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
                    onSave: onSave,
                    viewModel: viewModel
                )
            }
            
            // Git push button (always shown if git repo, not just when note is open)
            GitPushButton(viewModel: viewModel)
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
    let viewModel: NotesViewModel
    
    private var wordCount: Int {
        let plaintext = markdownToPlaintext(content)
        let words = plaintext.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return words.count
    }
    
    /// Converts markdown to plaintext by stripping all markdown syntax
    private func markdownToPlaintext(_ markdown: String) -> String {
        var text = markdown
        
        // Helper function for multiline regex replacements
        func replaceMultiline(pattern: String, with replacement: String, in text: String) -> String {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
                return text
            }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: replacement)
        }
        
        // Remove code blocks (```code```)
        text = text.replacingOccurrences(
            of: #"```[\s\S]*?```"#,
            with: "",
            options: .regularExpression
        )
        
        // Remove inline code (`code`)
        text = text.replacingOccurrences(
            of: #"`([^`]+)`"#,
            with: "$1",
            options: .regularExpression
        )
        
        // Remove images ![alt](url)
        text = text.replacingOccurrences(
            of: #"!\[([^\]]*)\]\([^\)]+\)"#,
            with: "$1",
            options: .regularExpression
        )
        
        // Remove links [text](url) but keep the text
        text = text.replacingOccurrences(
            of: #"\[([^\]]+)\]\([^\)]+\)"#,
            with: "$1",
            options: .regularExpression
        )
        
        // Remove reference-style links [text][ref]
        text = text.replacingOccurrences(
            of: #"\[([^\]]+)\]\[[^\]]+\]"#,
            with: "$1",
            options: .regularExpression
        )
        
        // Remove headers (# ## ### etc.)
        text = replaceMultiline(pattern: #"^#{1,6}\s+(.+)$"#, with: "$1", in: text)
        
        // Remove bold/italic markers (**text**, *text*, __text__, _text_)
        text = text.replacingOccurrences(
            of: #"\*\*([^*]+)\*\*"#,
            with: "$1",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: #"__([^_]+)__"#,
            with: "$1",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: #"(?<!\*)\*([^*]+)\*(?!\*)"#,
            with: "$1",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: #"(?<!_)_([^_]+)_(?!_)"#,
            with: "$1",
            options: .regularExpression
        )
        
        // Remove strikethrough (~~text~~)
        text = text.replacingOccurrences(
            of: #"~~([^~]+)~~"#,
            with: "$1",
            options: .regularExpression
        )
        
        // Remove blockquote markers (>)
        text = replaceMultiline(pattern: #"^>\s+(.+)$"#, with: "$1", in: text)
        
        // Remove horizontal rules (---, ***, ___)
        text = replaceMultiline(pattern: #"^[-*_]{3,}\s*$"#, with: "", in: text)
        
        // Remove list markers (-, *, +) and task list markers (- [ ], - [x])
        text = replaceMultiline(pattern: #"^[\s]*[-*+]\s+(\[[\sx]\]\s*)?"#, with: "", in: text)
        
        // Remove numbered list markers (1. 2. etc.)
        text = replaceMultiline(pattern: #"^[\s]*\d+\.\s+"#, with: "", in: text)
        
        // Remove HTML tags if any
        text = text.replacingOccurrences(
            of: #"<[^>]+>"#,
            with: "",
            options: .regularExpression
        )
        
        // Clean up multiple spaces and normalize whitespace
        text = text.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var estimatedReadTime: String {
        // Average reading speed is about 200-250 words per minute
        let wordsPerMinute = 200
        let minutes = max(1, wordCount / wordsPerMinute)
        return "\(minutes) min read"
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
                    .quickTooltip(isSaved ? "Note is saved" : "Save the current note")
                    
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
                    .quickTooltip(isSaved ? "Note is saved" : "Save the current note")
                    
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
                .quickTooltip("Clear search")
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
    @State private var iconPickerItem: NoteItem?
    
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
            HStack(spacing: 6) { // Increased spacing to prevent overlap
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
                            .frame(width: 10, height: 10)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .frame(width: 20, height: 20) // Larger hit area for easier clicking
                    .allowsHitTesting(true)
                } else {
                    // Spacer for non-folder items to align with folders
                    Spacer()
                        .frame(width: 20) // Match the button width
                }
                
                // Show icon for notes and folders (both clickable)
                // Use a separate view with its own tap handling
                IconButtonView(item: item, iconPickerItem: $iconPickerItem)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
                    .allowsHitTesting(true)
                    .quickTooltip("Change icon")

                // Make text area tappable for both notes and folders
                Text(item.name)
                    .lineLimit(1)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Don't toggle if icon picker is open for this item
                        if iconPickerItem?.id == item.id {
                            return
                        }
                        
                        // Handle folder expansion when clicking folder name
                        if item.isFolder, let folder = folder {
                            viewModel.toggleFolderExpansion(folder)
                        }
                        // Handle note selection
                        else if case .note(let note) = item {
                            let isShiftHeld = NSEvent.modifierFlags.contains(.shift)
                            print("📝 SidebarView: Selecting note \(note.title), shift=\(isShiftHeld)")
                            viewModel.selectNote(note)
                            
                            // Shift-click opens in new tab, regular click updates current tab
                            if isShiftHeld {
                                NotificationCenter.default.post(name: .noteOpenInNewTab, object: note)
                            } else {
                                NotificationCenter.default.post(name: .noteSelectedFromSidebar, object: note)
                            }
                        }
                    }

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
                Button {
                    iconPickerItem = item
                } label: {
                    Label("Change Icon...", systemImage: "tag")
                }
                
                Divider()
                
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
        .sheet(item: $iconPickerItem) { item in
            if case .note(let note) = item {
                IconPickerView(
                    selectedIcon: Binding(
                        get: { note.icon },
                        set: { newIcon in
                            updateNoteIcon(note: note, icon: newIcon)
                        }
                    ),
                    noteFileURL: note.fileURL,
                    onCustomIconSelected: { _ in
                        // Icon file has been copied, updateNoteIcon will handle the rest
                    }
                )
            } else if case .folder(let folder) = item {
                IconPickerView(
                    selectedIcon: Binding(
                        get: { folder.icon },
                        set: { newIcon in
                            updateFolderIcon(folder: folder, icon: newIcon)
                        }
                    ),
                    noteFileURL: folder.fileURL,
                    onCustomIconSelected: { _ in
                        // Icon file has been copied, updateFolderIcon will handle the rest
                    }
                )
            }
        }
    }
    
    private func updateFolderIcon(folder: Folder, icon: String?) {
        Task {
            do {
                try await viewModel.fileSystemService.saveFolderIcon(folder, icon: icon)
                // Update folder icon in place without reloading
                updateFolderIconInHierarchy(folder: folder, icon: icon)
            } catch {
                print("Failed to update folder icon: \(error)")
            }
        }
        
        iconPickerItem = nil
    }
    
    private func updateNoteIcon(note: Note, icon: String?) {
        var updatedNote = note
        updatedNote.icon = icon
        viewModel.currentNote = updatedNote
        
        // Save the note with updated icon
        Task {
            await viewModel.saveCurrentNote()
            // Update note icon in place without reloading
            updateNoteIconInHierarchy(note: note, icon: icon)
        }
        
        iconPickerItem = nil
    }
    
    /// Updates folder icon in the hierarchy without reloading
    private func updateFolderIconInHierarchy(folder: Folder, icon: String?) {
        func updateInItems(_ items: inout [NoteItem]) {
            for i in items.indices {
                if case .folder(var f) = items[i], f.id == folder.id {
                    f.icon = icon
                    items[i] = .folder(f)
                    return
                } else if case .folder(var f) = items[i] {
                    var children = f.children
                    updateInItems(&children)
                    f.children = children
                    items[i] = .folder(f)
                }
            }
        }
        
        var allItems = viewModel.allNoteItems
        updateInItems(&allItems)
        viewModel.allNoteItems = allItems
        
        var displayItems = viewModel.noteItems
        updateInItems(&displayItems)
        viewModel.noteItems = displayItems
    }
    
    /// Updates note icon in the hierarchy without reloading
    private func updateNoteIconInHierarchy(note: Note, icon: String?) {
        func updateInItems(_ items: inout [NoteItem]) {
            for i in items.indices {
                if case .note(var n) = items[i], n.id == note.id {
                    n.icon = icon
                    items[i] = .note(n)
                    return
                } else if case .folder(var f) = items[i] {
                    var children = f.children
                    updateInItems(&children)
                    f.children = children
                    items[i] = .folder(f)
                }
            }
        }
        
        var allItems = viewModel.allNoteItems
        updateInItems(&allItems)
        viewModel.allNoteItems = allItems
        
        var displayItems = viewModel.noteItems
        updateInItems(&displayItems)
        viewModel.noteItems = displayItems
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

// MARK: - Icon Button View
// Separate view to isolate tap handling and prevent propagation
struct IconButtonView: View {
    let item: NoteItem
    @Binding var iconPickerItem: NoteItem?
    
    var body: some View {
        Button(action: {
            // Set immediately to prevent any other gestures from firing
            iconPickerItem = item
        }) {
            if let icon = item.icon, !icon.isEmpty {
                // Show custom icon or emoji
                if icon.contains(".") {
                    // Custom icon - load from .icons folder (for notes) or folder's .icons folder (for folders)
                    if item.isFolder, case .folder(let folder) = item {
                        IconImageView(iconName: icon, noteFileURL: folder.fileURL, size: 20)
                    } else if case .note(let note) = item {
                        IconImageView(iconName: icon, noteFileURL: note.fileURL, size: 20)
                    } else {
                        Image(systemName: item.isFolder ? "folder.fill" : "doc.text.fill")
                            .foregroundStyle(item.isFolder ? .blue : .secondary)
                            .font(.system(size: item.isFolder ? 14 : 16))
                    }
                } else {
                    // Emoji
                    Text(icon)
                        .font(.system(size: 18))
                }
            } else {
                // Default icons
                Image(systemName: item.isFolder ? "folder.fill" : "doc.text.fill")
                    .foregroundStyle(item.isFolder ? .blue : .secondary)
                    .font(.system(size: item.isFolder ? 14 : 16))
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .allowsHitTesting(true)
        .background(
            // Invisible view that captures all mouse events to prevent propagation
            TapBlockingView()
                .frame(width: 24, height: 24)
        )
    }
}

// MARK: - Tap Blocking View
// Custom NSView that blocks all mouse events from propagating
struct TapBlockingView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = BlockingNSView()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // No updates needed
    }
    
    class BlockingNSView: NSView {
        override func mouseDown(with event: NSEvent) {
            // Consume the mouse event - don't call super
            // This prevents the event from propagating to parent views
        }
        
        override func mouseUp(with event: NSEvent) {
            // Consume the mouse event - don't call super
        }
        
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
            return true
        }
    }
}

// MARK: - Git Push Button

struct GitPushButton: View {
    let viewModel: NotesViewModel
    @AppStorage("autoCommitChanges") private var autoCommitChanges: Bool = false
    @State private var isPushing = false
    @State private var pushError: String?
    @State private var isGitRepo = false
    
    var body: some View {
        Group {
            if isGitRepo && autoCommitChanges {
                VStack(spacing: 0) {
                    Divider()
                    
                    Button {
                        Task {
                            await pushToUpstream()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if isPushing {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 12))
                            }
                            Text("Push to Git")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .disabled(isPushing)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .textBackgroundColor))
                    .quickTooltip("Push committed changes to upstream repository")
                    
                    if let error = pushError {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .top, spacing: 6) {
                                Text(error)
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                                    .textSelection(.enabled)
                                
                                Button {
                                    copyToClipboard(error)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Copy error message")
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 4)
                    }
                }
            }
        }
        .task {
            await checkGitRepo()
        }
        .onReceive(NotificationCenter.default.publisher(for: .storageLocationChanged)) { _ in
            Task {
                await checkGitRepo()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .gitRepositoryInitialized)) { _ in
            Task {
                await checkGitRepo()
            }
        }
        .onChange(of: viewModel.currentNote) { _, _ in
            // Re-check git repo status when note changes (in case repo was initialized)
            Task {
                await checkGitRepo()
            }
        }
        .onChange(of: autoCommitChanges) { _, _ in
            // Re-check git repo status when auto-commit setting changes
            Task {
                await checkGitRepo()
            }
        }
    }
    
    private func checkGitRepo() async {
        await MainActor.run {
            let gitService = GitService()
            isGitRepo = gitService.isGitRepository()
        }
    }
    
    private func pushToUpstream() async {
        await MainActor.run {
            isPushing = true
            pushError = nil
        }
        
        do {
            let gitService = GitService()
            try await gitService.pushToUpstream()
            // Clear any previous error on success
            await MainActor.run {
                pushError = nil
                isPushing = false
            }
        } catch {
            // Extract detailed error information
            var errorMessage = error.localizedDescription
            if let gitError = error as? GitError {
                errorMessage = gitError.localizedDescription ?? errorMessage
            } else {
                // Try to get more details from the error
                let errorString = String(describing: error)
                if errorString != errorMessage {
                    errorMessage = "\(errorMessage)\n\nFull error: \(errorString)"
                }
            }
            
            await MainActor.run {
                pushError = errorMessage
                isPushing = false
            }
        }
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

#Preview {
    let viewModel = NotesViewModel()
    return SidebarView(
        viewModel: viewModel,
        searchText: .constant(""),
        editedContent: .constant("Sample content for preview"),
        isSaved: .constant(true),
        onSave: {}
    )
    .frame(width: 250)
}
