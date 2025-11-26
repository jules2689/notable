import SwiftUI
import AppKit

/// View that displays a custom icon from the .icons folder (supports animated GIFs)
struct IconImageView: View {
    let iconName: String
    let noteFileURL: URL?
    let size: CGFloat
    
    @State private var iconURL: URL?
    
    init(iconName: String, noteFileURL: URL?, size: CGFloat = 24) {
        self.iconName = iconName
        self.noteFileURL = noteFileURL
        self.size = size
    }
    
    var body: some View {
        Group {
            if let iconURL = iconURL, FileManager.default.fileExists(atPath: iconURL.path) {
                // Check if it's a GIF
                if iconURL.pathExtension.lowercased() == "gif" {
                    // Use animated view for GIFs - completely disable hit testing
                    AnimatedIconView(iconURL: iconURL, size: size)
                        .frame(width: size, height: size)
                        .allowsHitTesting(false) // Allow clicks to pass through to button
                        .contentShape(Rectangle()) // Ensure the frame shape is defined
                } else {
                    // Use regular image view for static images
                    if let image = NSImage(contentsOf: iconURL) {
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.high)
                            .antialiased(true)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: size, height: size)
                    } else {
                        Image(systemName: "photo")
                            .foregroundStyle(.tertiary)
                            .font(.system(size: size * 0.6))
                    }
                }
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.tertiary)
                    .font(.system(size: size * 0.6))
            }
        }
        .onAppear {
            loadIconURL()
        }
        .onChange(of: iconName) { _, _ in
            loadIconURL()
        }
        .onChange(of: noteFileURL) { _, _ in
            loadIconURL()
        }
    }
    
    private func loadIconURL() {
        guard let noteFileURL = noteFileURL else {
            iconURL = nil
            return
        }
        
        // Get the .icons folder path (same directory as the note)
        let noteDirectory = noteFileURL.deletingLastPathComponent()
        let iconsFolder = noteDirectory.appendingPathComponent(".icons", isDirectory: true)
        let url = iconsFolder.appendingPathComponent(iconName)
        
        // Check if file exists
        if FileManager.default.fileExists(atPath: url.path) {
            iconURL = url
        } else {
            iconURL = nil
        }
    }
}

