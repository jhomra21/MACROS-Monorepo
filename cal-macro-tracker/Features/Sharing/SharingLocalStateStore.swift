import Foundation

struct SharingLocalStateStore {
    var isDeviceSharingEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: AppStorageKeys.isSharingDeviceEnabled) }
        nonmutating set { UserDefaults.standard.set(newValue, forKey: AppStorageKeys.isSharingDeviceEnabled) }
    }

    var displayName: String {
        get { normalizedDisplayName(UserDefaults.standard.string(forKey: AppStorageKeys.sharingDisplayName) ?? "Me") }
        nonmutating set { UserDefaults.standard.set(normalizedDisplayName(newValue), forKey: AppStorageKeys.sharingDisplayName) }
    }

    var lastUploadStatus: SharingUploadStatus {
        get {
            UserDefaults.standard.string(forKey: AppStorageKeys.sharingLastUploadStatus)
                .flatMap(SharingUploadStatus.init(rawValue:)) ?? .idle
        }
        nonmutating set { UserDefaults.standard.set(newValue.rawValue, forKey: AppStorageKeys.sharingLastUploadStatus) }
    }

    var lastUploadDate: Date? {
        get {
            let timeInterval = UserDefaults.standard.double(forKey: AppStorageKeys.sharingLastUploadDate)
            return timeInterval > 0 ? Date(timeIntervalSince1970: timeInterval) : nil
        }
        nonmutating set {
            if let newValue {
                UserDefaults.standard.set(newValue.timeIntervalSince1970, forKey: AppStorageKeys.sharingLastUploadDate)
            } else {
                UserDefaults.standard.removeObject(forKey: AppStorageKeys.sharingLastUploadDate)
            }
        }
    }

    var lastUploadedSnapshotHash: String? {
        get { UserDefaults.standard.string(forKey: AppStorageKeys.sharingLastUploadedSnapshotHash) }
        nonmutating set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: AppStorageKeys.sharingLastUploadedSnapshotHash)
            } else {
                UserDefaults.standard.removeObject(forKey: AppStorageKeys.sharingLastUploadedSnapshotHash)
            }
        }
    }

    func pendingInvite() -> SharingInvite? {
        let defaults = UserDefaults.standard
        guard
            let inviteId = defaults.string(forKey: AppStorageKeys.sharingPendingInviteId),
            let token = defaults.string(forKey: AppStorageKeys.sharingPendingInviteToken)
        else {
            return nil
        }

        let expiresAt = Date(timeIntervalSince1970: defaults.double(forKey: AppStorageKeys.sharingPendingInviteExpiresAt))
        guard expiresAt > .now else {
            clearPendingInvite()
            return nil
        }

        return makeInvite(inviteId: inviteId, token: token, expiresAt: expiresAt)
    }

    func savePendingInvite(_ invite: SharingInvite) {
        let defaults = UserDefaults.standard
        defaults.set(invite.inviteId, forKey: AppStorageKeys.sharingPendingInviteId)
        defaults.set(invite.token, forKey: AppStorageKeys.sharingPendingInviteToken)
        defaults.set(invite.expiresAt.timeIntervalSince1970, forKey: AppStorageKeys.sharingPendingInviteExpiresAt)
    }

    func clearPendingInvite() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: AppStorageKeys.sharingPendingInviteId)
        defaults.removeObject(forKey: AppStorageKeys.sharingPendingInviteToken)
        defaults.removeObject(forKey: AppStorageKeys.sharingPendingInviteExpiresAt)
    }

    func clearUploadMetadata() {
        lastUploadedSnapshotHash = nil
        lastUploadDate = nil
        lastUploadStatus = .idle
    }

    func makeInvite(inviteId: String, token: String, expiresAt: Date) -> SharingInvite {
        SharingInvite(
            inviteId: inviteId,
            token: token,
            url: SharingConfiguration.authBaseURL.appending(path: "invite/\(token)"),
            appURL: SharingConfiguration.inviteAppURL(token: token),
            expiresAt: expiresAt
        )
    }

    func normalizedDisplayName(_ displayName: String) -> String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Me" : String(trimmed.prefix(40))
    }
}
