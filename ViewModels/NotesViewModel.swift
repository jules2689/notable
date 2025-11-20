import Foundation
import SwiftUI

/// Main view model for the notes application
@Observable
class NotesViewModel {
    var fileSystemService: FileSystemService
    var noteItems: [NoteItem] = []
    var selectedNoteItem: NoteItem?
    var currentNote: Note?
    var isLoading = false
    var errorMessage: String?

    private var storageLocationObserver: NSObjectProtocol?
    
    init(fileSystemService: FileSystemService = FileSystemService()) {
        self.fileSystemService = fileSystemService
        loadNotes()
        
        // Listen for storage location changes
        storageLocationObserver = NotificationCenter.default.addObserver(
            forName: .storageLocationChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleStorageLocationChange()
        }
    }
    
    deinit {
        if let observer = storageLocationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func handleStorageLocationChange() {
        // Update the file system service with new storage location
        fileSystemService.updateStorageLocation()
        // Clear current selection and reload notes
        currentNote = nil
        selectedNoteItem = nil
        loadNotes()
    }

    // MARK: - Loading

    func loadNotes() {
        isLoading = true
        errorMessage = nil

        do {
            noteItems = try fileSystemService.loadNoteHierarchy()
            isLoading = false
        } catch {
            errorMessage = "Failed to load notes: \(error.localizedDescription)"
            isLoading = false
        }
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

    func createNote(title: String, in folder: Folder? = nil) {
        do {
            let directoryURL = folder?.fileURL ?? fileSystemService.workspace.rootURL
            let note = try fileSystemService.createNote(title: title, in: directoryURL)
            loadNotes()
            selectNote(note)
        } catch {
            errorMessage = "Failed to create note: \(error.localizedDescription)"
        }
    }

    func saveCurrentNote() {
        guard let note = currentNote else { return }

        do {
            var updatedNote = note
            updatedNote.touch()
            try fileSystemService.saveNote(updatedNote)
            currentNote = updatedNote
            loadNotes()
        } catch {
            errorMessage = "Failed to save note: \(error.localizedDescription)"
        }
    }

    func deleteNote(_ note: Note) {
        do {
            try fileSystemService.deleteNote(note)
            if currentNote?.id == note.id {
                currentNote = nil
                selectedNoteItem = nil
            }
            loadNotes()
        } catch {
            errorMessage = "Failed to delete note: \(error.localizedDescription)"
        }
    }

    func renameNote(_ note: Note, to newTitle: String) {
        // Skip if title hasn't actually changed (after sanitization)
        let sanitizedNewTitle = newTitle.trimmingCharacters(in: .whitespaces)
        if sanitizedNewTitle.isEmpty || sanitizedNewTitle == note.title {
            return
        }
        
        do {
            let renamedNote = try fileSystemService.renameNote(note, to: newTitle)
            // If we got a renamed note back, the rename succeeded - clear any previous error
            if currentNote?.id == note.id {
                currentNote = renamedNote
            }
            loadNotes()
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
                    loadNotes()
                } else {
                    errorMessage = "Failed to rename note: A file or folder with that name already exists"
                }
            } else {
                // Same file, silently ignore - just reload to ensure state is correct
                loadNotes()
            }
        } catch {
            errorMessage = "Failed to rename note: \(error.localizedDescription)"
        }
    }

    // MARK: - Folder Operations

    func createFolder(name: String, in parentFolder: Folder? = nil) {
        do {
            let directoryURL = parentFolder?.fileURL ?? fileSystemService.workspace.rootURL
            let folder = try fileSystemService.createFolder(name: name, in: directoryURL)
            loadNotes()
            selectFolder(folder)
        } catch {
            errorMessage = "Failed to create folder: \(error.localizedDescription)"
        }
    }

    func deleteFolder(_ folder: Folder) {
        do {
            try fileSystemService.deleteFolder(folder)
            if let selectedItem = selectedNoteItem, selectedItem.id == folder.id {
                currentNote = nil
                selectedNoteItem = nil
            }
            loadNotes()
        } catch {
            errorMessage = "Failed to delete folder: \(error.localizedDescription)"
        }
    }

    func renameFolder(_ folder: Folder, to newName: String) {
        do {
            _ = try fileSystemService.renameFolder(folder, to: newName)
            loadNotes()
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

    func moveItem(_ item: NoteItem, to folder: Folder) {
        do {
            _ = try fileSystemService.moveItem(item, to: folder.fileURL)
            loadNotes()
        } catch {
            errorMessage = "Failed to move item: \(error.localizedDescription)"
        }
    }

    // MARK: - Search

    func searchNotes(query: String) {
        guard !query.isEmpty else {
            loadNotes()
            return
        }

        do {
            let results = try fileSystemService.searchNotes(query: query)
            noteItems = results.map { .note($0) }
        } catch {
            errorMessage = "Failed to search notes: \(error.localizedDescription)"
        }
    }
}
