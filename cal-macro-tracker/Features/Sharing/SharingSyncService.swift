import Combine
import CryptoKit
import Foundation
import SwiftData

@MainActor
@Observable
final class SharingSyncService {
    private let remoteClient: SharingRemoteClient
    private let localStateStore: SharingLocalStateStore
    private(set) var lastUploadStatus: SharingUploadStatus
    private(set) var lastUploadDate: Date?
    private(set) var dashboard = SharingDashboard(people: [])
    private(set) var dashboardErrorMessage: String?
    private var isDashboardLoading = false
    var shouldShowDashboardLoading: Bool {
        dashboard.people.isEmpty && isDashboardLoading
    }

    private var lastUploadedSnapshotHash: String?
    private var dashboardSubscriptionDay: CalendarDay?
    private var dashboardSubscriptionTask: Task<Void, Never>?
    private var dashboardSubscriptionAttemptId: UUID?
    var isDeviceSharingEnabled: Bool {
        get { localStateStore.isDeviceSharingEnabled }
        set { localStateStore.isDeviceSharingEnabled = newValue }
    }

    init(authService: SharingAuthService) {
        let localStateStore = SharingLocalStateStore()
        self.remoteClient = SharingRemoteClient(authService: authService)
        self.localStateStore = localStateStore
        self.lastUploadStatus = localStateStore.lastUploadStatus
        self.lastUploadDate = localStateStore.lastUploadDate
        self.lastUploadedSnapshotHash = localStateStore.lastUploadedSnapshotHash
    }

    func syncTodayIfConfigured(container: ModelContainer) async {
        guard isDeviceSharingEnabled else { return }

        do {
            try await remoteClient.authenticate(displayName: storedDisplayName)
            try await uploadTodaySnapshot(container: container)
        } catch {
            setLastUploadStatus(.failed)
        }
    }

    func syncAfterDailyTotalsChange(container: ModelContainer) {
        Task {
            await syncTodayIfConfigured(container: container)
        }
    }

    func enableSharing(displayName: String, container: ModelContainer) async throws {
        let displayName = normalizedDisplayName(displayName)
        try await remoteClient.authenticate(displayName: displayName)
        try await updateDisplayNameAfterAuthentication(displayName)
        localStateStore.displayName = displayName
        isDeviceSharingEnabled = true
        try await uploadTodaySnapshot(container: container)
    }

    func updateDisplayName(_ displayName: String) async throws {
        let displayName = normalizedDisplayName(displayName)
        try await remoteClient.authenticate(displayName: displayName)
        try await updateDisplayNameAfterAuthentication(displayName)
        localStateStore.displayName = displayName
    }

    private func updateDisplayNameAfterAuthentication(_ displayName: String) async throws {
        try await remoteClient.updateDisplayName(displayName)
    }

    func uploadTodaySnapshot(container: ModelContainer, date: Date = .now) async throws {
        let localSnapshot = try DailyMacroSnapshotLoader.loadNutrition(for: date, in: container)
        let day = CalendarDay(date: date)
        let payload = SharingDailySnapshotPayload(
            day: day.sharingDayKey,
            timeZoneId: TimeZone.current.identifier,
            calories: localSnapshot.totals.calories,
            protein: localSnapshot.totals.protein,
            fat: localSnapshot.totals.fat,
            carbs: localSnapshot.totals.carbs,
            entryCount: localSnapshot.entryCount
        )
        let snapshotHash = payload.stableHash
        guard snapshotHash != lastUploadedSnapshotHash else { return }

        setLastUploadStatus(.uploading)
        try await remoteClient.upsertDailySnapshot(payload)
        lastUploadedSnapshotHash = snapshotHash
        localStateStore.lastUploadedSnapshotHash = snapshotHash
        setLastUploadDate(.now)
        setLastUploadStatus(.succeeded)
    }

    func prepareDashboardSubscription() async throws {
        try await remoteClient.authenticate(displayName: storedDisplayName)
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
        dashboardSubscriptionAttemptId = attemptId
        dashboardSubscriptionTask = Task { @MainActor in
            do {
                try await prepareDashboardSubscription()
                let values = remoteClient.dashboard(for: day).values
                for try await dashboard in values {
                    if isDashboardLoading {
                        isDashboardLoading = false
                    }
                    if self.dashboard != dashboard {
                        self.dashboard = dashboard
                    }
                    if dashboardErrorMessage != nil {
                        dashboardErrorMessage = nil
                    }
                }
            } catch is CancellationError {
            } catch {
                guard dashboardSubscriptionAttemptId == attemptId else { return }
                isDashboardLoading = false
                dashboardErrorMessage = error.localizedDescription
                dashboardSubscriptionTask = nil
                dashboardSubscriptionAttemptId = nil
            }
        }
    }

    func refreshDashboardSubscription(for day: CalendarDay) {
        stopDashboardSubscription(clearDashboard: false)
        startDashboardSubscription(for: day)
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

    func pendingInvite() -> SharingInvite? {
        localStateStore.pendingInvite()
    }

    func createInvite() async throws -> SharingInvite {
        try await remoteClient.authenticate(displayName: storedDisplayName)
        let token = try SharingRandomToken.make()
        let tokenHash = sha256Hex(token)
        let response = try await remoteClient.createInvite(tokenHash: tokenHash)
        let invite = localStateStore.makeInvite(inviteId: response.inviteId, token: token, expiresAt: response.expiresAt)
        localStateStore.savePendingInvite(invite)
        return invite
    }

    func revokeInvite(_ invite: SharingInvite) async throws {
        try await remoteClient.authenticate(displayName: storedDisplayName)
        try await remoteClient.revokeInvite(id: invite.inviteId)
        localStateStore.clearPendingInvite()
    }

    func acceptInvite(input: String, ownerDay: CalendarDay) async throws {
        try await remoteClient.authenticate(displayName: storedDisplayName)
        try await remoteClient.acceptInvite(tokenHash: sha256Hex(inviteToken(from: input)), ownerDay: ownerDay)
    }

    func setOutgoingSharing(to profileId: String, enabled: Bool, ownerDay: CalendarDay) async throws {
        try await remoteClient.authenticate(displayName: storedDisplayName)
        try await remoteClient.setOutgoingSharing(to: profileId, enabled: enabled, ownerDay: ownerDay)
    }

    func stopSharingMyData(ownerDay: CalendarDay) async throws {
        try await remoteClient.authenticate(displayName: storedDisplayName)
        try await remoteClient.stopSharingMyData(ownerDay: ownerDay)
    }

    func removePerson(_ profileId: String, ownerDay: CalendarDay) async throws {
        try await remoteClient.authenticate(displayName: storedDisplayName)
        try await remoteClient.removePerson(profileId, ownerDay: ownerDay)
    }

    func deleteSharingProfile() async throws {
        try await remoteClient.authenticate(displayName: storedDisplayName)
        try await remoteClient.deleteSharingProfile()
        isDeviceSharingEnabled = false
        stopDashboardSubscription(clearDashboard: true)
        clearUploadMetadata()
        localStateStore.clearPendingInvite()
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
