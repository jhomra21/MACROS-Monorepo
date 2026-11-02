import Combine
import CryptoKit
import Foundation
import SwiftData

@MainActor
@Observable
final class SharingSyncService {
    private let remoteClient: any SharingRemote
    private let credentialCleanup: any SharingCredentialCleanup
    private let localStateStore: SharingLocalStateStore
    private let uploadCoordinator = SharingUploadCoordinator()
    private var dashboardFeed: SharingDashboardFeed {
        SharingDashboardFeed(remote: remoteClient)
    }
    private var accountActions: SharingAccountActions {
        SharingAccountActions(remote: remoteClient)
    }
    private(set) var lastUploadStatus: SharingUploadStatus
    private(set) var lastUploadDate: Date?
    private(set) var dashboard = SharingDashboard(people: [])
    private(set) var dashboardErrorMessage: String?
    private(set) var uploadErrorMessage: String?
    private var isDashboardLoading = false
    var shouldShowDashboardLoading: Bool {
        dashboard.people.isEmpty && isDashboardLoading
    }

    private var lastUploadedSnapshotHash: String?
    private var uploadTask: Task<Void, Error>?
    private var uploadAttemptId: UUID?
    private var uploadRequest: UploadRequest?
    private var uploadDirty = false
    private var identityGeneration = UUID()
    private var authenticatedGeneration: UUID?
    private var personDays: [PersonDayKey: SharingPersonDay] = [:]
    private var profileDeletionTask: Task<Void, Error>?
    private var credentialCleanupTask: Task<Void, Error>?
    private var purchaseDeduplicator = PurchaseSubmissionDeduplicator()
    private var lastUploadContainer: ModelContainer?
    private var pendingScopeSync: (profileId: String, scope: SharingOutgoingScope)?

    private struct UploadRequest {
        let container: ModelContainer
        let date: Date?
        let calendar: Calendar?
    }
    private struct PersonDayKey: Hashable {
        let profileId: String
        let day: String
    }
    private var dashboardSubscriptionDay: CalendarDay?
    private var hasReceivedDashboard = false
    private var dashboardSubscriptionTask: Task<Void, Never>?
    private var dashboardSubscriptionAttemptId: UUID?
    var isDeviceSharingEnabled: Bool {
        localStateStore.isDeviceSharingEnabled && !localStateStore.isCredentialCleanupPending
    }

    convenience init(authService: SharingAuthService) {
        self.init(remoteClient: SharingRemoteClient(authService: authService), credentialCleanup: authService)
    }

    init(
        remoteClient: any SharingRemote,
        credentialCleanup: any SharingCredentialCleanup,
        localStateStore: SharingLocalStateStore? = nil
    ) {
        let localStateStore = localStateStore ?? SharingLocalStateStore()
        self.remoteClient = remoteClient
        self.credentialCleanup = credentialCleanup
        self.localStateStore = localStateStore
        self.lastUploadStatus = localStateStore.lastUploadStatus
        self.lastUploadDate = localStateStore.lastUploadDate
        self.lastUploadedSnapshotHash = localStateStore.lastUploadedSnapshotHash
        if localStateStore.isCredentialCleanupPending { disableLocalSharing() }
    }

    func syncTodayIfConfigured(container: ModelContainer) async {
        guard isDeviceSharingEnabled else { return }

        do {
            try await requestUpload(
                UploadRequest(container: container, date: nil, calendar: nil)
            ).value
        } catch {
            // The drain owns error/status updates, including stale-identity suppression.
        }
    }

    func syncAfterDailyTotalsChange(container: ModelContainer) {
        guard isDeviceSharingEnabled else { return }
        _ = requestUpload(UploadRequest(container: container, date: nil, calendar: nil))
    }

    func enableSharing(displayName: String, container: ModelContainer) async throws {
        if let profileDeletionTask { try await profileDeletionTask.value }
        try await finishPendingCredentialCleanup()
        let displayName = normalizedDisplayName(displayName)
        let generation = identityGeneration
        try await remoteClient.authenticate(displayName: displayName)
        try checkIdentity(generation)
        try await updateDisplayNameAfterAuthentication(displayName)
        try checkIdentity(generation)
        localStateStore.displayName = displayName
        localStateStore.isDeviceSharingEnabled = true
        try await uploadTodaySnapshot(container: container)
    }

