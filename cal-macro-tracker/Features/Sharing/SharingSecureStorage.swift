import Foundation
import Security

@MainActor
protocol SharingInviteTokenStorage {
    func loadToken() throws -> String?
    func saveToken(_ token: String) throws
    func deleteToken() throws
}

struct SharingKeychainItem {
    let service: String
    let account: String

    func load() throws -> Data? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw SharingIdentityStoreError.keychainFailure(status) }
        guard let data = result as? Data else { throw SharingIdentityStoreError.encodingFailed }
        return data
    }

    func save(_ data: Data) throws {
        var query = baseQuery
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else { throw SharingIdentityStoreError.keychainFailure(status) }
        query[kSecValueData as String] = data
        #if os(iOS)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        #endif
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw SharingIdentityStoreError.keychainFailure(addStatus) }
    }

    func delete() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SharingIdentityStoreError.keychainFailure(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

struct SharingInviteTokenStore: SharingInviteTokenStorage {
    let item: SharingKeychainItem

    init(service: String = "juan-test.cal-macro-tracker.sharing", account: String = "pending-invite") {
        item = SharingKeychainItem(service: service, account: account)
    }

    func loadToken() throws -> String? {
        guard let data = try item.load() else { return nil }
        guard let token = String(data: data, encoding: .utf8) else { throw SharingIdentityStoreError.encodingFailed }
        return token
    }

    func saveToken(_ token: String) throws { try item.save(Data(token.utf8)) }
    func deleteToken() throws { try item.delete() }
}
