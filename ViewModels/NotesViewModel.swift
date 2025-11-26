import Foundation
import SwiftUI

/// Main view model for the notes application
@Observable
@MainActor
class NotesViewModel: @unchecked Sendable {
    var fileSystemService: FileSystemService
    var noteItems: [NoteItem] = []  // Filtered items for sidebar display
    var allNoteItems: [NoteItem] = []  // Complete unfiltered hierarchy for tab lookups
    var selectedNoteItem: NoteItem?
    var currentNote: Note?
    var isLoading = false
    var isInitialLoadComplete = false
    var errorMessage: String?

    nonisolated(unsafe) private var storageLocationObserver: NSObjectProtocol?
    
    init(fileSystemService: FileSystemService = FileSystemService()) {
        self.fileSystemService = fileSystemService
        
        // Listen for storage location changes
        storageLocationObserver = NotificationCenter.default.addObserver(
            forName: .storageLocationChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleStorageLocationChange()
            }
        }
        
        // Start loading notes immediately
        Task {
            await loadNotes()
        }
    }
    
    deinit {
        if let observer = storageLocationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func handleStorageLocationChange() async {
        // Update the file system service with new storage location
        fileSystemService.updateStorageLocation()
        // Clear current selection and reload notes
        currentNote = nil
        selectedNoteItem = nil
        await loadNotes()
    }

    // MARK: - Loading

    func loadNotes() async {
        isLoading = true
        errorMessage = nil

        // Preserve the current selection before reloading
        let previousNoteFileURL = currentNote?.fileURL
        let previousSelectedItemFileURL = selectedNoteItem?.fileURL

        do {
            let loadedItems = try await fileSystemService.loadNoteHierarchy()
            allNoteItems = loadedItems  // Store complete hierarchy
            noteItems = loadedItems  // Also set as current display items
            
            // Restore selection after reload by matching file URLs
            if let previousFileURL = previousNoteFileURL {
                // Find the note with matching file URL in the complete hierarchy (allNoteItems)
                if let matchingNote = findNote(by: previousFileURL, in: allNoteItems) {
                    // Reload the note directly from disk to ensure we have the absolute latest content
                    // This is important after saves to ensure we get the saved content
                    if let freshNote = Note(fromFileURL: previousFileURL) {
                        currentNote = freshNote
                        selectedNoteItem = .note(freshNote)
                    } else {
                        // Fallback to hierarchy note if direct load fails
                        currentNote = matchingNote
                        selectedNoteItem = .note(matchingNote)
                    }
                } else {
                    // Note was deleted or moved, clear selection
                    currentNote = nil
                    selectedNoteItem = nil
                }
            } else if let previousFileURL = previousSelectedItemFileURL {
                // If we had a folder selected, try to restore it
                if let matchingItem = findItem(by: previousFileURL, in: allNoteItems) {
                    selectedNoteItem = matchingItem
                    if case .note(let note) = matchingItem {
                        currentNote = note
                    } else {
                        currentNote = nil
                    }
                } else {
                    selectedNoteItem = nil
                    currentNote = nil
                }
            }
            
            isLoading = false
            
            // Wait 50ms after loading completes before marking initial load as complete
            if !isInitialLoadComplete {
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                isInitialLoadComplete = true
            }
        } catch {
            errorMessage = "Failed to load notes: \(error.localizedDescription)"
            isLoading = false
            
            // Even on error, mark initial load as complete after delay
            if !isInitialLoadComplete {
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                isInitialLoadComplete = true
            }
        }
    }
    
    /// Recursively finds a note by file URL in the note items hierarchy
    private func findNote(by fileURL: URL, in items: [NoteItem]) -> Note? {
        let targetPath = fileURL.standardized.path
        for item in items {
            switch item {
            case .note(let note):
                // Compare paths to handle URL representation differences
                if note.fileURL.standardized.path == targetPath {
                    return note
                }
            case .folder(let folder):
                if let found = findNote(by: fileURL, in: folder.children) {
                    return found
                }
            }
        }
        return nil
    }
    
    /// Recursively finds an item by file URL in the note items hierarchy
    private func findItem(by fileURL: URL, in items: [NoteItem]) -> NoteItem? {
        let targetPath = fileURL.standardized.path
        for item in items {
            // Compare paths to handle URL representation differences
            if item.fileURL.standardized.path == targetPath {
                return item
            }
            if case .folder(let folder) = item {
                if let found = findItem(by: fileURL, in: folder.children) {
                    return found
                }
            }
        }
        return nil
    }

    // MARK: - Selection

    func selectNote(_ note: Note) {
        currentNote = note
        selectedNoteItem = .note(note)
        fileSystemService.workspace.addToRecent(noteID: note.id)
    }

    func selectFolder(_ folder: Folder) {
        selectedNoteItem = .folder(folder)
        currentNote = nil
    }

    // MARK: - Note Operations

    func createNote(title: String, in folder: Folder? = nil) async {
        do {
            let directoryURL = folder?.fileURL ?? fileSystemService.workspace.rootURL
            let note = try await fileSystemService.createNote(title: title, in: directoryURL)
            await loadNotes()
            selectNote(note)
        } catch {
            errorMessage = "Failed to create note: \(error.localizedDescription)"
        }
    }

    func saveCurrentNote() async {
        guard let note = currentNote else { return }

        do {
            var updatedNote = note
            updatedNote.touch()
            try await fileSystemService.saveNote(updatedNote)
            
            // Small delay to ensure file system has flushed the write
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Reload notes to get fresh content from disk
            await loadNotes()
        } catch {
            errorMessage = "Failed to save note: \(error.localizedDescription)"
        }
    }

    func deleteNote(_ note: Note) async {
        do {
            try await fileSystemService.deleteNote(note)
            // Compare by file URL since IDs may change after reload
            if currentNote?.fileURL == note.fileURL {
                currentNote = nil
                selectedNoteItem = nil
            }
            await loadNotes()
        } catch {
            errorMessage = "Failed to delete note: \(error.localizedDescription)"
        }
    }

    func renameNote(_ note: Note, to newTitle: String) async {
        // Skip if title hasn't actually changed (after sanitization)
        let sanitizedNewTitle = newTitle.trimmingCharacters(in: .whitespaces)
        if sanitizedNewTitle.isEmpty || sanitizedNewTitle == note.title {
            return
        }
        
        do {
            let renamedNote = try await fileSystemService.renameNote(note, to: newTitle)
            // If we got a renamed note back, the rename succeeded - clear any previous error
            // Compare by file URL since IDs may change after reload
            if currentNote?.fileURL == note.fileURL {
                currentNote = renamedNote
            }
            await loadNotes()
            // Clear error message on success
            errorMessage = nil
        } catch FileSystemError.fileAlreadyExists {
            // Check if it's actually the same file - if so, silently ignore
            // Otherwise, show the error
            let invalidChars = CharacterSet(charactersIn: ":/\\?%*|\"<>")
            let sanitizedTitle = newTitle.components(separatedBy: invalidChars).joined(separator: "-")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let currentFilename = note.fileURL.deletingPathExtension().lastPathComponent
            
            // Only show error if the sanitized title is different from current filename
            // This handles cases where the file system allows the rename despite the error
            if sanitizedTitle.caseInsensitiveCompare(currentFilename) != .orderedSame {
                // Double-check: if the file was actually renamed, don't show error
                // This can happen in race conditions where the check fails but the rename succeeds
                let newFilename = "\(sanitizedTitle).md"
                let newURL = note.fileURL.deletingLastPathComponent().appendingPathComponent(newFilename)
                if FileManager.default.fileExists(atPath: newURL.path) {
                    // File exists at new path - check if it's the same file or if rename succeeded
                    // If rename succeeded, we'll find it in loadNotes(), so don't show error
                    // Just reload to pick up the change
                    await loadNotes()
                } else {
                    errorMessage = "Failed to rename note: A file or folder with that name already exists"
                }
            } else {
                // Same file, silently ignore - just reload to ensure state is correct
                await loadNotes()
            }
        } catch {
            errorMessage = "Failed to rename note: \(error.localizedDescription)"
        }
    }

    // MARK: - Folder Operations

    func createFolder(name: String, in parentFolder: Folder? = nil) async {
        do {
            let directoryURL = parentFolder?.fileURL ?? fileSystemService.workspace.rootURL
            let folder = try await fileSystemService.createFolder(name: name, in: directoryURL)
            await loadNotes()
            selectFolder(folder)
        } catch {
            errorMessage = "Failed to create folder: \(error.localizedDescription)"
        }
    }

    func deleteFolder(_ folder: Folder) async {
        do {
            try fileSystemService.deleteFolder(folder)
            // Compare by file URL since IDs may change after reload
            if let selectedItem = selectedNoteItem, selectedItem.fileURL == folder.fileURL {
                currentNote = nil
                selectedNoteItem = nil
            }
            await loadNotes()
        } catch {
            errorMessage = "Failed to delete folder: \(error.localizedDescription)"
        }
    }

    func renameFolder(_ folder: Folder, to newName: String) async {
        do {
            _ = try fileSystemService.renameFolder(folder, to: newName)
            await loadNotes()
        } catch {
            errorMessage = "Failed to rename folder: \(error.localizedDescription)"
        }
    }

    // MARK: - Folder Expansion

    func toggleFolderExpansion(_ folder: Folder) {
        fileSystemService.workspace.toggleFolder(folder.id)
    }

    func isFolderExpanded(_ folder: Folder) -> Bool {
        fileSystemService.workspace.expandedFolders.contains(folder.id)
    }

    // MARK: - Move Operations

    func moveItem(_ item: NoteItem, to folder: Folder) async {
        do {
            _ = try fileSystemService.moveItem(item, to: folder.fileURL)
            await loadNotes()
        } catch {
            errorMessage = "Failed to move item: \(error.localizedDescription)"
        }
    }

    // MARK: - Search

    func searchNotes(query: String) async {
        guard !query.isEmpty else {
            // Clear search: restore full hierarchy to noteItems
            noteItems = allNoteItems
            return
        }

        do {
            let results = try await fileSystemService.searchNotes(query: query)
            // Only update noteItems (for sidebar display), keep allNoteItems intact
            noteItems = results.map { .note($0) }
        } catch {
            errorMessage = "Failed to search notes: \(error.localizedDescription)"
        }
    }
}
