import Combine
import Observation
import SwiftData
import XCTest
@testable import cal_macro_tracker

@MainActor
final class SharingReliabilityTests: XCTestCase {
    private func fixture() throws -> Fixture { try Fixture() }

    private func submitUpload(_ f: Fixture) async -> Task<Void, Error> {
        let submitted = expectation(description: "upload request submitted")
        let task = Task {
            submitted.fulfill()
            try await f.service.uploadTodaySnapshot(container: f.container)
        }
        await fulfillment(of: [submitted], timeout: 2)
        return task
    }

    private func observeChange(read: () -> Void, action: () -> Void) async {
        let changed = expectation(description: "production observable state changed")
        withObservationTracking(read) { changed.fulfill() }
        action()
        await fulfillment(of: [changed], timeout: 2)
    }

    func testUploadRevertDrainsLatestSnapshotAndAcknowledgesFinalHash() async throws {
        let f = try fixture()
        try await f.service.uploadTodaySnapshot(container: f.container)
        let originalHash = f.store.lastUploadedSnapshotHash
        try f.setCalories(100)
        f.remote.delayUpload = true
        let pending = Task { try await f.service.uploadTodaySnapshot(container: f.container) }
        await f.remote.uploadStarted()
        try f.setCalories(0)
        let revert = await submitUpload(f)
        f.remote.releaseUpload()
        try await pending.value
        try await revert.value
        XCTAssertEqual(f.remote.uploads.map(\.calories), [0, 100, 0])
        XCTAssertEqual(f.remote.committed?.calories, 0)
        XCTAssertEqual(f.store.lastUploadedSnapshotHash, originalHash)
        XCTAssertEqual(f.service.lastUploadStatus, .succeeded)
    }

    func testConcurrentIdenticalRequestsAndRepeatedNoopsWriteOnce() async throws {
        let f = try fixture()
        f.remote.delayUpload = true
        let first = Task { try await f.service.uploadTodaySnapshot(container: f.container) }
        await f.remote.uploadStarted()
        let second = await submitUpload(f)
        f.remote.releaseUpload()
        try await first.value
        try await second.value
        try await f.service.uploadTodaySnapshot(container: f.container)
        XCTAssertEqual(f.remote.uploads.count, 1)
    }

    func testFailureSettlesAndExplicitRecoveryUsesLatestLocalChange() async throws {
        let f = try fixture()
        f.remote.delayUpload = true
        f.remote.failUpload = true
        let first = Task { try await f.service.uploadTodaySnapshot(container: f.container) }
        await f.remote.uploadStarted()
        try f.setCalories(250)
        let latest = await submitUpload(f)
        f.remote.releaseUpload()
        do { try await first.value; XCTFail("Expected upload failure") } catch {}
        do { try await latest.value; XCTFail("Expected joined failure") } catch {}
        XCTAssertEqual(f.service.lastUploadStatus, .failed)
        XCTAssertEqual(f.remote.uploads.count, 1)
        f.remote.failUpload = false
        try await f.service.uploadTodaySnapshot(container: f.container)
        XCTAssertEqual(f.remote.committed?.calories, 250)
        XCTAssertEqual(f.remote.uploads.count, 2)
    }

    func testNewDayPublishesZeroAndHistoricalSelectionCannotChooseSharedDay() async throws {
        let f = try fixture()
        try f.setCalories(100)
        try await f.service.uploadTodaySnapshot(container: f.container)
        let tomorrow = CalendarDay(date: .now).advanced(byDays: 1)!
        var selection = AppDaySelection(today: CalendarDay(date: .now))
        selection.select(CalendarDay(date: .now).advanced(byDays: -7)!, today: CalendarDay(date: .now))
        try await f.service.uploadTodaySnapshot(container: f.container, date: tomorrow.startDate)
        XCTAssertEqual(f.remote.committed?.day, tomorrow.sharingDayKey)
        XCTAssertEqual(f.remote.committed?.calories, 0)
        XCTAssertNotEqual(f.remote.committed?.day, selection.selectedDay.sharingDayKey)
        XCTAssertEqual(f.remote.uploads.count, 2)
    }

