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
        ("Objects", ["📝", "📄", "📋", "📌", "📍", "📊", "📈", "📉", "📷", "📹", "🎥", "📺", "📻", "📱", "💻", "⌨️", "🖥️", "🖨️", "📞", "☎️", "📠", "📧", "📮", "📬", "📭", "📦", "📯", "📰", "📑", "📜", "📎", "🖇️", "📏", "📐", "✂️", "🗑️", "🔒", "🔓", "🔐", "🔑"]),
        ("Symbols", ["⭐", "🌟", "✨", "💫", "🔥", "💥", "⚡", "☀️", "🌙", "💎", "🎯", "🎪", "🎭", "🎨", "🎬", "🎵", "🎤", "🎧", "🎸", "🎹", "🥁", "🎺", "🎻", "🎷"]),
        ("Activities", ["🎨", "🎵", "🎬", "🎮", "🎯", "🎲", "🎪", "🎭", "🎤", "🎧", "🎸", "🎹", "🥁", "🎺", "🎻", "🎷", "⚽️", "🏀", "🏈", "⚾️", "🎾", "🏐", "🏉", "🎱"]),
        ("Food", ["🍎", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🍈", "🍒", "🍑", "🥭", "🍍", "🥥", "🥝", "🍅", "🍆", "🥑", "🥦", "🥬", "🥒", "🌶️", "🌽", "🥕", "🥔", "🍠", "🥐", "🥯", "🍞", "🥖", "🥨", "🧀", "🥚", "🍳", "🥞", "🥓", "🥩", "🍗", "🍖", "🌭", "🍔", "🍟", "🍕", "🥪", "🥙", "🌮", "🌯", "🥗", "🥘", "🥫", "🍝", "🍜", "🍲", "🍛", "🍣", "🍱", "☕️", "🍵", "🥤", "🍶", "🍺", "🍻", "🥂", "🍷", "🥃", "🍸", "🍹", "🍾"]),
        ("Nature", ["🌱", "🌲", "🌳", "🌴", "🌵", "🌷", "🌸", "🌹", "🌺", "🌻", "🌼", "🌾", "🌿", "🍀", "🍁", "🍂", "🍃", "🌍", "🌎", "🌏", "🌐", "🌑", "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘", "🌙", "🌚", "🌛", "🌜", "🌝", "🌞", "⭐", "🌟", "✨", "💫", "🔥", "☄️", "💥", "☀️", "🌤️", "⛅", "🌥️", "☁️", "🌦️", "🌧️", "⛈️", "🌩️", "⚡", "☔", "❄️", "⛄", "🌨️", "💨", "🌪️", "🌫️", "🌊"]),
    ]
    
    // Mapping of emojis to human-readable keywords for search
    private static let emojiKeywords: [String: [String]] = [
        // Frequently Used
        "📝": ["memo", "note", "write", "document", "paper"],
        "📄": ["page", "document", "paper", "file"],
        "📋": ["clipboard", "list", "checklist", "notes"],
        "📌": ["pin", "pushpin", "tack", "location"],
        "📍": ["location", "pin", "place", "marker", "map"],
        "⭐": ["star", "favorite", "rating", "important"],
        "🔥": ["fire", "flame", "hot", "burning", "lit"],
        "💡": ["lightbulb", "idea", "bright", "light", "bulb"],
        "🎯": ["target", "dart", "goal", "aim", "bullseye"],
        "✅": ["check", "checkmark", "done", "complete", "yes"],
        "❌": ["cross", "x", "no", "wrong", "cancel", "delete"],
        "⚠️": ["warning", "alert", "caution", "danger"],
        "💬": ["speech", "bubble", "chat", "message", "talk"],
        "📊": ["chart", "bar", "graph", "data", "statistics"],
        "📈": ["chart", "up", "growth", "increase", "trend"],
        "📉": ["chart", "down", "decrease", "fall", "trend"],
        "🎨": ["art", "paint", "palette", "artist", "creative"],
        "🎵": ["music", "note", "song", "melody"],
        "🎬": ["movie", "film", "camera", "cinema", "clapper"],
        "📷": ["camera", "photo", "picture", "photography"],
        "🏠": ["house", "home", "building"],
        "🚀": ["rocket", "launch", "space", "fast", "speed"],
        "💻": ["computer", "laptop", "pc", "mac"],
        "📱": ["phone", "mobile", "smartphone", "cell"],
        "🎮": ["game", "controller", "gaming", "play"],
        "📚": ["books", "library", "study", "education"],
        "🎓": ["graduation", "cap", "degree", "graduate", "school"],
        "🏆": ["trophy", "award", "winner", "champion"],
        "🎁": ["gift", "present", "box", "wrapped"],
        "🎉": ["party", "celebration", "confetti", "tada"],
        
        // Objects
        "📹": ["video", "camera", "recording"],
        "🎥": ["movie", "camera", "film", "cinema"],
        "📺": ["tv", "television", "screen"],
        "📻": ["radio", "music", "broadcast"],
        "⌨️": ["keyboard", "type", "keys"],
        "🖥️": ["computer", "desktop", "monitor", "screen"],
        "🖨️": ["printer", "print"],
        "📞": ["phone", "telephone", "call"],
        "☎️": ["phone", "telephone", "call"],
        "📠": ["fax", "machine"],
        "📧": ["email", "mail", "message"],
        "📮": ["mailbox", "post", "letter"],
        "📬": ["mailbox", "mail", "letter"],
        "📭": ["mailbox", "open", "mail"],
        "📦": ["package", "box", "parcel", "delivery"],
        "📯": ["postal", "horn", "mail"],
        "📰": ["newspaper", "news", "paper"],
        "📑": ["bookmark", "tabs", "page"],
        "📜": ["scroll", "document", "paper"],
        "📎": ["paperclip", "attach", "clip"],
        "🖇️": ["paperclips", "linked", "attach"],
        "📏": ["ruler", "measure", "straight"],
        "📐": ["triangle", "ruler", "math"],
        "✂️": ["scissors", "cut", "clip"],
        "🗑️": ["trash", "delete", "bin", "waste"],
        "🔒": ["lock", "locked", "secure", "private"],
        "🔓": ["unlock", "unlocked", "open"],
        "🔐": ["lock", "key", "secure"],
        "🔑": ["key", "unlock", "access"],
        
        // Symbols
        "🌟": ["star", "glowing", "bright", "sparkle"],
        "✨": ["sparkles", "magic", "shine", "glitter"],
        "💫": ["dizzy", "star", "sparkle"],
        "💥": ["explosion", "boom", "burst"],
        "⚡": ["lightning", "bolt", "electric", "zap"],
        "☀️": ["sun", "sunny", "bright", "day"],
        "🌙": ["moon", "night", "crescent"],
        "💎": ["diamond", "gem", "jewel", "precious"],
        "🎪": ["circus", "tent", "entertainment"],
        "🎭": ["theater", "drama", "masks", "acting"],
        "🎤": ["microphone", "mic", "sing", "karaoke"],
        "🎧": ["headphones", "music", "listen", "audio"],
        "🎸": ["guitar", "music", "rock"],
        "🎹": ["piano", "keyboard", "music"],
        "🥁": ["drum", "music", "beat"],
        "🎺": ["trumpet", "horn", "music"],
        "🎻": ["violin", "music", "orchestra"],
        "🎷": ["saxophone", "sax", "music", "jazz"],
        
        // Activities
        "🎲": ["dice", "game", "gamble", "random"],
        "⚽️": ["soccer", "football", "ball", "sport"],
        "🏀": ["basketball", "ball", "sport"],
        "🏈": ["football", "american", "sport"],
        "⚾️": ["baseball", "ball", "sport"],
        "🎾": ["tennis", "ball", "sport"],
        "🏐": ["volleyball", "ball", "sport"],
        "🏉": ["rugby", "ball", "sport"],
        "🎱": ["pool", "billiards", "8ball", "game"],
        
        // Food
        "🍎": ["apple", "red", "fruit"],
        "🍊": ["orange", "fruit", "citrus"],
        "🍋": ["lemon", "yellow", "fruit", "sour"],
        "🍌": ["banana", "fruit", "yellow"],
        "🍉": ["watermelon", "fruit", "summer"],
        "🍇": ["grapes", "fruit", "wine"],
        "🍓": ["strawberry", "fruit", "red"],
        "🍈": ["melon", "fruit"],
        "🍒": ["cherries", "fruit", "red"],
        "🍑": ["peach", "fruit"],
        "🥭": ["mango", "fruit", "tropical"],
        "🍍": ["pineapple", "fruit", "tropical"],
        "🥥": ["coconut", "fruit", "tropical"],
        "🥝": ["kiwi", "fruit", "green"],
        "🍅": ["tomato", "vegetable", "red"],
        "🍆": ["eggplant", "vegetable", "purple"],
        "🥑": ["avocado", "fruit", "green"],
        "🥦": ["broccoli", "vegetable", "green"],
        "🥬": ["lettuce", "vegetable", "green", "salad"],
        "🥒": ["cucumber", "vegetable", "green"],
        "🌶️": ["pepper", "chili", "spicy", "hot"],
        "🌽": ["corn", "maize", "vegetable"],
        "🥕": ["carrot", "vegetable", "orange"],
        "🥔": ["potato", "vegetable"],
        "🍠": ["sweet", "potato", "yam"],
        "🥐": ["croissant", "bread", "french"],
        "🥯": ["bagel", "bread"],
        "🍞": ["bread", "loaf"],
        "🥖": ["baguette", "bread", "french"],
        "🥨": ["pretzel", "bread", "twisted"],
        "🧀": ["cheese", "dairy"],
        "🥚": ["egg", "chicken"],
        "🍳": ["cooking", "pan", "fried", "egg"],
        "🥞": ["pancakes", "breakfast"],
        "🥓": ["bacon", "meat", "breakfast"],
        "🥩": ["meat", "steak", "beef"],
        "🍗": ["chicken", "leg", "meat"],
        "🍖": ["meat", "bone"],
        "🌭": ["hotdog", "sausage", "frank"],
        "🍔": ["hamburger", "burger", "fast", "food"],
        "🍟": ["fries", "french", "potato"],
        "🍕": ["pizza", "slice"],
        "🥪": ["sandwich"],
        "🥙": ["wrap", "sandwich", "pita"],
        "🌮": ["taco", "mexican"],
        "🌯": ["burrito", "wrap", "mexican"],
        "🥗": ["salad", "green", "healthy"],
        "🥘": ["pot", "cooking", "stew"],
        "🥫": ["can", "canned", "food"],
        "🍝": ["spaghetti", "pasta", "italian"],
        "🍜": ["noodles", "ramen", "soup"],
        "🍲": ["pot", "stew", "cooking"],
        "🍛": ["curry", "rice", "indian"],
        "🍣": ["sushi", "japanese"],
        "🍱": ["bento", "box", "japanese"],
        "☕️": ["coffee", "cafe", "hot", "drink"],
        "🍵": ["tea", "cup", "green", "drink"],
        "🥤": ["drink", "cup", "straw", "soda"],
        "🍶": ["sake", "bottle", "japanese"],
        "🍺": ["beer", "mug", "drink"],
        "🍻": ["beers", "cheers", "drink"],
        "🥂": ["champagne", "toast", "celebration"],
        "🍷": ["wine", "glass", "red"],
        "🥃": ["whiskey", "tumbler", "drink"],
        "🍸": ["cocktail", "martini", "drink"],
        "🍹": ["tropical", "drink", "cocktail"],
        "🍾": ["champagne", "bottle", "celebration"],
        
        // Nature
        "🌱": ["seedling", "plant", "grow", "sprout"],
        "🌲": ["tree", "evergreen", "pine"],
        "🌳": ["tree", "deciduous", "oak"],
        "🌴": ["palm", "tree", "tropical", "coconut"],
        "🌵": ["cactus", "desert", "plant"],
        "🌷": ["tulip", "flower", "spring"],
        "🌸": ["cherry", "blossom", "flower", "spring"],
        "🌹": ["rose", "flower", "red", "love"],
        "🌺": ["hibiscus", "flower", "tropical"],
        "🌻": ["sunflower", "flower", "yellow"],
        "🌼": ["flower", "blossom"],
        "🌾": ["rice", "grain", "harvest"],
        "🌿": ["herb", "leaf", "green"],
        "🍀": ["clover", "four", "leaf", "lucky"],
        "🍁": ["maple", "leaf", "autumn", "fall"],
        "🍂": ["fallen", "leaf", "autumn", "fall"],
        "🍃": ["leaf", "wind", "blowing"],
        "🌍": ["earth", "globe", "world", "europe", "africa"],
        "🌎": ["earth", "globe", "world", "americas"],
        "🌏": ["earth", "globe", "world", "asia", "australia"],
        "🌐": ["globe", "internet", "web", "world"],
        "🌑": ["new", "moon", "dark"],
        "🌒": ["waxing", "crescent", "moon"],
        "🌓": ["first", "quarter", "moon"],
        "🌔": ["waxing", "gibbous", "moon"],
        "🌕": ["full", "moon"],
        "🌖": ["waning", "gibbous", "moon"],
        "🌗": ["last", "quarter", "moon"],
        "🌘": ["waning", "crescent", "moon"],
        "🌚": ["new", "moon", "face"],
        "🌛": ["first", "quarter", "moon", "face"],
        "🌜": ["last", "quarter", "moon", "face"],
        "🌝": ["full", "moon", "face"],
        "🌞": ["sun", "face", "happy"],
        "☄️": ["comet", "space", "tail"],
        "☁️": ["cloud", "weather"],
        "🌤️": ["sun", "cloud", "partly", "cloudy"],
        "⛅": ["sun", "cloud", "partly", "cloudy"],
        "🌥️": ["sun", "cloud", "behind"],
        "🌦️": ["sun", "rain", "cloud"],
        "🌧️": ["rain", "cloud", "weather"],
        "⛈️": ["thunderstorm", "lightning", "rain"],
        "🌩️": ["lightning", "cloud"],
        "☔": ["umbrella", "rain", "weather"],
        "❄️": ["snowflake", "snow", "winter", "cold"],
        "⛄": ["snowman", "snow", "winter"],
        "🌨️": ["snow", "cloud"],
        "💨": ["wind", "dash", "fast", "blow"],
        "🌪️": ["tornado", "cyclone", "storm"],
        "🌫️": ["fog", "mist", "cloudy"],
        "🌊": ["wave", "water", "ocean", "sea"],
    ]
    
    private var filteredEmojis: [(name: String, emojis: [String])] {
        if searchText.isEmpty {
            return Self.emojiCategories
        }
        
        let searchLower = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Filter categories and emojis based on search
        return Self.emojiCategories.compactMap { category in
            // Check if category name matches
            let categoryMatches = category.name.lowercased().contains(searchLower)
            
            // Filter emojis that match the search
            let matchingEmojis = category.emojis.filter { emoji in
                // Check if the emoji character itself matches
                if emoji.contains(searchText) {
                    return true
                }
                
                // Check if category matches (show all emojis in matching categories)
                if categoryMatches {
                    return true
                }
                
                // Check if any keywords match
                if let keywords = Self.emojiKeywords[emoji] {
                    for keyword in keywords {
                        if keyword.lowercased().contains(searchLower) {
                            return true
                        }
                    }
                }
                
                return false
            }
            
            // Only include category if it has matching emojis
            if !matchingEmojis.isEmpty {
                return (name: category.name, emojis: matchingEmojis)
            }
            
            return nil
        }
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
        // Copy the icon file to the .icons folder
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
        let iconsFolder = noteDirectory.appendingPathComponent(".icons", isDirectory: true)
        let fileManager = FileManager.default
        
        // Create .icons folder if it doesn't exist
        do {
            if !fileManager.fileExists(atPath: iconsFolder.path) {
                try fileManager.createDirectory(at: iconsFolder, withIntermediateDirectories: true)
                print("✅ Created .icons folder at: \(iconsFolder.path)")
            }
        } catch {
            print("❌ Failed to create .icons folder: \(error)")
        }
        
        // Copy the file to .icons folder
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

