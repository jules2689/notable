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
    @State private var webdavServerURL: String = StorageLocationManager.shared.webdavServerURL?.absoluteString ?? ""
    @State private var webdavUsername: String = StorageLocationManager.shared.webdavUsername ?? ""
    @State private var webdavPassword: String = ""
    @State private var showingDirectoryPicker = false
    @State private var needsReload = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var isTestingConnection = false
    @State private var connectionTestResult: String?
    @State private var connectionTestColor: Color = .red
    @State private var pathCopied = false
    @State private var logsPathCopied = false
    @Environment(\.dismiss) private var dismiss
    
    private let storageManager = StorageLocationManager.shared
    
    /// Gets the logs directory path for the app
    private var logsDirectoryPath: String {
        let fileManager = FileManager.default
        let bundleID = Bundle.main.bundleIdentifier ?? "com.notable.Notable"
        let homeURL = fileManager.homeDirectoryForCurrentUser
        
        // For sandboxed apps, logs are in ~/Library/Containers/[BundleID]/Data/Library/Logs/
        // For non-sandboxed apps, logs are in ~/Library/Logs/[AppName]/
        // Since the app is sandboxed (based on entitlements), use container path
        let containerLogsURL = homeURL.appendingPathComponent("Library/Containers/\(bundleID)/Data/Library/Logs", isDirectory: true)
        return containerLogsURL.path
    }
    
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
                            Text("Custom Location").tag(StorageLocationType.custom)
                            Text("WebDAV").tag(StorageLocationType.webdav)
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
                                HStack {
                                    Text(storageManager.rootURL.path)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        copyPathToClipboard(storageManager.rootURL.path)
                                    }) {
                                        Image(systemName: pathCopied ? "checkmark.circle.fill" : "doc.on.doc")
                                            .font(.caption)
                                            .foregroundStyle(pathCopied ? .green : .secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Copy path to clipboard")
                                }
                            }
                        } else if storageType == .webdav {
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("Server URL", text: $webdavServerURL)
                                    .textFieldStyle(.roundedBorder)
                                
                                TextField("Username", text: $webdavUsername)
                                    .textFieldStyle(.roundedBorder)
                                
                                SecureField("Password", text: $webdavPassword)
                                    .textFieldStyle(.roundedBorder)
                                
                                HStack {
                                    Button("Test Connection") {
                                        testWebDAVConnection()
                                    }
                                    .disabled(isTestingConnection || webdavServerURL.isEmpty)
                                    
                                    if isTestingConnection {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                    
                                    if let result = connectionTestResult {
                                        Text(result)
                                            .font(.caption)
                                            .foregroundStyle(connectionTestColor)
                                    }
                                }

                                Button("Save WebDAV Configuration") {
                                    saveWebDAVConfiguration()
                                }
                                .disabled(webdavServerURL.isEmpty || webdavUsername.isEmpty || webdavPassword.isEmpty)
                                
                                if let successMessage = successMessage {
                                    Text(successMessage)
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                            }
                        } else {
                            HStack {
                                Text(storageManager.rootURL.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Spacer()
                                
                                Button(action: {
                                    copyPathToClipboard(storageManager.rootURL.path)
                                }) {
                                    Image(systemName: pathCopied ? "checkmark.circle.fill" : "doc.on.doc")
                                        .font(.caption)
                                        .foregroundStyle(pathCopied ? .green : .secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Copy path to clipboard")
                            }
                        }
                    }
                }
                
                Section("Logs Location") {
                    HStack {
                        Text(logsDirectoryPath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Button(action: {
                            copyLogsPathToClipboard(logsDirectoryPath)
                        }) {
                            Image(systemName: logsPathCopied ? "checkmark.circle.fill" : "doc.on.doc")
                                .font(.caption)
                                .foregroundStyle(logsPathCopied ? .green : .secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Copy logs path to clipboard")
                    }
                }
            }
            .formStyle(.grouped)
            .frame(width: 500, height: 550)
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
            webdavServerURL = storageManager.webdavServerURL?.absoluteString ?? ""
            webdavUsername = storageManager.webdavUsername ?? ""
            // Don't load password from keychain in UI for security
        }
    }
    
    private func testWebDAVConnection() {
        guard let serverURL = URL(string: webdavServerURL) else {
            connectionTestResult = "Invalid server URL"
            return
        }
        
        isTestingConnection = true
        connectionTestResult = nil
        connectionTestColor = .red
        
        let testService = WebDAVService(
            serverURL: serverURL,
            username: webdavUsername.isEmpty ? nil : webdavUsername,
            password: webdavPassword.isEmpty ? nil : webdavPassword
        )
        
        Task {
            do {
                let success = try await testService.testConnection()
                await MainActor.run {
                    isTestingConnection = false
                    connectionTestResult = success ? "Connection successful!" : "Connection failed"
                    connectionTestColor = success ? .green : .red
                }
            } catch {
                await MainActor.run {
                    isTestingConnection = false
                    connectionTestResult = "Error: \(error.localizedDescription)"
                    connectionTestColor = .red
                }
            }
        }
    }
    
    private func saveWebDAVConfiguration() {
        guard let serverURL = URL(string: webdavServerURL) else {
            errorMessage = "Invalid server URL"
            successMessage = nil
            return
        }
        
        guard !webdavUsername.isEmpty, !webdavPassword.isEmpty else {
            errorMessage = "Username and password are required"
            successMessage = nil
            return
        }
        
        storageManager.setWebDAVConfiguration(
            serverURL: serverURL,
            username: webdavUsername,
            password: webdavPassword
        )
        
        successMessage = "WebDAV configuration saved successfully"
        errorMessage = nil
        needsReload = true
        connectionTestResult = nil
        connectionTestColor = .red
        // Clear password field after successful save
        webdavPassword = ""
    }
    
    private func copyPathToClipboard(_ path: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(path, forType: .string)
        
        // Show feedback
        pathCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            pathCopied = false
        }
    }
    
    private func copyLogsPathToClipboard(_ path: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(path, forType: .string)
        
        // Show feedback
        logsPathCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            logsPathCopied = false
        }
    }
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
            ZStack(alignment: alignment) {
                placeholder().opacity(shouldShow ? 1 : 0)
                self
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

