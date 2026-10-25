import Foundation

struct SharingLocalStateStore {
    let defaults: UserDefaults
    let tokenStore: any SharingInviteTokenStorage

    init(defaults: UserDefaults = .standard, tokenStore: (any SharingInviteTokenStorage)? = nil) {
        self.defaults = defaults
        self.tokenStore = tokenStore ?? SharingInviteTokenStore()
    }
    var isDeviceSharingEnabled: Bool {
        get { defaults.bool(forKey: AppStorageKeys.isSharingDeviceEnabled) }
        nonmutating set { defaults.set(newValue, forKey: AppStorageKeys.isSharingDeviceEnabled) }
    }

    var displayName: String {
        get { normalizedDisplayName(defaults.string(forKey: AppStorageKeys.sharingDisplayName) ?? "Me") }
        nonmutating set { defaults.set(normalizedDisplayName(newValue), forKey: AppStorageKeys.sharingDisplayName) }
    }

    var lastUploadStatus: SharingUploadStatus {
        get {
            defaults.string(forKey: AppStorageKeys.sharingLastUploadStatus)
                .flatMap(SharingUploadStatus.init(rawValue:)) ?? .idle
        }
        nonmutating set { defaults.set(newValue.rawValue, forKey: AppStorageKeys.sharingLastUploadStatus) }
    }

    var lastUploadDate: Date? {
        get {
            let timeInterval = defaults.double(forKey: AppStorageKeys.sharingLastUploadDate)
            return timeInterval > 0 ? Date(timeIntervalSince1970: timeInterval) : nil
        }
        nonmutating set {
            if let newValue {
                defaults.set(newValue.timeIntervalSince1970, forKey: AppStorageKeys.sharingLastUploadDate)
            } else {
                defaults.removeObject(forKey: AppStorageKeys.sharingLastUploadDate)
            }
        }
    }

    var lastUploadedSnapshotHash: String? {
        get { defaults.string(forKey: AppStorageKeys.sharingLastUploadedSnapshotHash) }
        nonmutating set {
            if let newValue {
                defaults.set(newValue, forKey: AppStorageKeys.sharingLastUploadedSnapshotHash)
            } else {
                defaults.removeObject(forKey: AppStorageKeys.sharingLastUploadedSnapshotHash)
            }
        }
    }

    var isCredentialCleanupPending: Bool {
        get { defaults.bool(forKey: "sharingCredentialCleanupPending") }
        nonmutating set { defaults.set(newValue, forKey: "sharingCredentialCleanupPending") }
    }

    var isInviteCleanupPending: Bool {
        get { defaults.bool(forKey: "sharingInviteCleanupPending") }
        nonmutating set { defaults.set(newValue, forKey: "sharingInviteCleanupPending") }
    }

    func pendingInvite() throws -> SharingInvite? {
        guard !isCredentialCleanupPending else { return nil }
        if isInviteCleanupPending {
            try clearPendingInvite()
            return nil
        }
        guard
            let inviteId = defaults.string(forKey: AppStorageKeys.sharingPendingInviteId)
        else {
            return nil
        }

        let expiresAt = Date(timeIntervalSince1970: defaults.double(forKey: AppStorageKeys.sharingPendingInviteExpiresAt))
        guard expiresAt > .now else {
            try clearPendingInvite()
            return nil
        }

        let token: String
        if let secureToken = try tokenStore.loadToken() {
            token = secureToken
        } else if let legacyToken = defaults.string(forKey: AppStorageKeys.sharingPendingInviteToken) {
            try tokenStore.saveToken(legacyToken)
            token = legacyToken
        } else {
            return nil
        }
        defaults.removeObject(forKey: AppStorageKeys.sharingPendingInviteToken)
        return makeInvite(inviteId: inviteId, token: token, expiresAt: expiresAt)
    }

    func savePendingInvite(_ invite: SharingInvite) throws {
        try tokenStore.saveToken(invite.token)
        defaults.set(invite.inviteId, forKey: AppStorageKeys.sharingPendingInviteId)
        defaults.removeObject(forKey: AppStorageKeys.sharingPendingInviteToken)
        defaults.set(invite.expiresAt.timeIntervalSince1970, forKey: AppStorageKeys.sharingPendingInviteExpiresAt)
        isInviteCleanupPending = false
    }

    func clearPendingInvite() throws {
        isInviteCleanupPending = true
        defaults.removeObject(forKey: AppStorageKeys.sharingPendingInviteId)
        defaults.removeObject(forKey: AppStorageKeys.sharingPendingInviteToken)
        defaults.removeObject(forKey: AppStorageKeys.sharingPendingInviteExpiresAt)
        try tokenStore.deleteToken()
        isInviteCleanupPending = false
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
