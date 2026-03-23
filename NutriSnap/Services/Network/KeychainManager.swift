import Foundation
import Security

/// Wraps the Security framework for storing, retrieving, and deleting the app's JWT.
/// The Keychain is the only acceptable location for credentials — never UserDefaults.
final class KeychainManager {
    static let shared = KeychainManager()

    private let service = Bundle.main.bundleIdentifier ?? "com.nutrisnap.app"
    private let tokenKey = "auth_jwt"

    private init() {}

    // MARK: - Public Interface

    func saveToken(_ token: String) throws {
        guard let data = token.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: tokenKey,
            kSecValueData: data
        ]
        // Delete any existing item before inserting the new one.
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    func retrieveToken() -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: tokenKey,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deleteToken() {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: tokenKey
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Errors

    enum KeychainError: LocalizedError {
        case encodingFailed
        case saveFailed(OSStatus)

        var errorDescription: String? {
            switch self {
            case .encodingFailed: return "Failed to encode token for Keychain storage."
            case .saveFailed(let status): return "Keychain save failed with status: \(status)."
            }
        }
    }
}
