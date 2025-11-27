import Foundation
import SwiftGitX

/// Service for handling Git operations on the notes repository
@MainActor
class GitService {
    private let fileManager = FileManager.default
    private let storageManager = StorageLocationManager.shared
    
    init() {
        // Initialize SwiftGitX
        try? SwiftGitX.initialize()
    }
    
    deinit {
        // Shutdown SwiftGitX
        try? SwiftGitX.shutdown()
    }
    
    /// Checks if the notes directory is a git repository
    func isGitRepository(at url: URL) -> Bool {
        // Ensure security-scoped access for custom locations
        _ = storageManager.startAccessingSecurityScopedResource()
        defer {
            storageManager.stopAccessingSecurityScopedResource()
        }
        
        let gitDir = url.appendingPathComponent(".git", isDirectory: true)
        return fileManager.fileExists(atPath: gitDir.path)
    }
    
    /// Checks if the current workspace root is a git repository
    func isGitRepository() -> Bool {
        let rootURL = storageManager.rootURL
        return isGitRepository(at: rootURL)
    }
    
    /// Opens a repository at the given URL (must be called on MainActor)
    /// Note: Security-scoped access should be maintained by the caller for the duration of repository operations
    private func openRepository(at url: URL) throws -> Repository {
        // Ensure the directory exists and is accessible
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
        
        // Check for and remove any stale git lock files
        let gitDir = url.appendingPathComponent(".git", isDirectory: true)
        if fileManager.fileExists(atPath: gitDir.path) {
            let configLock = gitDir.appendingPathComponent("config.lock")
            if fileManager.fileExists(atPath: configLock.path) {
                // Remove stale lock file
                try? fileManager.removeItem(at: configLock)
            }
        }
        
        return try Repository(at: url)
    }
    
