import SwiftUI
import AppKit

// Define a focused value key for the view model
struct NotesViewModelKey: FocusedValueKey {
    typealias Value = NotesViewModel
}

// Define a focused value key for showing settings
struct ShowingSettingsKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {
    var notesViewModel: NotesViewModel? {
        get { self[NotesViewModelKey.self] }
        set { self[NotesViewModelKey.self] = newValue }
    }
    
    var showingSettings: Binding<Bool>? {
        get { self[ShowingSettingsKey.self] }
        set { self[ShowingSettingsKey.self] = newValue }
    }
}

struct ContentView: View {
    @State private var viewModel = NotesViewModel()
    @State private var searchText = ""
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showingSettings = false
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system

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
        .preferredColorScheme(appearanceMode.effectiveColorScheme())
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .focusedValue(\.notesViewModel, viewModel)
        .focusedValue(\.showingSettings, $showingSettings)
        .background(WindowTabbingModifier())
    }
}

// View modifier to enable window tabbing for all windows
struct WindowTabbingModifier: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.tabbingMode = .preferred
                window.tabbingIdentifier = "main"
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window {
            window.tabbingMode = .preferred
            window.tabbingIdentifier = "main"
        }
    }
}

#Preview {
    ContentView()
}
