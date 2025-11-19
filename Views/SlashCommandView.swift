import SwiftUI

/// A popup view that displays slash commands for quick insertion
struct SlashCommandView: View {
    let commands: [SlashCommand]
    let onSelect: (SlashCommand) -> Void
    let onDismiss: () -> Void
    @Binding var selectedIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "command")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text("Slash Commands")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(commands.count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            // Commands list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if commands.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 24))
                                    .foregroundColor(.secondary)
                                Text("No commands found")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        } else {
                            ForEach(Array(commands.enumerated()), id: \.element.id) { index, command in
                                SlashCommandRow(
                                    command: command,
                                    isSelected: index == selectedIndex
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onSelect(command)
                                }
                                .id(index)
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
                .onChange(of: selectedIndex) { _, newIndex in
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 2)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        .frame(width: 360)
    }

    /// Handle keyboard navigation
    func handleKeyPress(_ event: KeyEquivalent) {
        switch event {
        case .downArrow:
            selectedIndex = min(selectedIndex + 1, commands.count - 1)
        case .upArrow:
            selectedIndex = max(selectedIndex - 1, 0)
        case .returnKey:
            if !commands.isEmpty && selectedIndex < commands.count {
                onSelect(commands[selectedIndex])
            }
        case .escape:
            onDismiss()
        default:
            break
        }
    }
}

/// Individual row in the slash command list
struct SlashCommandRow: View {
    let command: SlashCommand
    let isSelected: Bool
    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(command.category == .components ? Color.blue.opacity(0.15) :
                          command.category == .formatting ? Color.purple.opacity(0.15) :
                          Color.green.opacity(0.15))
                    .frame(width: 32, height: 32)

                Image(systemName: command.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(command.category == .components ? .blue :
                                   command.category == .formatting ? .purple :
                                   .green)
            }

            // Text content
            VStack(alignment: .leading, spacing: 2) {
                Text(command.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)

                Text(command.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Category badge
            Text(command.category.rawValue)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            isSelected ? Color.accentColor.opacity(0.15) :
            isHovered ? Color(nsColor: .controlBackgroundColor) :
            Color.clear
        )
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(nsColor: .separatorColor).opacity(0.5)),
            alignment: .bottom
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .cursor(.pointingHand)
    }
}

enum KeyEquivalent {
    case upArrow
    case downArrow
    case returnKey
    case escape
    case other
}

// MARK: - View Extensions

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { isHovered in
            if isHovered {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

#Preview {
    @Previewable @State var selectedIndex = 0

    SlashCommandView(
        commands: SlashCommand.all,
        onSelect: { command in
            print("Selected: \(command.name)")
        },
        onDismiss: {
            print("Dismissed")
        },
        selectedIndex: $selectedIndex
    )
    .frame(width: 400, height: 400)
    .padding()
}