    func testEffectiveTimezoneParticipatesInSnapshotHash() async throws {
        let f = try fixture()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Pacific/Auckland")!
        try f.setCalories(100)
        let entries = try ModelContext(f.container).fetch(FetchDescriptor<LogEntry>())
        let selectedDay = CalendarDay(date: .now, calendar: calendar)
        XCTAssertEqual(InsightsAnalytics.points(for: entries, days: [selectedDay]).first?.snapshot.totals.calories, 100)
        let date = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12))!
        try await f.service.uploadTodaySnapshot(container: f.container, date: date, calendar: calendar)
        let initialHash = f.store.lastUploadedSnapshotHash
        XCTAssertEqual(f.remote.committed?.timeZoneId, calendar.timeZone.identifier)
        XCTAssertEqual(f.remote.committed?.day, CalendarDay(date: date, calendar: calendar).sharingDayKey)
        calendar.timeZone = TimeZone(identifier: "Pacific/Honolulu")!
        try await f.service.uploadTodaySnapshot(container: f.container, date: date, calendar: calendar)
        XCTAssertNotEqual(f.store.lastUploadedSnapshotHash, initialHash)
        XCTAssertEqual(f.remote.uploads.count, 2)
    }

    func testDeletionDuringCommittedDelayedUploadCannotRepopulateMetadata() async throws {
        let f = try fixture()
        f.remote.delayUpload = true
        let upload = Task { try await f.service.uploadTodaySnapshot(container: f.container) }
        await f.remote.uploadStarted()
        try await f.service.deleteSharingProfile()
        f.remote.releaseUpload()
        _ = try? await upload.value
        XCTAssertFalse(f.service.isDeviceSharingEnabled)
        XCTAssertNil(f.store.lastUploadedSnapshotHash)
        XCTAssertNil(f.service.lastUploadDate)
        XCTAssertEqual(f.service.lastUploadStatus, .idle)
        XCTAssertEqual(f.cleanup.calls, 1)
    }

    func testCommittedDeletionCleanupFailureRetriesLocallyAcrossColdLaunch() async throws {
        let f = try fixture()
        try await f.service.uploadTodaySnapshot(container: f.container)
        f.cleanup.shouldFail = true
        do { try await f.service.deleteSharingProfile(); XCTFail("Expected credential cleanup failure") } catch {}
        XCTAssertFalse(f.service.isDeviceSharingEnabled)
        XCTAssertNil(f.store.lastUploadedSnapshotHash)
        XCTAssertNil(try f.service.pendingInvite())
        XCTAssertEqual(f.remote.deletes, 1)
        let authenticationCount = f.remote.authentications
        let cold = SharingSyncService(remoteClient: f.remote, credentialCleanup: f.cleanup, localStateStore: f.store)
        f.cleanup.shouldFail = false
        try await cold.deleteSharingProfile()
        XCTAssertEqual(f.remote.deletes, 1)
        XCTAssertEqual(f.remote.authentications, authenticationCount)
        XCTAssertEqual(f.cleanup.calls, 2)
    }

    func testFailedJoinedCredentialCleanupSettlesForLaterRetry() async throws {
        let f = try fixture()
        f.store.isCredentialCleanupPending = true
        f.cleanup.delay = true
        f.cleanup.shouldFail = true

        let enable = Task { try await f.service.enableSharing(displayName: "Replacement", container: f.container) }
        await f.cleanup.cleanupStarted(count: 1)
        let deleteRetry = Task { try await f.service.deleteSharingProfile() }
        await Task.yield()
        f.cleanup.releaseCleanup()

        do { try await enable.value; XCTFail("Expected shared cleanup failure") } catch {}
        do { try await deleteRetry.value; XCTFail("Expected shared cleanup failure") } catch {}
        XCTAssertEqual(f.cleanup.calls, 1)
        XCTAssertTrue(f.store.isCredentialCleanupPending)
        XCTAssertEqual(f.remote.authentications, 0)

        f.cleanup.shouldFail = false
        try await f.service.deleteSharingProfile()
        XCTAssertEqual(f.cleanup.calls, 2)
        XCTAssertFalse(f.store.isCredentialCleanupPending)
    }

    func testDeletionBeforeRemoteCommitPreservesEnabledState() async throws {
        let f = try fixture()
        f.remote.failDelete = true
        do { try await f.service.deleteSharingProfile(); XCTFail("Expected remote failure") } catch {}
        XCTAssertTrue(f.service.isDeviceSharingEnabled)
        XCTAssertEqual(f.cleanup.calls, 0)
    }

    func testDeviceDisableOwnsGrantsSubscriptionAndDelayedUploadCleanup() async throws {
        let f = try fixture()
        let today = CalendarDay(date: .now)
        f.service.startDashboardSubscription(for: today)
        await f.remote.dashboardStarted(count: 1)
        f.remote.delayUpload = true
        let upload = Task { try await f.service.uploadTodaySnapshot(container: f.container) }
        await f.remote.uploadStarted()
        try await f.service.disableSharingOnDevice(ownerDay: today)
        f.remote.releaseUpload()
        _ = try? await upload.value
        XCTAssertEqual(f.remote.grantStops, 1)
        XCTAssertEqual(f.remote.dashboardCancels, 1)
        XCTAssertFalse(f.service.isDeviceSharingEnabled)
        XCTAssertFalse(f.service.shouldShowDashboardLoading)
        XCTAssertNil(f.store.lastUploadedSnapshotHash)
    }

    func testEnableFinishesPendingCleanupBeforeAuthentication() async throws {
        let f = try fixture()
        f.cleanup.shouldFail = true
        _ = try? await f.service.deleteSharingProfile()
        let calls = f.remote.authentications
        do {
            try await f.service.enableSharing(displayName: "QA", container: f.container)
            XCTFail("Expected pending cleanup failure")
        } catch {}
        XCTAssertEqual(f.remote.authentications, calls)
        XCTAssertFalse(f.service.isDeviceSharingEnabled)
    }

    func testEnableAndDeleteRetryJoinPendingCredentialCleanup() async throws {
        let f = try fixture()
        f.store.isCredentialCleanupPending = true
        f.cleanup.delay = true

        let enable = Task { try await f.service.enableSharing(displayName: "Replacement", container: f.container) }
        await f.cleanup.cleanupStarted(count: 1)
        let deleteRetry = Task { try await f.service.deleteSharingProfile() }
        await Task.yield()

        XCTAssertEqual(f.cleanup.calls, 1)
        XCTAssertEqual(f.remote.authentications, 0)
        f.cleanup.releaseCleanup()
        try await enable.value
        try await deleteRetry.value

        XCTAssertEqual(f.cleanup.calls, 1)
        XCTAssertEqual(f.cleanup.completedCalls, 1)
        XCTAssertEqual(Set(f.remote.authenticatedNames), ["Replacement"])
        XCTAssertTrue(f.service.isDeviceSharingEnabled)
        XCTAssertNotNil(f.store.lastUploadedSnapshotHash)
        XCTAssertEqual(f.remote.uploads.count, 1)
    }

    func testStaleDeviceDisableResponseCannotDisableReplacementIdentity() async throws {
        let f = try fixture()
        f.remote.delayStopGrants = true
        let disable = Task {
            try await f.service.disableSharingOnDevice(ownerDay: CalendarDay(date: .now))
        }
        await f.remote.stopGrantsStarted()

        try await f.service.deleteSharingProfile()
        try await f.service.enableSharing(displayName: "Replacement", container: f.container)
        f.service.startDashboardSubscription(for: CalendarDay(date: .now))
        await f.remote.dashboardStarted(count: 1)
        let replacementHash = f.store.lastUploadedSnapshotHash
        let replacementUploads = f.remote.uploads.count

        f.remote.releaseStopGrants()
        do {
            try await disable.value
            XCTFail("Expected stale device-disable response to be rejected")
        } catch is CancellationError {
        }

        XCTAssertTrue(f.service.isDeviceSharingEnabled)
        XCTAssertEqual(f.store.lastUploadedSnapshotHash, replacementHash)
        XCTAssertEqual(f.remote.uploads.count, replacementUploads)
        XCTAssertEqual(f.remote.dashboardStarts, 1)
        XCTAssertEqual(f.remote.dashboardCancels, 0)
    }

    func testDashboardReusesSameDayAndCancelsOnDayChangeAndDeletion() async throws {
        let f = try fixture()
        let today = CalendarDay(date: .now)
        f.service.startDashboardSubscription(for: today)
        await f.remote.dashboardStarted(count: 1)
        f.service.startDashboardSubscription(for: today)
        XCTAssertEqual(f.remote.dashboardStarts, 1)
        f.service.startDashboardSubscription(for: today.advanced(byDays: 1)!)
        await f.remote.dashboardStarted(count: 2)
        XCTAssertEqual(f.remote.dashboardCancels, 1)
        f.remote.streams[0].send(completion: .failure(QAError.injected))
        XCTAssertNil(f.service.dashboardErrorMessage)
        XCTAssertTrue(f.service.shouldShowDashboardLoading)
        try await f.service.deleteSharingProfile()
        await f.remote.dashboardCancelled(count: 2)
        XCTAssertFalse(f.service.shouldShowDashboardLoading)
        XCTAssertTrue(f.service.dashboard.people.isEmpty)
    }

    func testStaleAuthenticationCannotStartDashboardAfterDeletion() async throws {
        let f = try fixture()
        f.remote.delayAuthentication = true
        f.service.startDashboardSubscription(for: CalendarDay(date: .now))
        await f.remote.authenticationStarted()
        // Release only subscription authentication after delete has committed.
        f.remote.delayAuthentication = false
        try await f.service.deleteSharingProfile()
        f.remote.releaseAuthentication()
        await f.remote.authenticationReleased()
        XCTAssertEqual(f.remote.dashboardStarts, 0)
        XCTAssertFalse(f.service.shouldShowDashboardLoading)
    }

    func testDashboardValueFailureCompletionAndExplicitRestart() async throws {
        let f = try fixture()
        let day = CalendarDay(date: .now)
        f.service.startDashboardSubscription(for: day)
        await f.remote.dashboardStarted(count: 1)
        await observeChange(read: { _ = f.service.shouldShowDashboardLoading }) {
            f.remote.streams[0].send(SharingDashboard(people: []))
        }
        XCTAssertFalse(f.service.shouldShowDashboardLoading)
        await observeChange(read: { _ = f.service.dashboardErrorMessage }) {
            f.remote.streams[0].send(completion: .failure(QAError.injected))
        }
        XCTAssertNotNil(f.service.dashboardErrorMessage)
        f.service.startDashboardSubscription(for: day)
        await f.remote.dashboardStarted(count: 2)
        XCTAssertNil(f.service.dashboardErrorMessage)
        await observeChange(read: { _ = f.service.shouldShowDashboardLoading }) {
            f.remote.streams[1].send(completion: .finished)
        }
        XCTAssertFalse(f.service.shouldShowDashboardLoading)
        f.service.startDashboardSubscription(for: day)
        await f.remote.dashboardStarted(count: 3)
        f.service.stopDashboardSubscription(clearDashboard: true)
    }

    func testSecureInviteMigrationColdLoadAndRevokeCleanup() async throws {
        let f = try fixture()
        let secure = SharingInviteTokenStore(service: "SharingReliability.\(UUID())")
        defer { try? secure.deleteToken() }
        let store = SharingLocalStateStore(defaults: f.defaults, tokenStore: secure)
        f.seedLegacyInvite()
        let invite = try XCTUnwrap(store.pendingInvite())
        XCTAssertTrue(f.defaults.string(forKey: AppStorageKeys.sharingPendingInviteToken) == nil)
        XCTAssertTrue(try secure.loadToken() != nil)
        let cold = SharingLocalStateStore(defaults: f.defaults, tokenStore: secure)
        XCTAssertEqual(try cold.pendingInvite()?.inviteId, invite.inviteId)
        let service = SharingSyncService(remoteClient: f.remote, credentialCleanup: f.cleanup, localStateStore: cold)
        try await service.revokeInvite(invite)
        XCTAssertNil(try secure.loadToken())
        XCTAssertNil(try cold.pendingInvite())
    }

    func testFailedSecureMigrationRetainsLegacyTokenAndThrows() throws {
        let f = try fixture()
        f.seedLegacyInvite()
        f.tokens.failSave = true
        XCTAssertThrowsError(try f.store.pendingInvite())
        XCTAssertTrue(f.defaults.string(forKey: AppStorageKeys.sharingPendingInviteToken) != nil)
        f.tokens.failSave = false
        XCTAssertNotNil(try f.store.pendingInvite())
        XCTAssertTrue(f.defaults.string(forKey: AppStorageKeys.sharingPendingInviteToken) == nil)
    }

    func testInviteSaveFailureAndExpiredCleanupAreExplicit() throws {
        let f = try fixture()
        let invite = f.store.makeInvite(inviteId: "qa", token: UUID().uuidString, expiresAt: .now.addingTimeInterval(3600))
        f.tokens.failSave = true
        XCTAssertThrowsError(try f.store.savePendingInvite(invite))
        XCTAssertTrue(f.defaults.string(forKey: AppStorageKeys.sharingPendingInviteToken) == nil)
        f.tokens.failSave = false
        try f.store.savePendingInvite(invite)
        f.defaults.set(Date.now.addingTimeInterval(-1).timeIntervalSince1970, forKey: AppStorageKeys.sharingPendingInviteExpiresAt)
        f.tokens.failDelete = true
        XCTAssertThrowsError(try f.store.pendingInvite())
        f.tokens.failDelete = false
        XCTAssertNil(try f.store.pendingInvite())
        XCTAssertTrue(f.tokens.token == nil)
    }

    func testDeleteSecureFailureHidesInviteAndRetriesWithoutRemoteCall() async throws {
        let f = try fixture()
        try f.store.savePendingInvite(
            f.store.makeInvite(inviteId: "qa", token: UUID().uuidString, expiresAt: .now.addingTimeInterval(3600)))
        f.tokens.failDelete = true
        do { try await f.service.deleteSharingProfile(); XCTFail("Expected secure failure") } catch {}
        XCTAssertNil(try f.service.pendingInvite())
        XCTAssertFalse(f.service.isDeviceSharingEnabled)
        f.tokens.failDelete = false
        try await f.service.deleteSharingProfile()
        XCTAssertTrue(f.tokens.token == nil)
        XCTAssertEqual(f.remote.deletes, 1)
    }
}

