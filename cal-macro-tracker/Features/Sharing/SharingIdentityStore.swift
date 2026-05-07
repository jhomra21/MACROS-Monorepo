import Foundation

struct SharingIdentity: Codable, Equatable {
    let profileKey: String
    let profileSecret: String
}

enum SharingIdentityStoreError: Error {
    case encodingFailed
    case keychainFailure(OSStatus)
    case randomGenerationFailed(OSStatus)
}

struct SharingIdentityStore {
    private let service = "juan-test.cal-macro-tracker.sharing"
    private let account = "profile-identity"

    func load() throws -> SharingIdentity? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw SharingIdentityStoreError.keychainFailure(status)
        }
        guard let data = result as? Data else {
            throw SharingIdentityStoreError.encodingFailed
        }

        return try JSONDecoder().decode(SharingIdentity.self, from: data)
    }

    func loadOrCreate() throws -> SharingIdentity {
        if let identity = try load() {
            return identity
        }

        let identity = SharingIdentity(profileKey: try SharingRandomToken.make(), profileSecret: try SharingRandomToken.make())
        try save(identity)
        return identity
    }

    func save(_ identity: SharingIdentity) throws {
        let data = try JSONEncoder().encode(identity)
        var query = baseQuery

        let attributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw SharingIdentityStoreError.keychainFailure(updateStatus)
        }

        query[kSecValueData as String] = data
        #if os(iOS)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        #endif

        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw SharingIdentityStoreError.keychainFailure(addStatus)
        }
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
