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
    private var profileDeletionTask: Task<Void, Error>?
    private var credentialCleanupTask: Task<Void, Error>?

    private struct UploadRequest {
        let container: ModelContainer
        let date: Date?
        let calendar: Calendar?
    }
    private var dashboardSubscriptionDay: CalendarDay?
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
            try await requestUpload(UploadRequest(container: container, date: nil, calendar: nil)).value
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
        try await remoteClient.updateDisplayName(displayName)
    }

    func uploadTodaySnapshot(container: ModelContainer, date: Date = .now, calendar: Calendar = .current) async throws {
        guard isDeviceSharingEnabled else { return }
        try await requestUpload(UploadRequest(container: container, date: date, calendar: calendar)).value
    }

    private func requestUpload(_ request: UploadRequest) -> Task<Void, Error> {
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
            let localSnapshot = try DailyMacroSnapshotLoader.loadNutrition(for: date, in: request.container, calendar: calendar)
            let payload = SharingDailySnapshotPayload(
                day: CalendarDay(date: date, calendar: calendar).sharingDayKey,
                timeZoneId: calendar.timeZone.identifier,
                calories: localSnapshot.totals.calories,
                protein: localSnapshot.totals.protein,
                fat: localSnapshot.totals.fat,
                carbs: localSnapshot.totals.carbs,
                entryCount: localSnapshot.entryCount
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
        try await remoteClient.authenticate(displayName: displayName ?? storedDisplayName)
        try checkIdentity(generation)
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
        dashboardSubscriptionAttemptId = attemptId
        let remoteClient = remoteClient
        dashboardSubscriptionTask = Task { @MainActor [weak self, remoteClient] in
            defer { self?.finishDashboardSubscription(attemptId: attemptId) }

            do {
                try await remoteClient.authenticate(displayName: displayName)
                guard !Task.isCancelled, self?.isCurrentDashboardSubscriptionAttempt(attemptId) == true else { return }
                let values = remoteClient.dashboard(for: day).values
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
        isDashboardLoading = false
        if self.dashboard != dashboard { self.dashboard = dashboard }
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
        }
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
        let response = try await remoteClient.createInvite(tokenHash: tokenHash)
        try checkIdentity(generation)
        let invite = localStateStore.makeInvite(inviteId: response.inviteId, token: token, expiresAt: response.expiresAt)
        try localStateStore.savePendingInvite(invite)
        return invite
    }

    func revokeInvite(_ invite: SharingInvite) async throws {
        let generation = identityGeneration
        try await authenticateForOperation()
        try await remoteClient.revokeInvite(id: invite.inviteId)
        try checkIdentity(generation)
        try localStateStore.clearPendingInvite()
    }

    func acceptInvite(input: String, ownerDay: CalendarDay) async throws {
        try await authenticateForOperation()
        try await remoteClient.acceptInvite(tokenHash: sha256Hex(inviteToken(from: input)), ownerDay: ownerDay)
    }

    func setOutgoingSharing(to profileId: String, enabled: Bool, ownerDay: CalendarDay) async throws {
        try await authenticateForOperation()
        try await remoteClient.setOutgoingSharing(to: profileId, enabled: enabled, ownerDay: ownerDay)
    }

    func stopSharingMyData(ownerDay: CalendarDay) async throws {
        try await authenticateForOperation()
        try await remoteClient.stopSharingMyData(ownerDay: ownerDay)
    }

    func disableSharingOnDevice(ownerDay: CalendarDay) async throws {
        let generation = identityGeneration
        try await stopSharingMyData(ownerDay: ownerDay)
        try checkIdentity(generation)
        disableLocalSharing()
    }

    func removePerson(_ profileId: String, ownerDay: CalendarDay) async throws {
        try await authenticateForOperation()
        try await remoteClient.removePerson(profileId, ownerDay: ownerDay)
    }

    func deleteSharingProfile() async throws {
        if let profileDeletionTask { return try await profileDeletionTask.value }
        let task = Task { @MainActor in
            defer { self.profileDeletionTask = nil }
            if !self.localStateStore.isCredentialCleanupPending {
                try await self.remoteClient.authenticate(displayName: self.storedDisplayName)
                try await self.remoteClient.deleteSharingProfile()
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