    func updateDisplayName(_ displayName: String) async throws {
        let displayName = normalizedDisplayName(displayName)
        let generation = identityGeneration
        try await authenticateForOperation(displayName: displayName)
        try await updateDisplayNameAfterAuthentication(displayName)
        try checkIdentity(generation)
        localStateStore.displayName = displayName
    }

    private func updateDisplayNameAfterAuthentication(_ displayName: String) async throws {
        try await accountActions.updateDisplayName(displayName)
    }

    func uploadTodaySnapshot(
        container: ModelContainer,
        date: Date = .now,
        calendar: Calendar = .current
    ) async throws {
        guard isDeviceSharingEnabled else { return }
        try await requestUpload(
            UploadRequest(container: container, date: date, calendar: calendar)
        ).value
    }

    private func requestUpload(_ request: UploadRequest) -> Task<Void, Error> {
        lastUploadContainer = request.container
        uploadRequest = request
        uploadDirty = true
        if let uploadTask { return uploadTask }
        let attemptId = UUID()
        let generation = identityGeneration
        uploadAttemptId = attemptId
        let task = Task { @MainActor in
            defer {
                if self.uploadAttemptId == attemptId {
                    self.uploadTask = nil
                    self.uploadAttemptId = nil
                    self.uploadRequest = nil
                }
            }
            do {
                try await self.drainUpload(generation: generation)
            } catch {
                if self.identityGeneration == generation, !Task.isCancelled {
                    self.uploadErrorMessage = error.localizedDescription
                    self.setLastUploadStatus(.failed)
                }
                throw error
            }
        }
        uploadTask = task
        return task
    }

    private func drainUpload(generation: UUID) async throws {
        var authenticated = false
        // Every successful write reloads local state. Only new changes drive another
        // iteration; errors settle and require an explicit request to retry.
        while uploadDirty, let request = uploadRequest {
            try checkIdentity(generation)
            guard isDeviceSharingEnabled else { throw CancellationError() }
            uploadDirty = false
            let calendar = request.calendar ?? .current
            let date = request.date ?? .now
            let shouldShareFoods = dashboard.people.contains {
                !$0.connectionPaused && $0.outgoingScope == .macrosAndFoods
            }
            let payload = try uploadCoordinator.payload(
                container: request.container,
                date: date,
                calendar: calendar,
                includeFoods: shouldShareFoods
            )
            let hash = payload.stableHash
            guard hash != lastUploadedSnapshotHash else {
                uploadErrorMessage = nil
                if lastUploadStatus == .failed { setLastUploadStatus(.succeeded) }
                return
            }
            if !authenticated {
                try await remoteClient.authenticate(displayName: storedDisplayName)
                try checkIdentity(generation)
                authenticated = true
                // Re-read after authentication rather than uploading its old snapshot.
                uploadDirty = true
                continue
            }
            setLastUploadStatus(.uploading)
            try await remoteClient.upsertDailySnapshot(payload)
            try checkIdentity(generation)
            // Cancellation cannot undo a committed remote write. It only prevents
            // acknowledgment or new writes under a disabled/replaced identity.
            lastUploadedSnapshotHash = hash
            localStateStore.lastUploadedSnapshotHash = hash
            setLastUploadDate(.now)
            uploadErrorMessage = nil
            setLastUploadStatus(.succeeded)
            // Also reload when no caller marked dirty: edits may have happened during await.
            uploadDirty = true
        }
    }

    private func checkIdentity(_ generation: UUID) throws {
        try Task.checkCancellation()
        guard identityGeneration == generation else { throw CancellationError() }
    }

    private func authenticateForOperation(displayName: String? = nil) async throws {
        guard profileDeletionTask == nil else { throw SharingOperationError.deletionInProgress }
        guard !localStateStore.isCredentialCleanupPending else {
            throw SharingOperationError.cleanupPending
        }
        let generation = identityGeneration
        // The Convex client refreshes its own token, so one exchange per identity is enough.
        // Each exchange is a network round trip to the auth worker.
        if displayName == nil, authenticatedGeneration == generation { return }
        try await remoteClient.authenticate(displayName: displayName ?? storedDisplayName)
        try checkIdentity(generation)
        authenticatedGeneration = generation
    }

