import SwiftUI
import AppKit

extension Notification.Name {
    static let storageLocationChanged = Notification.Name("storageLocationChanged")
    static let gitRepositoryInitialized = Notification.Name("gitRepositoryInitialized")
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
    @AppStorage("showWordCount") private var showWordCount: Bool = true
    @AppStorage("showReadTime") private var showReadTime: Bool = true
    @AppStorage("autoCommitChanges") private var autoCommitChanges: Bool = false
    @AppStorage("gitUserName") private var gitUserName: String = ""
    @AppStorage("gitUserEmail") private var gitUserEmail: String = ""
    @AppStorage("gitHTTPSToken") private var gitHTTPSToken: String = ""
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
    @State private var isGitRepo = false
    @State private var upstreamURL: String = ""
    @State private var isInitializingGit = false
    @State private var isSavingUpstream = false
    @State private var gitErrorMessage: String?
    @State private var gitSuccessMessage: String?
    @Environment(\.dismiss) private var dismiss
    
    private let storageManager = StorageLocationManager.shared
    private let gitService = GitService()
    
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
                
                Section("Editor") {
                    Toggle("Show Word Count", isOn: $showWordCount)
                    Toggle("Show Estimated Read Time", isOn: $showReadTime)
                }
                
                Section("Git Integration") {
                    Toggle("Auto-commit changes on save", isOn: $autoCommitChanges)
                        .help("Automatically commit note changes to git when saving (only works if the notes folder is a git repository)")
                    
                    TextField("Git User Name", text: $gitUserName)
                        .help("Your name for git commits")
                    
                    TextField("Git User Email", text: $gitUserEmail)
                        .help("Your email for git commits")
                    
                    if autoCommitChanges {
                        if !isGitRepo {
                            // Show initialize button if auto-commit is enabled but not a git repo
                            Button {
                                Task {
                                    await initializeGitRepository()
                                }
                            } label: {
                                HStack {
                                    if isInitializingGit {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "plus.circle.fill")
                                    }
                                    Text("Initialize Git Repository")
                                }
                            }
                            .disabled(isInitializingGit)
                            .help("Initialize a git repository in the notes folder")
                            
                            if let error = gitErrorMessage {
                                HStack(alignment: .top, spacing: 6) {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                        .textSelection(.enabled)
                                    
                                    Button {
                                        copyToClipboard(error)
                                    } label: {
                                        Image(systemName: "doc.on.doc")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Copy error message")
                                }
                            }
                        } else {
                            // Show upstream URL field if it is a git repo
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("Upstream URL", text: $upstreamURL)
                                    .textFieldStyle(.roundedBorder)
                                    .help("Git remote URL (HTTPS or file:// only, e.g., https://github.com/user/repo.git)")
                                
                                // Show token field if URL is HTTPS
                                if upstreamURL.hasPrefix("https://") {
                                    SecureField("HTTPS Token/Password", text: $gitHTTPSToken)
                                        .textFieldStyle(.roundedBorder)
                                        .help("Personal access token or password for HTTPS authentication")
                                }
                                
                                Button {
                                    Task {
                                        await saveUpstreamURL()
                                    }
                                } label: {
                                    HStack {
                                        if isSavingUpstream {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        } else {
                                            Image(systemName: "checkmark.circle.fill")
                                        }
                                        Text("Save Upstream URL")
                                    }
                                }
                                .disabled(isSavingUpstream || upstreamURL.isEmpty)
                                .help("Save the upstream repository URL")
                                
                                if let error = gitErrorMessage {
                                    HStack(alignment: .top, spacing: 6) {
                                        Text(error)
                                            .font(.caption)
                                            .foregroundStyle(.red)
                                            .textSelection(.enabled)
                                        
                                        Button {
                                            copyToClipboard(error)
                                        } label: {
                                            Image(systemName: "doc.on.doc")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                        .help("Copy error message")
                                    }
                                }
                                
                                if let success = gitSuccessMessage {
                                    Text(success)
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                            }
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
                                .quickTooltip("Choose custom storage location")
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
                                    .quickTooltip("Copy path to clipboard")
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
                                    .quickTooltip("Test WebDAV connection")
                                    
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
                                .quickTooltip("Save WebDAV configuration")
                                
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
                        .quickTooltip("Copy logs path to clipboard")
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
                    .quickTooltip("Close settings")
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
        .task {
            // Load initial state
            storageType = storageManager.storageType
            customPath = storageManager.customPath ?? ""
            webdavServerURL = storageManager.webdavServerURL?.absoluteString ?? ""
            webdavUsername = storageManager.webdavUsername ?? ""
            // Don't load password from keychain in UI for security
            
            // Check git repo status and load upstream URL
            await checkGitRepositoryStatus()
        }
        .onAppear {
            // Also update state synchronously for immediate UI updates
            storageType = storageManager.storageType
            customPath = storageManager.customPath ?? ""
            webdavServerURL = storageManager.webdavServerURL?.absoluteString ?? ""
            webdavUsername = storageManager.webdavUsername ?? ""
        }
        .onChange(of: autoCommitChanges) { _, _ in
            // Re-check git status when auto-commit setting changes
            Task {
                await checkGitRepositoryStatus()
            }
        }
        .onChange(of: storageType) { _, _ in
            // Re-check git status when storage location changes
            Task {
                await checkGitRepositoryStatus()
            }
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
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    
    private func checkGitRepositoryStatus() async {
        let isRepo = gitService.isGitRepository()
        await MainActor.run {
            isGitRepo = isRepo
        }
        
        if isRepo {
            // Load current upstream URL
            do {
                print("🔍 Checking for upstream URL...")
                if let url = try await gitService.getUpstreamURL() {
                    print("✅ Found upstream URL: \(url)")
                    await MainActor.run {
                        upstreamURL = url
                    }
                } else {
                    print("⚠️ No upstream URL found (remote exists but returned nil)")
                    await MainActor.run {
                        upstreamURL = ""
                    }
                }
            } catch {
                print("❌ Error getting upstream URL: \(error.localizedDescription)")
                await MainActor.run {
                    upstreamURL = ""
                    // Don't set error message here, just log it
                }
            }
        } else {
            await MainActor.run {
                upstreamURL = ""
            }
        }
        
        await MainActor.run {
            gitErrorMessage = nil
            gitSuccessMessage = nil
        }
    }
    
    private func initializeGitRepository() async {
        isInitializingGit = true
        gitErrorMessage = nil
        gitSuccessMessage = nil
        
        do {
            try await gitService.initializeGitRepository()
            await MainActor.run {
                isInitializingGit = false
                isGitRepo = true
                gitSuccessMessage = "Git repository initialized successfully"
            }
            
            // Re-check status to load upstream URL
            await checkGitRepositoryStatus()
            
            // Notify that git repo was initialized so sidebar can update
            NotificationCenter.default.post(name: .gitRepositoryInitialized, object: nil)
        } catch {
            await MainActor.run {
                isInitializingGit = false
                gitErrorMessage = error.localizedDescription
            }
        }
    }
    
    private func saveUpstreamURL() async {
        isSavingUpstream = true
        gitErrorMessage = nil
        gitSuccessMessage = nil
        
        do {
            try await gitService.setUpstreamURL(upstreamURL)
            await MainActor.run {
                isSavingUpstream = false
                gitSuccessMessage = "Upstream URL saved successfully"
            }
            
            // Reload the upstream URL to ensure it's correctly displayed (in case it was modified, e.g., token embedded)
            await checkGitRepositoryStatus()
        } catch {
            await MainActor.run {
                isSavingUpstream = false
                gitErrorMessage = error.localizedDescription
            }
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
        .quickTooltip("Set appearance to \(title.lowercased())")
    }
}

#Preview {
    SettingsView()
}

