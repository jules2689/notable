import Foundation

/// Represents different storage location options for notes
enum StorageLocationType: String, Codable {
    case `default` = "default"
    case custom = "custom"
}

/// Manages storage location preferences and provides the appropriate root URL
final class StorageLocationManager: @unchecked Sendable {
    static let shared = StorageLocationManager()
    
    private let fileManager = FileManager.default
    private let storageTypeKey = "storageLocationType"
    private let customPathKey = "customStoragePath"
    private let customBookmarkKey = "customStorageBookmark"
    
    // Track if we're currently accessing the security-scoped resource
    private var isAccessingSecurityScopedResource = false
    private var securityScopedURL: URL?
    
    /// Gets the current storage location type from user defaults
    var storageType: StorageLocationType {
        get {
            if let rawValue = UserDefaults.standard.string(forKey: storageTypeKey) {
                // Migrate old iCloud selection to default
                if rawValue == "iCloud" {
                    // Update stored value to default
                    UserDefaults.standard.set(StorageLocationType.default.rawValue, forKey: storageTypeKey)
                    return .default
                }
                if let type = StorageLocationType(rawValue: rawValue) {
                    return type
                }
            }
            return .default
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: storageTypeKey)
            if newValue != .custom {
                // Clear bookmark when switching away from custom
                clearCustomBookmark()
            }
        }
    }
    
    /// Gets the custom storage path from user defaults (for display purposes)
    var customPath: String? {
        get {
            if let url = resolveCustomURL() {
                return url.path
            }
            return UserDefaults.standard.string(forKey: customPathKey)
        }
    }
    
    /// Gets the root URL for notes based on the selected storage location
    var rootURL: URL {
        switch storageType {
        case .default:
            return Workspace.defaultNotesURL
            
        case .custom:
            if let url = resolveCustomURL() {
                return url
            } else {
                // Fallback to default if no custom path is set
                return Workspace.defaultNotesURL
            }
        }
    }
    
    /// Sets a custom storage location URL and creates a security-scoped bookmark
    func setCustomLocation(_ url: URL) throws {
        // Start accessing the security-scoped resource first (required for bookmark creation)
        let accessGranted = url.startAccessingSecurityScopedResource()
        defer {
            if accessGranted {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        // Create security-scoped bookmark while we have access
        let bookmarkData = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        
        // Store both the bookmark and path (path is for display/fallback)
        UserDefaults.standard.set(bookmarkData, forKey: customBookmarkKey)
        UserDefaults.standard.set(url.path, forKey: customPathKey)
        
        // Set storage type to custom
        storageType = .custom
        
        // Now start accessing using the resolved bookmark URL
        _ = startAccessingSecurityScopedResource()
    }
    
    /// Resolves the custom URL from the stored security-scoped bookmark
    private func resolveCustomURL() -> URL? {
        // Try to resolve from bookmark first
        if let bookmarkData = UserDefaults.standard.data(forKey: customBookmarkKey) {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                if isStale {
                    // Bookmark is stale, try to refresh it
                    if let refreshedBookmark = try? url.bookmarkData(
                        options: [.withSecurityScope],
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    ) {
                        UserDefaults.standard.set(refreshedBookmark, forKey: customBookmarkKey)
                    }
                }
                return url
            }
        }
        
        // Fallback to path if bookmark resolution fails
        if let path = UserDefaults.standard.string(forKey: customPathKey), !path.isEmpty {
            return URL(fileURLWithPath: path)
        }
        
        return nil
    }
    
    /// Starts accessing the security-scoped resource for custom locations
    func startAccessingSecurityScopedResource() -> Bool {
        guard storageType == .custom else { return true }
        
        if isAccessingSecurityScopedResource {
            return true
        }
        
        if let url = resolveCustomURL() {
            let success = url.startAccessingSecurityScopedResource()
            if success {
                isAccessingSecurityScopedResource = true
                securityScopedURL = url
            }
            return success
        }
        
        return false
    }
    
    /// Stops accessing the security-scoped resource
    func stopAccessingSecurityScopedResource() {
        if isAccessingSecurityScopedResource, let url = securityScopedURL {
            url.stopAccessingSecurityScopedResource()
            isAccessingSecurityScopedResource = false
            securityScopedURL = nil
        }
    }
    
    /// Clears the custom bookmark
    private func clearCustomBookmark() {
        stopAccessingSecurityScopedResource()
        UserDefaults.standard.removeObject(forKey: customBookmarkKey)
        UserDefaults.standard.removeObject(forKey: customPathKey)
    }
    
    private init() {
        // Start accessing security-scoped resource on init if using custom location
        if storageType == .custom {
            _ = startAccessingSecurityScopedResource()
        }
    }
    
    deinit {
        stopAccessingSecurityScopedResource()
    }
}