    func startDashboardSubscription(for day: CalendarDay) {
        guard isDeviceSharingEnabled else {
            if dashboardSubscriptionTask != nil
                || dashboardSubscriptionDay != nil
                || dashboardSubscriptionAttemptId != nil
                || dashboardErrorMessage != nil
                || isDashboardLoading
                || !dashboard.people.isEmpty
            {
                stopDashboardSubscription(clearDashboard: true)
            }
            return
        }
        guard dashboardSubscriptionDay != day || dashboardSubscriptionTask == nil else { return }

        let isChangingDay = dashboardSubscriptionDay != nil && dashboardSubscriptionDay != day
        stopDashboardSubscription(clearDashboard: isChangingDay)
        dashboardSubscriptionDay = day
        isDashboardLoading = dashboard.people.isEmpty
        let attemptId = UUID()
        let displayName = storedDisplayName
        let generation = identityGeneration
        dashboardSubscriptionAttemptId = attemptId
        let remoteClient = remoteClient
        let dashboardFeed = dashboardFeed
        dashboardSubscriptionTask = Task { @MainActor [weak self, remoteClient, dashboardFeed] in
            defer { self?.finishDashboardSubscription(attemptId: attemptId) }

            do {
                try await remoteClient.authenticate(displayName: displayName)
                guard !Task.isCancelled, self?.isCurrentDashboardSubscriptionAttempt(attemptId) == true else { return }
                self?.authenticatedGeneration = generation
                let values = dashboardFeed.dashboard(for: day).values
                for try await dashboard in values {
                    guard !Task.isCancelled else { return }
                    self?.receiveDashboard(dashboard, attemptId: attemptId)
                }
            } catch is CancellationError {
            } catch {
                guard !Task.isCancelled else { return }
                self?.failDashboardSubscription(error, attemptId: attemptId)
            }
        }
    }

    private func isCurrentDashboardSubscriptionAttempt(_ attemptId: UUID) -> Bool {
        dashboardSubscriptionAttemptId == attemptId
    }

    private func receiveDashboard(_ dashboard: SharingDashboard, attemptId: UUID) {
        guard isCurrentDashboardSubscriptionAttempt(attemptId) else { return }
        let previouslySharedFoods = self.dashboard.people.contains {
            !$0.connectionPaused && $0.outgoingScope == .macrosAndFoods
        }
        isDashboardLoading = false
        let sharesFoodsNow = dashboard.people.contains {
            !$0.connectionPaused && $0.outgoingScope == .macrosAndFoods
        }
        let eligibilityEnded =
            previouslySharedFoods && !sharesFoodsNow
            || (!hasReceivedDashboard && !sharesFoodsNow && lastUploadedSnapshotHash != nil)
        hasReceivedDashboard = true
        if eligibilityEnded {
            lastUploadedSnapshotHash = nil
            localStateStore.lastUploadedSnapshotHash = nil
        }
        let scopeSyncReady =
            pendingScopeSync.map { pending in
                dashboard.people.contains { $0.profileId == pending.profileId && $0.outgoingScope == pending.scope }
            } ?? false
        if scopeSyncReady { pendingScopeSync = nil }
        if self.dashboard != dashboard { self.dashboard = dashboard }
        prunePersonDays(to: dashboard)
        if sharesFoodsNow != previouslySharedFoods || eligibilityEnded || scopeSyncReady, let lastUploadContainer {
            _ = requestUpload(UploadRequest(container: lastUploadContainer, date: nil, calendar: nil))
        }
        if dashboardErrorMessage != nil { dashboardErrorMessage = nil }
    }

    private func failDashboardSubscription(_ error: Error, attemptId: UUID) {
        guard isCurrentDashboardSubscriptionAttempt(attemptId) else { return }
        isDashboardLoading = false
        dashboardErrorMessage = error.localizedDescription
    }

    private func finishDashboardSubscription(attemptId: UUID) {
        guard dashboardSubscriptionAttemptId == attemptId else { return }
        isDashboardLoading = false
        dashboardSubscriptionTask = nil
        dashboardSubscriptionAttemptId = nil
    }

    func stopDashboardSubscription(clearDashboard: Bool) {
        dashboardSubscriptionTask?.cancel()
        dashboardSubscriptionTask = nil
        dashboardSubscriptionDay = nil
        dashboardSubscriptionAttemptId = nil
        dashboardErrorMessage = nil
        isDashboardLoading = false
        if clearDashboard {
            dashboard = SharingDashboard(people: [])
            hasReceivedDashboard = false
            personDays = [:]
        }
    }

