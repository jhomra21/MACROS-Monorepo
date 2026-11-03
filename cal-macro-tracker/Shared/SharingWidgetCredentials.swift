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

    /// App launch only. Verify the group copy before deleting the specifically identified legacy copy.
    func migrateToAccessGroup() throws {
        #if os(iOS)
        guard let accessGroup else { return }
        var query = baseQuery
        query[kSecReturnAttributes as String] = true
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return }
        guard status == errSecSuccess else { throw SharingIdentityStoreError.keychainFailure(status) }
        guard let attributes = result as? [String: Any],
            let oldGroup = attributes[kSecAttrAccessGroup as String] as? String,
            let data = attributes[kSecValueData as String] as? Data
        else { throw SharingIdentityStoreError.encodingFailed }
        guard oldGroup != accessGroup else { return }
        var scoped = baseQuery
        scoped[kSecAttrAccessGroup as String] = accessGroup
        var addition = scoped
        addition[kSecValueData as String] = data
        addition[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(addition as CFDictionary, nil)
        guard addStatus == errSecSuccess || addStatus == errSecDuplicateItem else {
            throw SharingIdentityStoreError.keychainFailure(addStatus)
        }
        scoped[kSecReturnData as String] = true
        let verification = SecItemCopyMatching(scoped as CFDictionary, &result)
        guard verification == errSecSuccess else { throw SharingIdentityStoreError.keychainFailure(verification) }
        guard result as? Data == data else { throw SharingIdentityStoreError.encodingFailed }
        var legacy = baseQuery
        legacy[kSecAttrAccessGroup as String] = oldGroup
        let deletion = SecItemDelete(legacy as CFDictionary)
        guard deletion == errSecSuccess || deletion == errSecItemNotFound else {
            throw SharingIdentityStoreError.keychainFailure(deletion)
        }
        #endif
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
