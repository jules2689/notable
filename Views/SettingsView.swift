import SwiftUI
import AppKit

extension Notification.Name {
    static let storageLocationChanged = Notification.Name("storageLocationChanged")
}

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
    @State private var storageType: StorageLocationType = StorageLocationManager.shared.storageType
    @State private var customPath: String = StorageLocationManager.shared.customPath ?? ""
    @State private var showingDirectoryPicker = false
    @State private var needsReload = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    
    private let storageManager = StorageLocationManager.shared
    
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
                
                Section("Storage Location") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Storage Location", selection: $storageType) {
                            Text("Default").tag(StorageLocationType.default)
                            if storageManager.isICloudAvailable {
                                Text("iCloud").tag(StorageLocationType.iCloud)
                            } else {
                                Text("iCloud (Not Available)").tag(StorageLocationType.iCloud)
                                    .disabled(true)
                            }
                            Text("Custom Location").tag(StorageLocationType.custom)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: storageType) { oldValue, newValue in
                            storageManager.storageType = newValue
                            if newValue == .custom && customPath.isEmpty {
                                showingDirectoryPicker = true
                            }
                            needsReload = true
                        }
                        
                        if storageType == .custom {
                            HStack {
                                TextField("Custom Path", text: $customPath)
                                    .textFieldStyle(.roundedBorder)
                                    .disabled(true)
                                
                                Button("Choose...") {
                                    showingDirectoryPicker = true
                                }
                            }
                            
                            if !customPath.isEmpty {
                                Text(storageManager.rootURL.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text(storageManager.rootURL.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        if storageType == .iCloud && !storageManager.isICloudAvailable {
                            Text("iCloud is not available. Please sign in to iCloud in System Settings.")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .frame(width: 500, height: 400)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if needsReload {
                            // Post notification to reload notes
                            NotificationCenter.default.post(name: .storageLocationChanged, object: nil)
                        }
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showingDirectoryPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        do {
                            // Verify the URL is accessible
                            guard url.startAccessingSecurityScopedResource() else {
                                errorMessage = "Failed to access selected directory. Please try again."
                                return
                            }
                            url.stopAccessingSecurityScopedResource()
                            
                            // Create security-scoped bookmark
                            try storageManager.setCustomLocation(url)
                            // Update the displayed path from the manager (which resolves from bookmark)
                            customPath = storageManager.customPath ?? url.path
                            needsReload = true
                            errorMessage = nil
                        } catch {
                            errorMessage = "Failed to set custom location: \(error.localizedDescription)"
                        }
                    }
                case .failure(let error):
                    errorMessage = "Failed to select directory: \(error.localizedDescription)"
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
        }
        .preferredColorScheme(appearanceMode.effectiveColorScheme())
        .onAppear {
            storageType = storageManager.storageType
            customPath = storageManager.customPath ?? ""
        }
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

