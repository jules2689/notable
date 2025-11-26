import SwiftUI
import AppKit

struct IconPickerView: View {
    @Binding var selectedIcon: String?
    var noteFileURL: URL?
    var onCustomIconSelected: ((URL) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var showingCustomIconPicker = false
    
    // Popular emoji categories - static to avoid recomputation
    private static let emojiCategories: [(name: String, emojis: [String])] = [
        ("Frequently Used", ["📝", "📄", "📋", "📌", "📍", "⭐", "🔥", "💡", "🎯", "✅", "❌", "⚠️", "💬", "📊", "📈", "📉", "🎨", "🎵", "🎬", "📷", "🏠", "🚀", "💻", "📱", "🎮", "📚", "🎓", "🏆", "🎁", "🎉"]),
        ("Objects", ["📝", "📄", "📋", "📌", "📍", "📊", "📈", "📉", "📷", "📹", "🎥", "📺", "📻", "📱", "💻", "⌨️", "🖥️", "🖨️", "📞", "☎️", "📠", "📧", "📮", "📬", "📭", "📦", "📯", "📰", "📑", "📜", "📎", "🖇️", "📏", "📐", "✂️", "🗑️", "🔒", "🔓", "🔐", "🔑"]),
        ("Symbols", ["⭐", "🌟", "✨", "💫", "🔥", "💥", "⚡", "☀️", "🌙", "💎", "🎯", "🎪", "🎭", "🎨", "🎬", "🎵", "🎤", "🎧", "🎸", "🎹", "🥁", "🎺", "🎻", "🎷"]),
        ("Activities", ["🎨", "🎵", "🎬", "🎮", "🎯", "🎲", "🎪", "🎭", "🎤", "🎧", "🎸", "🎹", "🥁", "🎺", "🎻", "🎷", "⚽️", "🏀", "🏈", "⚾️", "🎾", "🏐", "🏉", "🎱"]),
        ("Food", ["🍎", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🍈", "🍒", "🍑", "🥭", "🍍", "🥥", "🥝", "🍅", "🍆", "🥑", "🥦", "🥬", "🥒", "🌶️", "🌽", "🥕", "🥔", "🍠", "🥐", "🥯", "🍞", "🥖", "🥨", "🧀", "🥚", "🍳", "🥞", "🥓", "🥩", "🍗", "🍖", "🌭", "🍔", "🍟", "🍕", "🥪", "🥙", "🌮", "🌯", "🥗", "🥘", "🥫", "🍝", "🍜", "🍲", "🍛", "🍣", "🍱", "☕️", "🍵", "🥤", "🍶", "🍺", "🍻", "🥂", "🍷", "🥃", "🍸", "🍹", "🍾"]),
        ("Nature", ["🌱", "🌲", "🌳", "🌴", "🌵", "🌷", "🌸", "🌹", "🌺", "🌻", "🌼", "🌾", "🌿", "🍀", "🍁", "🍂", "🍃", "🌍", "🌎", "🌏", "🌐", "🌑", "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘", "🌙", "🌚", "🌛", "🌜", "🌝", "🌞", "⭐", "🌟", "✨", "💫", "🔥", "☄️", "💥", "☀️", "🌤️", "⛅", "🌥️", "☁️", "🌦️", "🌧️", "⛈️", "🌩️", "⚡", "☔", "❄️", "⛄", "🌨️", "💨", "🌪️", "🌫️", "🌊"]),
    ]
    
    private var filteredEmojis: [(name: String, emojis: [String])] {
        if searchText.isEmpty {
            return Self.emojiCategories
        }
        
        // For now, show all if searching (search not implemented yet)
        return Self.emojiCategories
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header - shown immediately
            HStack {
                Text("Choose Icon")
                    .font(.headline)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            // Search bar - shown immediately
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search emoji...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
            .cornerRadius(6)
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // Emoji grid - use simpler layout for faster rendering
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(filteredEmojis, id: \.name) { category in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(category.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                            
                            // Use LazyVGrid for better performance
                            let columns = [GridItem](repeating: GridItem(.flexible(), spacing: 8), count: 8)
                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(category.emojis, id: \.self) { emoji in
                                    Button(action: {
                                        selectedIcon = emoji
                                        dismiss()
                                    }) {
                                        Text(emoji)
                                            .font(.system(size: 24))
                                            .frame(width: 40, height: 40)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(selectedIcon == emoji ? Color.accentColor.opacity(0.3) : Color.clear)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            
            Divider()
            
            // Footer with custom icon option - shown immediately
            HStack {
                Button("Custom Icon...") {
                    showingCustomIconPicker = true
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                if selectedIcon != nil {
                    Button("Remove Icon") {
                        selectedIcon = nil
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .frame(width: 400, height: 500)
        .fileImporter(
            isPresented: $showingCustomIconPicker,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    handleCustomIconSelection(url: url)
                }
            case .failure:
                break
            }
        }
    }
    
    private func handleCustomIconSelection(url: URL) {
        // Copy the icon file to the icons folder
        guard let noteFileURL = noteFileURL else {
            // Fallback: just use filename
            selectedIcon = url.lastPathComponent
            dismiss()
            return
        }
        
        // Start accessing security-scoped resource if needed
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        let noteDirectory = noteFileURL.deletingLastPathComponent()
        let iconsFolder = noteDirectory.appendingPathComponent("icons", isDirectory: true)
        let fileManager = FileManager.default
        
        // Create icons folder if it doesn't exist
        do {
            if !fileManager.fileExists(atPath: iconsFolder.path) {
                try fileManager.createDirectory(at: iconsFolder, withIntermediateDirectories: true)
                print("✅ Created icons folder at: \(iconsFolder.path)")
            }
        } catch {
            print("❌ Failed to create icons folder: \(error)")
        }
        
        // Copy the file to icons folder
        let destinationURL = iconsFolder.appendingPathComponent(url.lastPathComponent)
        
        do {
            // Remove existing file if it exists
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
                print("🗑️ Removed existing icon file: \(destinationURL.path)")
            }
            
            // Copy the new file
            try fileManager.copyItem(at: url, to: destinationURL)
            print("✅ Successfully copied icon file from \(url.path) to \(destinationURL.path)")
            
            // Verify the file was copied
            guard fileManager.fileExists(atPath: destinationURL.path) else {
                print("❌ Icon file was not found after copying")
                selectedIcon = url.lastPathComponent
                dismiss()
                return
            }
            
            // Use the filename as the icon identifier
            selectedIcon = url.lastPathComponent
            
            // Call the callback if provided
            onCustomIconSelected?(destinationURL)
            
            dismiss()
        } catch {
            print("❌ Failed to copy icon file: \(error)")
            print("   Source: \(url.path)")
            print("   Destination: \(destinationURL.path)")
            // Fallback: just use filename (but file won't be accessible)
            selectedIcon = url.lastPathComponent
            dismiss()
        }
    }
}

