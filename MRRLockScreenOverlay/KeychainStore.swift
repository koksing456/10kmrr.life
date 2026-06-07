import Foundation
import Security

enum KeychainStore {
    static func stripeAPIKeyExists() -> Bool {
        findStripeAPIKey(in: keychainService) != nil || findStripeAPIKey(in: legacyKeychainService) != nil
    }

    static func readStripeAPIKey() throws -> String {
        if let key = findStripeAPIKey(in: keychainService) {
            return key
        }
        if let legacyKey = findStripeAPIKey(in: legacyKeychainService) {
            try? saveStripeAPIKey(legacyKey)
            return legacyKey
        }
        throw OverlayError.missingAPIKey
    }

    static func saveStripeAPIKey(_ key: String) throws {
        try saveStripeAPIKey(key, service: keychainService)
    }

    static func deleteStripeAPIKey() throws {
        var firstError: NSError?
        for service in [keychainService, legacyKeychainService] {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: keychainAccount
            ]
            let status = SecItemDelete(query as CFDictionary)
            if status != errSecSuccess && status != errSecItemNotFound && firstError == nil {
                firstError = NSError(domain: NSOSStatusErrorDomain, code: Int(status))
            }
        }
        if let firstError {
            throw firstError
        }
    }

    private static func findStripeAPIKey(in service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty
        else {
            return nil
        }
        return key
    }

    private static func saveStripeAPIKey(_ key: String, service: String) throws {
        let data = Data(key.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keychainAccount
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(updateStatus))
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(addStatus))
        }
    }
}
