import SwiftUI

/// A tab item representing an open note or empty tab
struct TabItem: Identifiable, Equatable {
    let id: UUID
    var noteID: UUID?
    var title: String
    var fileURL: URL?
    
    /// Whether this is an empty tab with no note
    var isEmpty: Bool {
        noteID == nil
    }
    
    /// Create an empty tab
    static func empty() -> TabItem {
        TabItem(id: UUID(), noteID: nil, title: "New Tab", fileURL: nil)
    }
    
    /// Create a tab for a note
    static func forNote(_ note: Note) -> TabItem {
        TabItem(id: UUID(), noteID: note.id, title: note.title, fileURL: note.fileURL)
    }
    
    // Use default Equatable (compares all fields) so SwiftUI detects title changes
}

/// Custom tab bar for managing open notes
struct TabBarView: View {
    @Binding var tabs: [TabItem]
    @Binding var selectedTabID: UUID?
    var onSelectTab: (TabItem) -> Void
    var onCloseTab: (TabItem) -> Void
    var onNewTab: () -> Void
    
    @State private var hoveredTabID: UUID?
    
    var body: some View {
        HStack(spacing: 0) {
            // Tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 1) {
                    ForEach(tabs) { tab in
                        TabItemView(
                            tab: tab,
                            isSelected: selectedTabID == tab.id,
                            isHovered: hoveredTabID == tab.id,
                            onSelect: { onSelectTab(tab) },
                            onClose: { onCloseTab(tab) }
                        )
                        .onHover { isHovered in
                            hoveredTabID = isHovered ? tab.id : nil
                        }
                    }
                }
                .padding(.leading, 4)
            }
            
            Spacer()
            
            // New tab button
            Button(action: onNewTab) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
        }
        .frame(height: 32)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

/// Individual tab item view
struct TabItemView: View {
    let tab: TabItem
    let isSelected: Bool
    let isHovered: Bool
    var onSelect: () -> Void
    var onClose: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Text(tab.title)
                .font(.system(size: 12))
                .lineLimit(1)
                .foregroundStyle(isSelected ? .primary : .secondary)
            
            // Close button - show on hover or when selected
            if isHovered || isSelected {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 16, height: 16)
                        .background(
                            Circle()
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                        )
                }
                .buttonStyle(.plain)
            } else {
                // Placeholder to maintain consistent width
                Color.clear
                    .frame(width: 16, height: 16)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color(nsColor: .controlBackgroundColor) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color(nsColor: .separatorColor).opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}

#Preview {
    TabBarView(
        tabs: .constant([
            TabItem(id: UUID(), noteID: UUID(), title: "Note 1", fileURL: URL(fileURLWithPath: "/test1.md")),
            TabItem(id: UUID(), noteID: UUID(), title: "Note 2", fileURL: URL(fileURLWithPath: "/test2.md")),
            TabItem.empty()
        ]),
        selectedTabID: .constant(nil),
        onSelectTab: { _ in },
        onCloseTab: { _ in },
        onNewTab: {}
    )
    .frame(width: 600)
}

