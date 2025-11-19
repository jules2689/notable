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

    init(fileSystemService: FileSystemService = FileSystemService()) {
        self.fileSystemService = fileSystemService
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
        do {
            let renamedNote = try fileSystemService.renameNote(note, to: newTitle)
            if currentNote?.id == note.id {
                currentNote = renamedNote
            }
            loadNotes()
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