    /// Last known shared day for a person, shown while the live subscription reconnects.
    func cachedPersonDay(profileId: String, day: CalendarDay) -> SharingPersonDay? {
        personDays[PersonDayKey(profileId: profileId, day: day.sharingDayKey)]
    }

    func cachePersonDay(_ value: SharingPersonDay, profileId: String, day: CalendarDay) {
        guard isDeviceSharingEnabled else { return }
        let key = PersonDayKey(profileId: profileId, day: day.sharingDayKey)
        let cached = value.visibility == .shared ? value : nil
        if personDays[key] != cached { personDays[key] = cached }
    }

    /// Keeps only days the dashboard still says are visible, and drops foods once the person stops sharing them.
    private func prunePersonDays(to dashboard: SharingDashboard) {
        let pruned = personDays.compactMap { key, value -> (PersonDayKey, SharingPersonDay)? in
            guard let person = dashboard.people.first(where: { $0.profileId == key.profileId }),
                person.incomingActive, !person.connectionPaused
            else { return nil }
            return (key, person.foodsShared ? value : SharingPersonDay(snapshot: value.snapshot, foods: []))
        }
        let result = Dictionary(uniqueKeysWithValues: pruned)
        if personDays != result { personDays = result }
    }

    func pendingInvite() throws -> SharingInvite? {
        guard !localStateStore.isCredentialCleanupPending else { return nil }
        return try localStateStore.pendingInvite()
    }

    func createInvite() async throws -> SharingInvite {
        if let profileDeletionTask { try await profileDeletionTask.value }
        try await finishPendingCredentialCleanup()
        let generation = identityGeneration
        try await remoteClient.authenticate(displayName: storedDisplayName)
        try checkIdentity(generation)
        let token = try SharingRandomToken.make()
        let tokenHash = sha256Hex(token)
        let response = try await accountActions.createInvite(tokenHash: tokenHash)
        try checkIdentity(generation)
        let invite = localStateStore.makeInvite(inviteId: response.inviteId, token: token, expiresAt: response.expiresAt)
        try localStateStore.savePendingInvite(invite)
        return invite
    }

    func revokeInvite(_ invite: SharingInvite) async throws {
        let generation = identityGeneration
        try await authenticateForOperation()
        try await accountActions.revokeInvite(id: invite.inviteId)
        try checkIdentity(generation)
        try localStateStore.clearPendingInvite()
    }

    func acceptInvite(input: String, ownerDay: CalendarDay) async throws {
        try await authenticateForOperation()
        try await accountActions.acceptInvite(tokenHash: sha256Hex(inviteToken(from: input)), ownerDay: ownerDay)
    }

    func setOutgoingScope(
        to profileId: String,
        scope: SharingOutgoingScope,
        ownerDay: CalendarDay,
        container: ModelContainer? = nil
    ) async throws {
        let generation = identityGeneration
        try await authenticateForOperation()
        try await accountActions.setOutgoingScope(profileId: profileId, scope: scope, ownerDay: ownerDay)
        try checkIdentity(generation)
        pendingScopeSync = (profileId, scope)
        if dashboard.people.contains(where: { $0.profileId == profileId && $0.outgoingScope == scope }),
            let uploadContainer = container ?? lastUploadContainer
        {
            pendingScopeSync = nil
            _ = requestUpload(UploadRequest(container: uploadContainer, date: nil, calendar: nil))
        }
    }

    func setOutgoingSharing(to profileId: String, enabled: Bool, ownerDay: CalendarDay) async throws {
        try await setOutgoingScope(to: profileId, scope: enabled ? .macros : .off, ownerDay: ownerDay)
    }

    func submitPurchase(
        signedTransaction: String,
        signedRenewalInfo: String?,
        transactionID: UInt64,
        expiresAt: Date?
    ) async throws {
        guard isDeviceSharingEnabled,
            purchaseDeduplicator.insert(
                transactionID: transactionID,
                expiresAt: expiresAt,
                renewalInfo: signedRenewalInfo
            )
        else { return }
        let generation = identityGeneration
        do {
            try await authenticateForOperation()
            try checkIdentity(generation)
            try await accountActions.submitPurchase(transaction: signedTransaction, renewalInfo: signedRenewalInfo)
            try checkIdentity(generation)
        } catch {
            if identityGeneration == generation {
                purchaseDeduplicator.remove(
                    transactionID: transactionID,
                    expiresAt: expiresAt,
                    renewalInfo: signedRenewalInfo
                )
            }
            throw error
        }
    }

