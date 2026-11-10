#if DEBUG
import Combine
import Foundation

#if os(iOS)
import UIKit
#endif

/// Launch-time fixture for XCUITest. DEBUG only. It swaps in an in-memory store with the demo dataset,
/// a scripted entitlement and a scripted sharing remote, so UI runs never touch real data, Convex or StoreKit.
struct UITestFixture {
    let isPro: Bool
    let isSharingOn: Bool
    let isRemoteOffline: Bool
    let exportDirectory: URL?

    static let current: UITestFixture? = {
        let environment = ProcessInfo.processInfo.environment
        guard environment["MACROS_UI_FIXTURE"] == "1" else { return nil }
        return UITestFixture(
            isPro: environment["MACROS_FIXTURE_PRO"] == "1",
            isSharingOn: environment["MACROS_FIXTURE_SHARING"] == "on",
            isRemoteOffline: environment["MACROS_FIXTURE_REMOTE"] == "offline",
            exportDirectory: environment["MACROS_EXPORT_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
        )
    }()

    func apply(to entitlements: AppEntitlements) {
        UserDefaults.standard.set(isSharingOn, forKey: AppStorageKeys.isSharingDeviceEnabled)
        entitlements.update(
            EntitlementResolution(
                source: isPro ? .lifetime : nil, expiration: nil, hasActiveSubscription: false
            )
        )
    }

    func makeSharingSyncService() -> SharingSyncService {
        SharingSyncService(
            remoteClient: FixtureSharingRemote(isOffline: isRemoteOffline),
            credentialCleanup: FixtureCredentialCleanup()
        )
    }

    #if os(iOS)
    /// Lets the UI test inspect exactly what the Share button rendered.
    func recordExport(_ image: UIImage, name: String) {
        guard let exportDirectory, let data = image.pngData() else { return }
        try? FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        try? data.write(to: exportDirectory.appending(path: "\(name).png"))
    }
    #endif
}

private struct FixtureCredentialCleanup: SharingCredentialCleanup {
    func clearLocalIdentity() async throws {}
}

private struct FixtureSharingRemote: SharingRemote {
    let isOffline: Bool

    private var dashboardValue: SharingDashboard {
        SharingDashboard(
            people: ["Alex", "Sam"].map { name in
                SharingPerson(
                    relationshipId: "fixture-\(name)",
                    profileId: "fixture-profile-\(name)",
                    displayName: name,
                    incomingActive: true,
                    outgoingActive: true,
                    scope: SharingScope(macros: true),
                    snapshot: nil,
                    foodsShared: false,
                    outgoingScope: .macros,
                    connectionPaused: false
                )
            }
        )
    }

    func authenticate(displayName: String) async throws {
        if isOffline { throw URLError(.notConnectedToInternet) }
    }

    func dashboard(for day: CalendarDay) -> AnyPublisher<SharingDashboard, Error> {
        Just(dashboardValue).setFailureType(to: Error.self).eraseToAnyPublisher()
    }

    func updateDisplayName(_ displayName: String) async throws {}
    func upsertDailySnapshot(_ payload: SharingDailySnapshotPayload) async throws {}
    func createInvite(tokenHash: String) async throws -> (inviteId: String, expiresAt: Date) {
        throw URLError(.notConnectedToInternet)
    }
    func revokeInvite(id: String) async throws {}
    func acceptInvite(tokenHash: String, ownerDay: CalendarDay) async throws {}
    func setOutgoingSharing(to profileId: String, enabled: Bool, ownerDay: CalendarDay) async throws {}
    func stopSharingMyData(ownerDay: CalendarDay) async throws {}
    func removePerson(_ profileId: String, ownerDay: CalendarDay) async throws {}
    func deleteSharingProfile() async throws {}
}
#endif
