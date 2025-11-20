import Foundation
import Security

/// Helper for secure keychain storage
final class KeychainHelper: @unchecked Sendable {
    static let shared = KeychainHelper()
    
    private let service = "com.notable.Notable"
    
    private init() {}
    
    /// Sets a password in the keychain
    /// Returns true if successful, false otherwise
    @discardableResult
    func setPassword(_ password: String, for key: String) -> Bool {
        let data = password.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete existing item if it exists
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Gets a password from the keychain
    func getPassword(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return password
    }
    
    /// Deletes a password from the keychain
    func deletePassword(for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

