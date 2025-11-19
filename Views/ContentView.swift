import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            // Sidebar will go here
            Text("Sidebar")
                .frame(minWidth: 200)
        } detail: {
            // Editor will go here
            Text("Editor")
                .frame(minWidth: 400)
        }
    }
}

#Preview {
    ContentView()
}
