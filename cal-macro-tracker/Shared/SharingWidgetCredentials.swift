import Foundation
import Security

nonisolated struct SharingIdentity: Codable, Equatable, Sendable {
    let profileKey: String
    let profileSecret: String
}

/// The payload type is SDK-free; its Keychain item belongs only to the extension.
nonisolated struct SharedWidgetTokenCache: Codable, Sendable {
    let token: String
    let expiresAt: Double
    let profileKey: String
    let deploymentURL: String
    let generation: UUID

    func isUsable(profileKey: String, generation: UUID, now: Date = .now) -> Bool {
        !token.isEmpty && expiresAt.isFinite
            && expiresAt > now.addingTimeInterval(300).timeIntervalSince1970 * 1000
            && self.profileKey == profileKey && self.generation == generation
            && deploymentURL == SharedAppConfiguration.convexDeploymentURL
    }
}

nonisolated enum SharingIdentityStoreError: Error {
    case encodingFailed
    case keychainFailure(OSStatus)
    case randomGenerationFailed(OSStatus)
}

nonisolated struct SharingKeychainItem: Sendable {
    let service: String
    let account: String
    var accessGroup: String? = nil

    static let identity = SharingKeychainItem(
        service: "juan-test.cal-macro-tracker.sharing",
        account: "profile-identity",
        accessGroup: SharedAppConfiguration.appGroupIdentifier
    )

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
        if let accessGroup { query[kSecAttrAccessGroup as String] = accessGroup }
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

    /// Retry at token exchange. Verify the group copy before deleting specifically identified legacy copies.
    func migrateToAccessGroup() throws {
        #if os(iOS)
        guard let accessGroup else { return }
        let legacy = try matchingItems().filter { $0[kSecAttrAccessGroup as String] as? String != accessGroup }
        guard let original = legacy.first else { return }
        guard let data = original[kSecValueData as String] as? Data else {
            throw SharingIdentityStoreError.encodingFailed
        }
        var addition = baseQuery
        addition[kSecAttrAccessGroup as String] = accessGroup
        addition[kSecValueData as String] = data
        addition[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(addition as CFDictionary, nil)
        guard addStatus == errSecSuccess || addStatus == errSecDuplicateItem else {
            throw SharingIdentityStoreError.keychainFailure(addStatus)
        }
        if addStatus == errSecDuplicateItem {
            // The legacy build's bytes win. Unscoped updates also keep both copies in sync.
            let update = SecItemUpdate(baseQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            guard update == errSecSuccess else { throw SharingIdentityStoreError.keychainFailure(update) }
        }
        let group = try matchingItems().first { $0[kSecAttrAccessGroup as String] as? String == accessGroup }
        guard group?[kSecValueData as String] as? Data == data else {
            throw SharingIdentityStoreError.encodingFailed
        }
        for item in legacy {
            guard let reference = item[kSecValuePersistentRef as String] as? Data else {
                throw SharingIdentityStoreError.encodingFailed
            }
            let deletion = SecItemDelete([kSecValuePersistentRef as String: reference] as CFDictionary)
            guard deletion == errSecSuccess || deletion == errSecItemNotFound else {
                throw SharingIdentityStoreError.keychainFailure(deletion)
            }
        }
        #endif
    }

    private func matchingItems() throws -> [[String: Any]] {
        var query = baseQuery
        query[kSecReturnAttributes as String] = true
        query[kSecReturnData as String] = true
        query[kSecReturnPersistentRef as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitAll
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess else { throw SharingIdentityStoreError.keychainFailure(status) }
        guard let items = result as? [[String: Any]] else { throw SharingIdentityStoreError.encodingFailed }
        return items
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
