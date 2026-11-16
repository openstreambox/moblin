import Foundation
import Security

// This device's static key for the hub: made once at the join, kept in the
// Keychain on this device only (never in backups, never exported).
enum HubKeychain {
    private static let service = "openstreambox.hub"
    private static let account = "device-key"

    private static var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    static func loadDeviceKey() -> HubKeyPair? {
        var item: CFTypeRef?
        var search = query
        search[kSecReturnData as String] = true
        search[kSecMatchLimit as String] = kSecMatchLimitOne
        guard SecItemCopyMatching(search as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else {
            return nil
        }
        return try? HubKeyPair(privateKey: data)
    }

    @discardableResult
    static func saveDeviceKey(_ key: HubKeyPair) -> Bool {
        deleteDeviceKey()
        var add = query
        add[kSecValueData as String] = key.privateKey
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    static func deleteDeviceKey() {
        SecItemDelete(query as CFDictionary)
    }
}