private enum QAError: Error { case injected }

@MainActor
private final class Fixture {
    let suite = "SharingReliability.\(UUID())"
    let defaults: UserDefaults
    let container: ModelContainer
    let remote = ControlledSharingRemote()
    let cleanup = ControlledCleanup()
    let tokens = ControlledTokens()
    let store: SharingLocalStateStore
    let service: SharingSyncService

    init() throws {
        defaults = UserDefaults(suiteName: suite)!
        store = SharingLocalStateStore(defaults: defaults, tokenStore: tokens)
        store.isDeviceSharingEnabled = true
        container = try ModelContainer(
            for: DailyGoals.self, FoodItem.self, Meal.self, MealComponent.self,
            LoggedMealComponentSnapshot.self, LogEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        service = SharingSyncService(remoteClient: remote, credentialCleanup: cleanup, localStateStore: store)
    }

    func setCalories(_ calories: Double) throws {
        let context = ModelContext(container)
        for entry in try context.fetch(FetchDescriptor<LogEntry>()) { context.delete(entry) }
        try context.save()
        guard calories > 0 else { return }
        var draft = FoodDraft()
        draft.name = "QA"
        draft.caloriesPerServing = calories
        draft.proteinPerServing = 0
        draft.fatPerServing = 0
        draft.carbsPerServing = 0
        try LogEntryRepository(modelContext: context).logFood(
            draft: draft, reusableFoodPersistenceMode: .none, loggedAt: .now,
            quantityMode: .servings, quantityAmount: 1, operation: "isolated sharing QA"
        )
    }

    func seedLegacyInvite() {
        defaults.set("qa", forKey: AppStorageKeys.sharingPendingInviteId)
        defaults.set(UUID().uuidString, forKey: AppStorageKeys.sharingPendingInviteToken)
        defaults.set(Date.now.addingTimeInterval(3600).timeIntervalSince1970, forKey: AppStorageKeys.sharingPendingInviteExpiresAt)
    }

    deinit { defaults.removePersistentDomain(forName: suite) }
}

@MainActor
private final class ControlledCleanup: SharingCredentialCleanup {
    var shouldFail = false
    var calls = 0
    var completedCalls = 0
    var delay = false
    private var cleanupGate: CheckedContinuation<Void, Never>?
    private var cleanupObserver: CheckedContinuation<Void, Never>?

