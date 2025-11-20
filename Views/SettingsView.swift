import SwiftUI
import AppKit

enum AppearanceMode: String, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil
        }
    }
    
    func effectiveColorScheme() -> ColorScheme? {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            // Read the actual system appearance from NSApp
            let systemAppearance = NSApp.effectiveAppearance
            if systemAppearance.name == .darkAqua || systemAppearance.name == .vibrantDark {
                return .dark
            } else {
                return .light
            }
        }
    }
}

struct SettingsView: View {
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    HStack(spacing: 12) {
                        AppearanceRadioButton(
                            mode: .light,
                            icon: "sun.max.fill",
                            title: "Light",
                            isSelected: appearanceMode == .light
                        ) {
                            appearanceMode = .light
                        }
                        
                        AppearanceRadioButton(
                            mode: .dark,
                            icon: "moon.fill",
                            title: "Dark",
                            isSelected: appearanceMode == .dark
                        ) {
                            appearanceMode = .dark
                        }
                        
                        AppearanceRadioButton(
                            mode: .system,
                            icon: "circle.lefthalf.filled",
                            title: "System",
                            isSelected: appearanceMode == .system
                        ) {
                            appearanceMode = .system
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .frame(width: 500, height: 300)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(appearanceMode.effectiveColorScheme())
    }
}

struct AppearanceRadioButton: View {
    let mode: AppearanceMode
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.accentColor : Color.secondary, lineWidth: 2)
                    )
                    .overlay(
                        Circle()
                            .fill(isSelected ? Color.white : Color.clear)
                            .frame(width: 6, height: 6)
                    )
                
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView()
}

