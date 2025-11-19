import SwiftUI

// Define a focused value key for the view model
struct NotesViewModelKey: FocusedValueKey {
    typealias Value = NotesViewModel
}

extension FocusedValues {
    var notesViewModel: NotesViewModel? {
        get { self[NotesViewModelKey.self] }
        set { self[NotesViewModelKey.self] = newValue }
    }
}

struct ContentView: View {
    @State private var viewModel = NotesViewModel()
    @State private var searchText = ""
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(viewModel: viewModel, searchText: $searchText)
                .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 400)
                .background(Color(nsColor: .textBackgroundColor))
        } detail: {
            EditorView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 400, ideal: 800)
                .background(Color(nsColor: .textBackgroundColor))
        }
        .navigationSplitViewStyle(.balanced)
        .toolbarBackground(.hidden, for: .windowToolbar)
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .focusedValue(\.notesViewModel, viewModel)
    }
}

#Preview {
    ContentView()
}