    func clearLocalIdentity() async throws {
        calls += 1
        if delay {
            delay = false
            await withCheckedContinuation { continuation in
                cleanupGate = continuation
                cleanupObserver?.resume()
                cleanupObserver = nil
            }
        }
        if shouldFail { throw QAError.injected }
        completedCalls += 1
    }

    func cleanupStarted(count: Int) async {
        if calls >= count { return }
        await withCheckedContinuation { cleanupObserver = $0 }
    }

    func releaseCleanup() {
        cleanupGate?.resume()
        cleanupGate = nil
    }
}

private final class ControlledTokens: SharingInviteTokenStorage {
    var token: String?
    var failSave = false
    var failDelete = false
    func loadToken() throws -> String? { token }
    func saveToken(_ token: String) throws {
        if failSave { throw QAError.injected }
        self.token = token
    }
    func deleteToken() throws {
        if failDelete { throw QAError.injected }
        token = nil
    }
}

@MainActor
private final class ControlledSharingRemote: SharingRemote {
    var uploads: [SharingDailySnapshotPayload] = []
    var committed: SharingDailySnapshotPayload?
    var authentications = 0
    var deletes = 0
    var grantStops = 0
    var failDelete = false
    var delayUpload = false
    var failUpload = false
    var delayStopGrants = false
    var delayAuthentication = false
    var dashboardStarts = 0
    var dashboardCancels = 0
    var streams: [PassthroughSubject<SharingDashboard, Error>] = []
    private var uploadGate: CheckedContinuation<Void, Never>?
    private var uploadObserver: CheckedContinuation<Void, Never>?
    private var authGate: CheckedContinuation<Void, Never>?
    private var authObserver: CheckedContinuation<Void, Never>?
    private var authReleased = false
    private var authReleaseObserver: CheckedContinuation<Void, Never>?
    private var stopGrantsGate: CheckedContinuation<Void, Never>?
    private var stopGrantsObserver: CheckedContinuation<Void, Never>?
    private var startObserver: (Int, CheckedContinuation<Void, Never>)?
    private var cancelObserver: (Int, CheckedContinuation<Void, Never>)?
    var authenticatedNames: [String] = []