    func personDayUpdates(profileId: String, day: CalendarDay) async throws -> AnyPublisher<SharingPersonDay, Error> {
        try await authenticateForOperation()
        return dashboardFeed.personDay(profileId: profileId, day: day)
    }

    func stopSharingMyData(ownerDay: CalendarDay) async throws {
        try await authenticateForOperation()
        try await accountActions.stopSharing(ownerDay: ownerDay)
    }

    func disableSharingOnDevice(ownerDay: CalendarDay) async throws {
        let generation = identityGeneration
        try await stopSharingMyData(ownerDay: ownerDay)
        try checkIdentity(generation)
        disableLocalSharing()
    }

    func removePerson(_ profileId: String, ownerDay: CalendarDay) async throws {
        try await authenticateForOperation()
        try await accountActions.removePerson(profileId: profileId, ownerDay: ownerDay)
        personDays = personDays.filter { $0.key.profileId != profileId }
    }

    func deleteSharingProfile() async throws {
        if let profileDeletionTask { return try await profileDeletionTask.value }
        let task = Task { @MainActor in
            defer { self.profileDeletionTask = nil }
            if !self.localStateStore.isCredentialCleanupPending {
                try await self.remoteClient.authenticate(displayName: self.storedDisplayName)
                try await self.accountActions.deleteProfile()
                self.localStateStore.isCredentialCleanupPending = true
                self.disableLocalSharing()
            }
            do {
                try await self.finishPendingCredentialCleanup()
            } catch {
                throw SharingOperationError.cleanupPending
            }
        }
        profileDeletionTask = task
        try await task.value
    }

    private func disableLocalSharing() {
        localStateStore.isDeviceSharingEnabled = false
        identityGeneration = UUID()
        purchaseDeduplicator = PurchaseSubmissionDeduplicator()
        pendingScopeSync = nil
        uploadTask?.cancel()
        uploadTask = nil
        uploadAttemptId = nil
        uploadRequest = nil
        uploadDirty = false
        uploadErrorMessage = nil
        stopDashboardSubscription(clearDashboard: true)
        clearUploadMetadata()
    }

    private func finishPendingCredentialCleanup() async throws {
        if let credentialCleanupTask { return try await credentialCleanupTask.value }
        guard localStateStore.isCredentialCleanupPending else { return }
        let task = Task { @MainActor in
            defer { self.credentialCleanupTask = nil }
            // Keep the nonsecret marker until both credential stores are cleared.
            do {
                try await self.credentialCleanup.clearLocalIdentity()
            } catch {
                try? self.localStateStore.clearPendingInvite()
                throw error
            }
            try self.localStateStore.clearPendingInvite()
            self.localStateStore.isCredentialCleanupPending = false
        }
        credentialCleanupTask = task
        try await task.value
    }

    private var storedDisplayName: String {
        localStateStore.displayName
    }

    private func normalizedDisplayName(_ displayName: String) -> String {
        localStateStore.normalizedDisplayName(displayName)
    }

    private func inviteToken(from input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme != nil else {
            return trimmed
        }
        return url.pathComponents.last ?? trimmed
    }

    private func sha256Hex(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func setLastUploadStatus(_ status: SharingUploadStatus) {
        lastUploadStatus = status
        localStateStore.lastUploadStatus = status
    }

    private func setLastUploadDate(_ date: Date) {
        lastUploadDate = date
        localStateStore.lastUploadDate = date
    }

    private func clearUploadMetadata() {
        lastUploadedSnapshotHash = nil
        lastUploadDate = nil
        lastUploadStatus = .idle
        localStateStore.clearUploadMetadata()
    }
}

private enum SharingOperationError: LocalizedError {
    case cleanupPending
    case deletionInProgress

    var errorDescription: String? {
        switch self {
        case .cleanupPending:
            "Your cloud sharing profile was deleted, but device credential cleanup is unfinished. Retry Delete Sharing Profile to finish. Local food and logs are unchanged."
        case .deletionInProgress:
            "Sharing profile deletion is in progress. Wait for it to finish before changing sharing settings."
        }
    }
}