    /// Commits all changes in the repository with the given message
    func commitChanges(message: String, in directory: URL) async throws {
        // Check if it's a git repo first (on main actor)
        guard isGitRepository(at: directory) else {
            throw GitError.notAGitRepository
        }
        
        // Ensure security-scoped access for custom locations - maintain throughout entire operation
        let hasAccess = storageManager.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                storageManager.stopAccessingSecurityScopedResource()
            }
        }
        
        // Keep repository operations on MainActor since Repository is not Sendable
        try await MainActor.run {
            let repo = try self.openRepository(at: directory)
            
            // Set git user config if provided
            let gitUserName = UserDefaults.standard.string(forKey: "gitUserName") ?? ""
            let gitUserEmail = UserDefaults.standard.string(forKey: "gitUserEmail") ?? ""
            
            // Set git config values - try using config API first, fallback to direct file write
            let gitDir = directory.appendingPathComponent(".git", isDirectory: true)
            let configFile = gitDir.appendingPathComponent("config")
            
            if !gitUserName.isEmpty || !gitUserEmail.isEmpty {
                // Try to set via config API if available
                do {
                    if !gitUserName.isEmpty {
                        try repo.config.set("user.name", forKey: gitUserName)
                    }
                    if !gitUserEmail.isEmpty {
                        try repo.config.set("user.email", forKey: gitUserEmail)
                    }
                } catch {
                    // Fallback: write directly to config file
                    var configContent = ""
                    if fileManager.fileExists(atPath: configFile.path) {
                        configContent = (try? String(contentsOf: configFile, encoding: .utf8)) ?? ""
                    }
                    
                    // Remove existing user.name and user.email lines
                    let lines = configContent.components(separatedBy: .newlines)
                    var newLines: [String] = []
                    var inUserSection = false
                    
                    for line in lines {
                        if line.trimmingCharacters(in: .whitespaces).hasPrefix("[user]") {
                            inUserSection = true
                            newLines.append(line)
                        } else if line.trimmingCharacters(in: .whitespaces).hasPrefix("[") && !line.trimmingCharacters(in: .whitespaces).hasPrefix("[user]") {
                            if inUserSection {
                                // Add user config before leaving user section
                                if !gitUserName.isEmpty {
                                    newLines.append("\tname = \(gitUserName)")
                                }
                                if !gitUserEmail.isEmpty {
                                    newLines.append("\temail = \(gitUserEmail)")
                                }
                                inUserSection = false
                            }
                            newLines.append(line)
                        } else if inUserSection && (line.trimmingCharacters(in: .whitespaces).hasPrefix("name =") || line.trimmingCharacters(in: .whitespaces).hasPrefix("email =")) {
                            // Skip existing name/email lines, we'll add new ones
                            continue
                        } else {
                            newLines.append(line)
                        }
                    }
                    
                    // Add [user] section if it didn't exist
                    if !inUserSection && (!gitUserName.isEmpty || !gitUserEmail.isEmpty) {
                        if !newLines.isEmpty && !newLines.last!.isEmpty {
                            newLines.append("")
                        }
                        newLines.append("[user]")
                        if !gitUserName.isEmpty {
                            newLines.append("\tname = \(gitUserName)")
                        }
                        if !gitUserEmail.isEmpty {
                            newLines.append("\temail = \(gitUserEmail)")
                        }
                    } else if inUserSection {
                        // We were in user section at end of file
                        if !gitUserName.isEmpty {
                            newLines.append("\tname = \(gitUserName)")
                        }
                        if !gitUserEmail.isEmpty {
                            newLines.append("\temail = \(gitUserEmail)")
                        }
                    }
                    
                    try newLines.joined(separator: "\n").write(to: configFile, atomically: true, encoding: .utf8)
                }
            }
            
            // Clean up any stale lock files before operations
            if fileManager.fileExists(atPath: gitDir.path) {
                let indexLock = gitDir.appendingPathComponent("index.lock")
                try? fileManager.removeItem(at: indexLock)
            }
            
            do {
                // Add all files - SwiftGitX doesn't support "." so we need to add files individually
                // Capture fileManager for use in nested function
                let fm = self.fileManager
                
                // Recursively find all files in the directory
                func getAllFiles(in dirURL: URL, baseURL: URL) throws -> [String] {
                    var files: [String] = []
                    let contents = try fm.contentsOfDirectory(
                        at: dirURL,
                        includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
                        options: [.skipsHiddenFiles]
                    )
                    
                    for itemURL in contents {
                        // Skip .git directory
                        if itemURL.lastPathComponent == ".git" {
                            continue
                        }
                        
                        var isDirectory: ObjCBool = false
                        if fm.fileExists(atPath: itemURL.path, isDirectory: &isDirectory) {
                            if isDirectory.boolValue {
                                // Recursively get files in subdirectory
                                let subFiles = try getAllFiles(in: itemURL, baseURL: baseURL)
                                files.append(contentsOf: subFiles)
                            } else {
                                // Get relative path from repository root
                                let relativePath = itemURL.path.replacingOccurrences(
                                    of: baseURL.path + "/",
                                    with: ""
                                )
                                files.append(relativePath)
                            }
                        }
                    }
                    
                    return files
                }
                
                // Get all files recursively
                let allFiles = try getAllFiles(in: directory, baseURL: directory)
                
                // Add each file to the index
                for relativePath in allFiles {
                    try repo.add(path: relativePath)
                }
                
                // Commit changes
                try repo.commit(message: message)
            } catch let error {
                let errorDetails = extractErrorDetails(from: error)
                // Check if it's a permissions error
                if errorDetails.contains("Operation not permitted") || errorDetails.contains("lock") {
                    let storageType = storageManager.storageType
                    if storageType == .default {
                        throw GitError.commitFailed("Permission denied when committing. The Documents folder has restricted write access in the app sandbox. Please go to Settings → Storage Location and select 'Custom Location' to choose a folder outside the sandbox.")
                    } else {
                        throw GitError.commitFailed("Permission denied when committing. Please check that the storage location has proper write permissions. Error: \(errorDetails)")
                    }
                }
                throw GitError.commitFailed("Failed to commit changes: \(errorDetails)")
            }
        }
    }
    
    /// Commits all changes in the current workspace
    func commitChanges(message: String) async throws {
        let rootURL = storageManager.rootURL
        try await commitChanges(message: message, in: rootURL)
    }
    
    /// Pushes changes to the upstream repository
    func pushToUpstream(in directory: URL) async throws {
        // Check if it's a git repo first (on main actor)
        guard isGitRepository(at: directory) else {
            throw GitError.notAGitRepository
        }
        
        // Ensure security-scoped access for custom locations - maintain throughout entire operation
        let hasAccess = storageManager.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                storageManager.stopAccessingSecurityScopedResource()
            }
        }
        
        // Since we're @MainActor, work directly with Repository
        let repo = try self.openRepository(at: directory)
        
        // Check if there are any commits first
        let hasCommits: Bool
        do {
            _ = try repo.HEAD.target
            hasCommits = true
        } catch {
            hasCommits = false
        }
        
        guard hasCommits else {
            throw GitError.pushFailed("No commits to push. Please make at least one commit before pushing.")
        }
        
        // Get the current branch
        let branch: Branch
        if let head = try? repo.HEAD.target as? Branch {
            branch = head
        } else {
            // Try to get the default branch (main or master)
            // If HEAD is not pointing to a branch, try to find the default branch
            let defaultBranchNames = ["main", "master"]
            var foundBranch: Branch?
            for branchName in defaultBranchNames {
                if let br = try? repo.branch.get(named: branchName) {
                    foundBranch = br
                    break
                }
            }
            
            guard let defaultBranch = foundBranch else {
                throw GitError.pushFailed("Could not determine current branch. Please make at least one commit to create a branch.")
            }
            branch = defaultBranch
        }
        
        // Get the remote (default to origin)
        let remoteName = "origin"
        guard let remote = try? repo.remote.get(named: remoteName) else {
            throw GitError.pushFailed("No remote named '\(remoteName)' configured")
        }
        
        // Debug: Print remote URL
        let remoteURLString = remote.url.absoluteString
        print("📤 Pushing to remote: \(remoteURLString)")
        
        // Configure HTTPS credentials if needed
        if remoteURLString.hasPrefix("https://") {
            let httpsToken = UserDefaults.standard.string(forKey: "gitHTTPSToken") ?? ""
            if !httpsToken.isEmpty {
                // Embed token in URL for HTTPS authentication
                // Format: https://token@host/path
                if let remoteURL = URL(string: remoteURLString) {
                    var components = URLComponents(url: remoteURL, resolvingAgainstBaseURL: false)
                    components?.user = httpsToken.isEmpty ? nil : httpsToken
                    if let newURL = components?.url {
                        // Update remote URL with embedded token
                        do {
                            try repo.remote.remove(remote)
                            try repo.remote.add(named: remoteName, at: newURL)
                            print("🔑 Configured HTTPS authentication with token")
                        } catch {
                            print("⚠️ Failed to update remote with token, will try without")
                        }
                    }
                }
            } else {
                print("⚠️ No HTTPS token configured for HTTPS remote")
            }
        }
        
        // Push to remote - create a Task isolated to MainActor to avoid Sendable warnings
        do {
            try await Task { @MainActor in
                try await repo.push(remote: remote)
            }.value
            print("✅ Push successful")
        } catch let error {
            let errorDetails = extractErrorDetails(from: error)
            
            // Debug: Print error details
            print("❌ Push failed with error: \(errorDetails)")
            
            // Provide more detailed error message with authentication hints
            var errorMessage = "Failed to push to remote: \(errorDetails)"
            if errorDetails.contains("could not read refs") || errorDetails.contains("authentication") || errorDetails.contains("Category: 12") {
                errorMessage += "\n\nThis might be an authentication issue."
                if remoteURLString.hasPrefix("https://") {
                    let httpsToken = UserDefaults.standard.string(forKey: "gitHTTPSToken") ?? ""
                    if httpsToken.isEmpty {
                        errorMessage += "\n• No HTTPS token configured. Please enter a token in Settings → Git Integration."
                    } else {
                        errorMessage += "\n• HTTPS token is configured."
                    }
                    errorMessage += "\n\nMake sure:"
                    errorMessage += "\n1. Your HTTPS token/password is entered in Settings → Git Integration"
                    errorMessage += "\n2. The token has the correct permissions (repo access for GitHub)"
                    errorMessage += "\n3. The token is valid and not expired"
                } else if remoteURLString.hasPrefix("file://") {
                    errorMessage += "\n• File-based remote detected. Check file permissions."
                } else {
                    errorMessage += "\n• Only HTTPS and file:// URLs are supported. SSH URLs are not supported."
                }
            }
            throw GitError.pushFailed(errorMessage)
        }
    }
    
    /// Pushes changes to upstream in the current workspace
    func pushToUpstream() async throws {
        let rootURL = storageManager.rootURL
        try await pushToUpstream(in: rootURL)
    }
    
    /// Initializes a git repository in the specified directory
    func initializeGitRepository(in directory: URL) async throws {
        // Check if it's already a git repo
        guard !isGitRepository(at: directory) else {
            throw GitError.alreadyAGitRepository
        }
        
        // Ensure security-scoped access for custom locations
        let hasAccess = storageManager.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                storageManager.stopAccessingSecurityScopedResource()
            }
        }
        
        // Keep repository operations on MainActor
        try await MainActor.run {
            _ = try Repository.create(at: directory)
        }
    }
    
    /// Initializes a git repository in the current workspace
    func initializeGitRepository() async throws {
        let rootURL = storageManager.rootURL
        try await initializeGitRepository(in: rootURL)
    }
    
    /// Gets the upstream URL for the current branch
    func getUpstreamURL(in directory: URL) async throws -> String? {
        guard isGitRepository(at: directory) else {
            throw GitError.notAGitRepository
        }
        
        // Ensure security-scoped access for custom locations - maintain throughout entire operation
        let hasAccess = storageManager.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                storageManager.stopAccessingSecurityScopedResource()
            }
        }
        
        // Keep repository operations on MainActor
        return try await MainActor.run { () -> String? in
            let repo = try self.openRepository(at: directory)
            
            // Try to get origin remote URL (don't require a branch HEAD)
            if let remote = try? repo.remote.get(named: "origin") {
                var urlString = remote.url.absoluteString
                
                // Strip token from URL for display (https://token@host/path -> https://host/path)
                if urlString.hasPrefix("https://") {
                    if let url = URL(string: urlString) {
                        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                        components?.user = nil
                        if let cleanURL = components?.url {
                            urlString = cleanURL.absoluteString
                        }
                    }
                }
                
                print("✅ Retrieved upstream URL: \(urlString)")
                return urlString
            }
            
            print("⚠️ No 'origin' remote found")
            return nil
        }
    }
    
    /// Gets the upstream URL for the current workspace
    func getUpstreamURL() async throws -> String? {
        let rootURL = storageManager.rootURL
        return try await getUpstreamURL(in: rootURL)
    }
    
    /// Sets the upstream URL for the current branch
    func setUpstreamURL(_ urlString: String, in directory: URL) async throws {
        guard isGitRepository(at: directory) else {
            throw GitError.notAGitRepository
        }
        
            // Validate URL - only allow HTTPS or file://
            if !urlString.hasPrefix("https://") && !urlString.hasPrefix("http://") && !urlString.hasPrefix("file://") && !urlString.hasPrefix("/") {
                throw GitError.invalidURL
            }
            
            // Reject SSH URLs
            if urlString.hasPrefix("git@") {
                throw GitError.setUpstreamFailed("SSH URLs are not supported. Please use HTTPS (e.g., https://github.com/user/repo.git) or a file:// URL.")
            }
        
        // Ensure security-scoped access for custom locations - maintain throughout entire operation
        let hasAccess = storageManager.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                storageManager.stopAccessingSecurityScopedResource()
            }
        }
        
        // Keep repository operations on MainActor
        try await MainActor.run {
            // Ensure directory exists and clean up any stale lock files before opening repo
            if !fileManager.fileExists(atPath: directory.path) {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            }
            
            // Clean up any stale git lock files that might prevent operations
            let gitDir = directory.appendingPathComponent(".git", isDirectory: true)
            if fileManager.fileExists(atPath: gitDir.path) {
                // Remove any stale lock files
                let configLock = gitDir.appendingPathComponent("config.lock")
                if fileManager.fileExists(atPath: configLock.path) {
                    // Try to remove stale lock file (ignore errors, will fail later if truly not writable)
                    try? fileManager.removeItem(at: configLock)
                }
            }
            
            let repo = try self.openRepository(at: directory)
            
            // Get the current branch name
            let branchName: String
            if let head = try? repo.HEAD.target as? Branch {
                branchName = head.name.replacingOccurrences(of: "refs/heads/", with: "")
            } else {
                branchName = "main"
            }
            
            // Check if origin remote exists
            let remoteName = "origin"
            
            // Create URL from string - only allow HTTPS or file:// URLs
            let remoteURL: URL
            if urlString.hasPrefix("https://") {
                // HTTPS URL - validate and use as-is
                guard let httpsURL = URL(string: urlString) else {
                    throw GitError.setUpstreamFailed("Invalid HTTPS URL format. Please use a full HTTPS URL (e.g., https://github.com/user/repo.git)")
                }
                remoteURL = httpsURL
            } else if urlString.hasPrefix("http://") {
                // HTTP URL (not recommended but allowed)
                guard let httpURL = URL(string: urlString) else {
                    throw GitError.setUpstreamFailed("Invalid HTTP URL format. Please use HTTPS instead for security.")
                }
                remoteURL = httpURL
            } else if urlString.hasPrefix("file://") || urlString.hasPrefix("/") {
                // File-based URL
                if urlString.hasPrefix("file://") {
                    guard let fileURL = URL(string: urlString) else {
                        throw GitError.setUpstreamFailed("Invalid file:// URL format.")
                    }
                    remoteURL = fileURL
                } else {
                    // Absolute file path
                    remoteURL = URL(fileURLWithPath: urlString)
                }
            } else if urlString.hasPrefix("git@") {
                // Reject SSH URLs
                throw GitError.setUpstreamFailed("SSH URLs are not supported. Please use HTTPS (e.g., https://github.com/user/repo.git) or a file:// URL.")
            } else {
                throw GitError.setUpstreamFailed("Invalid URL format. Only HTTPS and file:// URLs are supported. Please use a full URL (e.g., https://github.com/user/repo.git)")
            }
            
            // Check if remote exists - be more explicit about error handling
            let existingRemote: Remote?
            do {
                existingRemote = try repo.remote.get(named: remoteName)
            } catch {
                // Remote doesn't exist or error getting it
                existingRemote = nil
            }
            
            // For HTTPS URLs, embed token if provided
            var finalRemoteURL = remoteURL
            if remoteURL.absoluteString.hasPrefix("https://") {
                let httpsToken = UserDefaults.standard.string(forKey: "gitHTTPSToken") ?? ""
                if !httpsToken.isEmpty {
                    // Embed token in URL: https://token@host/path
                    var components = URLComponents(url: remoteURL, resolvingAgainstBaseURL: false)
                    components?.user = httpsToken
                    if let tokenURL = components?.url {
                        finalRemoteURL = tokenURL
                        print("🔑 Embedding HTTPS token in remote URL")
                    }
                }
            }
            
            if let existingRemote = existingRemote {
                // Update existing remote URL
                do {
                    // Clean up any stale lock files before operations
                    let configLock = gitDir.appendingPathComponent("config.lock")
                    try? fileManager.removeItem(at: configLock)
                    
                    try repo.remote.remove(existingRemote)
                    
                    // Clean up lock file again after remove, before add
                    try? fileManager.removeItem(at: configLock)
                    try repo.remote.add(named: remoteName, at: finalRemoteURL)
                } catch let error {
                    let errorDetails = extractErrorDetails(from: error)
                    // Check if it's a permissions error
                    if errorDetails.contains("Operation not permitted") || errorDetails.contains("config.lock") {
                        let storageType = storageManager.storageType
                        if storageType == .default {
                            throw GitError.setUpstreamFailed("Permission denied when writing to git config. The Documents folder has restricted write access in the app sandbox. Please go to Settings → Storage Location and select 'Custom Location' to choose a folder outside the sandbox, then try again.")
                        } else {
                            throw GitError.setUpstreamFailed("Permission denied when writing to git config. Please check that the storage location has proper write permissions.")
                        }
                    }
                    throw GitError.setUpstreamFailed("Failed to update remote URL: \(errorDetails). URL: \(urlString)")
                }
            } else {
                // Add new remote
                do {
                    // Clean up lock file before adding
                    let configLock = gitDir.appendingPathComponent("config.lock")
                    try? fileManager.removeItem(at: configLock)
                    try repo.remote.add(named: remoteName, at: finalRemoteURL)
                } catch let error {
                    let errorDetails = extractErrorDetails(from: error)
                    // Check if it's a permissions error
                    if errorDetails.contains("Operation not permitted") || errorDetails.contains("config.lock") {
                        let storageType = storageManager.storageType
                        if storageType == .default {
                            throw GitError.setUpstreamFailed("Permission denied when writing to git config. The Documents folder has restricted write access in the app sandbox. Please go to Settings → Storage Location and select 'Custom Location' to choose a folder outside the sandbox, then try again.")
                        } else {
                            throw GitError.setUpstreamFailed("Permission denied when writing to git config. Please check that the storage location has proper write permissions.")
                        }
                    }
                    throw GitError.setUpstreamFailed("Failed to add remote: \(errorDetails). URL: \(urlString). Make sure the URL is valid and accessible.")
                }
            }
            
            // Set upstream tracking for current branch
            // This might need to be done via config or a different API
            // For now, we'll set it if the API supports it
        }
    }
    
    /// Sets the upstream URL for the current workspace
    func setUpstreamURL(_ urlString: String) async throws {
        let rootURL = storageManager.rootURL
        try await setUpstreamURL(urlString, in: rootURL)
    }
    
    /// Extracts detailed error information from SwiftGitX errors
    private func extractErrorDetails(from error: Error) -> String {
        // Try to get more details from the error
        let errorDescription = error.localizedDescription
        
        // Check if it's a SwiftGitX error and try to get more info
        if let gitXError = error as? SwiftGitXError {
            var details = "SwiftGitXError code \(gitXError.code.rawValue): \(gitXError.localizedDescription)"
            
            // Include operation if available
            if let operation = gitXError.operation {
                details += "\nOperation: \(operation.rawValue)"
            }
            
            // Include category
            details += "\nCategory: \(gitXError.category.rawValue)"
            
            // Include message (if it's not empty)
            let message = gitXError.message
            if !message.isEmpty {
                details += "\nMessage: \(message)"
            }
            
            return details
        }
        
        // Fallback to mirror-based extraction for other error types
        let mirror = Mirror(reflecting: error)
        var details: [String] = [errorDescription]
        
        // Try to extract error code or additional info
        for child in mirror.children {
            if let label = child.label, let value = child.value as? CustomStringConvertible {
                details.append("\(label): \(value)")
            }
        }
        
        // Include the full error description
        let fullError = String(describing: error)
        if fullError != errorDescription {
            details.append("Full error: \(fullError)")
        }
        
        return details.joined(separator: ". ")
    }
}

// MARK: - Errors

enum GitError: LocalizedError {
    case notAGitRepository
    case alreadyAGitRepository
    case commitFailed(String)
    case pushFailed(String)
    case initFailed(String)
    case setUpstreamFailed(String)
    case invalidURL
    
    var errorDescription: String? {
        switch self {
        case .notAGitRepository:
            return "The notes directory is not a git repository"
        case .alreadyAGitRepository:
            return "The notes directory is already a git repository"
        case .commitFailed(let message):
            return "Failed to commit changes: \(message)"
        case .pushFailed(let message):
            return "Failed to push changes: \(message)"
        case .initFailed(let message):
            return "Failed to initialize git repository: \(message)"
        case .setUpstreamFailed(let message):
            return "Failed to set upstream URL: \(message)"
        case .invalidURL:
            return "Invalid URL format"
        }
    }
}