    func authenticate(displayName: String) async throws {
        authentications += 1
        authenticatedNames.append(displayName)
        if delayAuthentication {
            await withCheckedContinuation { continuation in
                authGate = continuation
                authObserver?.resume()
                authObserver = nil
            }
            authReleased = true
            authReleaseObserver?.resume()
            authReleaseObserver = nil
        }
    }
    func authenticationStarted() async {
        if authGate != nil { return }
        await withCheckedContinuation { authObserver = $0 }
    }
    func releaseAuthentication() { authGate?.resume(); authGate = nil }
    func authenticationReleased() async {
        if authReleased { return }
        await withCheckedContinuation { authReleaseObserver = $0 }
    }
    func updateDisplayName(_ displayName: String) async throws {}
    func upsertDailySnapshot(_ payload: SharingDailySnapshotPayload) async throws {
        uploads.append(payload)
        if delayUpload {
            delayUpload = false
            await withCheckedContinuation { continuation in
                uploadGate = continuation
                uploadObserver?.resume()
                uploadObserver = nil
            }
        }
        if failUpload { throw QAError.injected }
        committed = payload
    }
    func uploadStarted() async {
        if uploadGate != nil { return }
        await withCheckedContinuation { uploadObserver = $0 }
    }
    func releaseUpload() { uploadGate?.resume(); uploadGate = nil }
    func dashboard(for day: CalendarDay) -> AnyPublisher<SharingDashboard, Error> {
        let subject = PassthroughSubject<SharingDashboard, Error>()
        streams.append(subject)
        return subject.handleEvents(
            receiveSubscription: { [self] _ in
                dashboardStarts += 1
                if let (count, observer) = startObserver, dashboardStarts >= count {
                    startObserver = nil
                    observer.resume()
                }
            },
            receiveCancel: { [self] in
                dashboardCancels += 1
                if let (count, observer) = cancelObserver, dashboardCancels >= count {
                    cancelObserver = nil
                    observer.resume()
                }
            }
        ).eraseToAnyPublisher()
    }
    func dashboardStarted(count: Int) async {
        if dashboardStarts >= count { return }
        await withCheckedContinuation { startObserver = (count, $0) }
    }
    func dashboardCancelled(count: Int) async {
        if dashboardCancels >= count { return }
        await withCheckedContinuation { cancelObserver = (count, $0) }
    }
    func createInvite(tokenHash: String) async throws -> (inviteId: String, expiresAt: Date) {
        ("qa", .now.addingTimeInterval(3600))
    }
    func revokeInvite(id: String) async throws {}
    func acceptInvite(tokenHash: String, ownerDay: CalendarDay) async throws {}
    func setOutgoingSharing(to profileId: String, enabled: Bool, ownerDay: CalendarDay) async throws {}
    func stopSharingMyData(ownerDay: CalendarDay) async throws {
        grantStops += 1
        if delayStopGrants {
            delayStopGrants = false
            await withCheckedContinuation { continuation in
                stopGrantsGate = continuation
                stopGrantsObserver?.resume()
                stopGrantsObserver = nil
            }
        }
    }
    func stopGrantsStarted() async {
        if stopGrantsGate != nil { return }
        await withCheckedContinuation { stopGrantsObserver = $0 }
    }
    func releaseStopGrants() {
        stopGrantsGate?.resume()
        stopGrantsGate = nil
    }
    func removePerson(_ profileId: String, ownerDay: CalendarDay) async throws {}
    func deleteSharingProfile() async throws {
        if failDelete { throw QAError.injected }
        deletes += 1
    }
}
