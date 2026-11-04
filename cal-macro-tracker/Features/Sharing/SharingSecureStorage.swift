import Foundation

@MainActor
protocol SharingInviteTokenStorage {
    func loadToken() throws -> String?
    func saveToken(_ token: String) throws
    func deleteToken() throws
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
