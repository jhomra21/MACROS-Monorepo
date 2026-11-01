import Foundation

@MainActor
struct SharingAccountActions {
    private let remote: any SharingRemote

    init(remote: any SharingRemote) {
        self.remote = remote
    }

    func updateDisplayName(_ name: String) async throws {
        try await remote.updateDisplayName(name)
    }

    func createInvite(tokenHash: String) async throws -> (inviteId: String, expiresAt: Date) {
        try await remote.createInvite(tokenHash: tokenHash)
    }

    func revokeInvite(id: String) async throws {
        try await remote.revokeInvite(id: id)
    }

    func acceptInvite(tokenHash: String, ownerDay: CalendarDay) async throws {
        try await remote.acceptInvite(tokenHash: tokenHash, ownerDay: ownerDay)
    }

    func setOutgoingScope(profileId: String, scope: SharingOutgoingScope, ownerDay: CalendarDay) async throws {
        try await remote.setOutgoingScope(to: profileId, scope: scope, ownerDay: ownerDay)
    }

    func stopSharing(ownerDay: CalendarDay) async throws {
        try await remote.stopSharingMyData(ownerDay: ownerDay)
    }

    func removePerson(profileId: String, ownerDay: CalendarDay) async throws {
        try await remote.removePerson(profileId, ownerDay: ownerDay)
    }

    func deleteProfile() async throws {
        try await remote.deleteSharingProfile()
    }

    func submitPurchase(transaction: String, renewalInfo: String?) async throws {
        try await remote.submitPurchase(signedTransaction: transaction, signedRenewalInfo: renewalInfo)
    }
}
