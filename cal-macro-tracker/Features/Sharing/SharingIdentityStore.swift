import Foundation

struct SharingIdentityStore {
    private let item: SharingKeychainItem

    init(item: SharingKeychainItem = .identity) {
        self.item = item
    }

    func migrateToAccessGroup() throws { try item.migrateToAccessGroup() }

    func load() throws -> SharingIdentity? {
        guard let data = try item.load() else { return nil }
        return try JSONDecoder().decode(SharingIdentity.self, from: data)
    }

    func loadOrCreate() throws -> SharingIdentity {
        if let identity = try load() { return identity }
        let identity = SharingIdentity(profileKey: try SharingRandomToken.make(), profileSecret: try SharingRandomToken.make())
        try save(identity)
        return identity
    }

    func save(_ identity: SharingIdentity) throws {
        try item.save(JSONEncoder().encode(identity))
    }

    func delete() throws { try item.delete() }
}
