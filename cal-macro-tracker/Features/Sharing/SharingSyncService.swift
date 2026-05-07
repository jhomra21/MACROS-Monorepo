import Combine
import CryptoKit
import Foundation
import ConvexMobile
import SwiftData

enum SharingUploadStatus: String {
    case idle
    case uploading
    case succeeded
    case failed
}

struct SharingDashboard: Decodable, Equatable {
    let people: [SharingPerson]
}

struct SharingPerson: Decodable, Equatable, Identifiable {
    let relationshipId: String
    let profileId: String
    let displayName: String
    let incomingActive: Bool
    let outgoingActive: Bool
    let scope: SharingScope
    let snapshot: SharedDailySnapshot?

    var id: String { relationshipId }
}

struct SharingScope: Decodable, Equatable {
    let macros: Bool
}

struct SharedDailySnapshot: Decodable, Equatable {
    let day: String
    let timeZoneId: String
    let calories: Double
    let protein: Double
    let fat: Double
    let carbs: Double
    let entryCount: Int
    let updatedAt: Double
}

struct SharingInvite: Equatable {
    let inviteId: String
    let token: String
    let url: URL
    let appURL: URL
    let expiresAt: Date
}

private struct CreateInviteResponse: Decodable {
    let inviteId: String
    let expiresAt: Double
}

private struct SharingMutationStatus: Decodable {
    let ok: Bool
}

private struct UpsertDailySnapshotResponse: Decodable {
    let snapshotId: String
}

@MainActor
@Observable
final class SharingSyncService {
    private let authService: SharingAuthService
    private(set) var lastUploadStatus: SharingUploadStatus
    private(set) var lastUploadDate: Date?
    private var lastUploadedSnapshotHash: String?
    var isDeviceSharingEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: AppStorageKeys.isSharingDeviceEnabled) }
        set { UserDefaults.standard.set(newValue, forKey: AppStorageKeys.isSharingDeviceEnabled) }
    }

    init(authService: SharingAuthService) {
        self.authService = authService
        let defaults = UserDefaults.standard
        lastUploadStatus =
            defaults.string(forKey: AppStorageKeys.sharingLastUploadStatus)
            .flatMap(SharingUploadStatus.init(rawValue:)) ?? .idle
        let lastUploadTimeInterval = defaults.double(forKey: AppStorageKeys.sharingLastUploadDate)
        lastUploadDate = lastUploadTimeInterval > 0 ? Date(timeIntervalSince1970: lastUploadTimeInterval) : nil
        lastUploadedSnapshotHash = defaults.string(forKey: AppStorageKeys.sharingLastUploadedSnapshotHash)
    }

    func syncTodayIfConfigured(container: ModelContainer) async {
        guard isDeviceSharingEnabled else { return }

        do {
            _ = try await authService.authenticate(displayName: storedDisplayName)
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
        _ = try await authService.authenticate(displayName: displayName)
        try await updateDisplayNameAfterAuthentication(displayName)
        UserDefaults.standard.set(displayName, forKey: AppStorageKeys.sharingDisplayName)
        isDeviceSharingEnabled = true
        try await uploadTodaySnapshot(container: container)
    }

    func updateDisplayName(_ displayName: String) async throws {
        let displayName = normalizedDisplayName(displayName)
        _ = try await authService.authenticate(displayName: displayName)
        try await updateDisplayNameAfterAuthentication(displayName)
        UserDefaults.standard.set(displayName, forKey: AppStorageKeys.sharingDisplayName)
    }

    private func updateDisplayNameAfterAuthentication(_ displayName: String) async throws {
        let _: SharingMutationStatus = try await authService.client.mutation(
            "sharing:updateDisplayName",
            with: ["displayName": displayName]
        )
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
        let _: UpsertDailySnapshotResponse = try await authService.client.mutation(
            "sharing:upsertMyDailySnapshot",
            with: payload.convexArguments
        )
        lastUploadedSnapshotHash = snapshotHash
        UserDefaults.standard.set(snapshotHash, forKey: AppStorageKeys.sharingLastUploadedSnapshotHash)
        setLastUploadDate(.now)
        setLastUploadStatus(.succeeded)
    }

    func dashboard(for day: CalendarDay) -> AnyPublisher<SharingDashboard, Error> {
        let dayKey = day.sharingDayKey
        return authService.client
            .subscribe(
                to: "sharing:sharingDashboard",
                with: ["day": dayKey, "ownerToday": dayKey],
                yielding: SharingDashboard.self
            )
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }

    func prepareDashboardSubscription() async throws {
        _ = try await authService.authenticate(displayName: storedDisplayName)
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

        return SharingInvite(
            inviteId: inviteId,
            token: token,
            url: SharingConfiguration.authBaseURL.appending(path: "invite/\(token)"),
            appURL: SharingConfiguration.inviteAppURL(token: token),
            expiresAt: expiresAt
        )
    }

    func createInvite() async throws -> SharingInvite {
        _ = try await authService.authenticate(displayName: storedDisplayName)
        let token = try SharingRandomToken.make()
        let tokenHash = sha256Hex(token)
        let response: CreateInviteResponse = try await authService.client.mutation(
            "sharing:createInvite",
            with: ["tokenHash": tokenHash]
        )
        let invite = SharingInvite(
            inviteId: response.inviteId,
            token: token,
            url: SharingConfiguration.authBaseURL.appending(path: "invite/\(token)"),
            appURL: SharingConfiguration.inviteAppURL(token: token),
            expiresAt: Date(timeIntervalSince1970: response.expiresAt / 1000)
        )
        savePendingInvite(invite)
        return invite
    }

    func revokeInvite(_ invite: SharingInvite) async throws {
        _ = try await authService.authenticate()
        let _: SharingMutationStatus = try await authService.client.mutation(
            "sharing:revokePendingInvite",
            with: ["inviteId": invite.inviteId]
        )
        clearPendingInvite()
    }

    func acceptInvite(input: String, ownerDay: CalendarDay) async throws {
        _ = try await authService.authenticate(displayName: storedDisplayName)
        let _: [String: String] = try await authService.client.mutation(
            "sharing:acceptInvite",
            with: ["tokenHash": sha256Hex(inviteToken(from: input)), "ownerDay": ownerDay.sharingDayKey]
        )
    }

    func setOutgoingSharing(to profileId: String, enabled: Bool, ownerDay: CalendarDay) async throws {
        _ = try await authService.authenticate(displayName: storedDisplayName)
        let _: SharingMutationStatus = try await authService.client.mutation(
            "sharing:setOutgoingSharingForPerson",
            with: ["toProfileId": profileId, "enabled": enabled, "ownerDay": ownerDay.sharingDayKey]
        )
    }

    func stopSharingMyData(ownerDay: CalendarDay) async throws {
        _ = try await authService.authenticate(displayName: storedDisplayName)
        let _: SharingMutationStatus = try await authService.client.mutation(
            "sharing:stopSharingMyData",
            with: ["ownerDay": ownerDay.sharingDayKey]
        )
    }

    func removePerson(_ profileId: String, ownerDay: CalendarDay) async throws {
        _ = try await authService.authenticate(displayName: storedDisplayName)
        let _: SharingMutationStatus = try await authService.client.mutation(
            "sharing:removePerson",
            with: ["otherProfileId": profileId, "ownerDay": ownerDay.sharingDayKey]
        )
    }

    func deleteSharingProfile() async throws {
        _ = try await authService.authenticate(displayName: storedDisplayName)
        let _: SharingMutationStatus = try await authService.client.mutation("sharing:deleteMySharingProfile")
        try await authService.clearLocalIdentity()
        isDeviceSharingEnabled = false
        clearUploadMetadata()
        clearPendingInvite()
    }

    private var storedDisplayName: String {
        normalizedDisplayName(UserDefaults.standard.string(forKey: AppStorageKeys.sharingDisplayName) ?? "Me")
    }

    private func normalizedDisplayName(_ displayName: String) -> String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Me" : String(trimmed.prefix(40))
    }

    private func savePendingInvite(_ invite: SharingInvite) {
        let defaults = UserDefaults.standard
        defaults.set(invite.inviteId, forKey: AppStorageKeys.sharingPendingInviteId)
        defaults.set(invite.token, forKey: AppStorageKeys.sharingPendingInviteToken)
        defaults.set(invite.expiresAt.timeIntervalSince1970, forKey: AppStorageKeys.sharingPendingInviteExpiresAt)
    }

    private func clearPendingInvite() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: AppStorageKeys.sharingPendingInviteId)
        defaults.removeObject(forKey: AppStorageKeys.sharingPendingInviteToken)
        defaults.removeObject(forKey: AppStorageKeys.sharingPendingInviteExpiresAt)
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
        UserDefaults.standard.set(status.rawValue, forKey: AppStorageKeys.sharingLastUploadStatus)
    }

    private func setLastUploadDate(_ date: Date) {
        lastUploadDate = date
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: AppStorageKeys.sharingLastUploadDate)
    }

    private func clearUploadMetadata() {
        let defaults = UserDefaults.standard
        lastUploadedSnapshotHash = nil
        lastUploadDate = nil
        lastUploadStatus = .idle
        defaults.removeObject(forKey: AppStorageKeys.sharingLastUploadedSnapshotHash)
        defaults.removeObject(forKey: AppStorageKeys.sharingLastUploadDate)
        defaults.removeObject(forKey: AppStorageKeys.sharingLastUploadStatus)
    }
}

private struct SharingDailySnapshotPayload {
    let day: String
    let timeZoneId: String
    let calories: Double
    let protein: Double
    let fat: Double
    let carbs: Double
    let entryCount: Int

    var convexArguments: [String: ConvexEncodable?] {
        [
            "day": day,
            "timeZoneId": timeZoneId,
            "calories": calories,
            "protein": protein,
            "fat": fat,
            "carbs": carbs,
            "entryCount": Double(entryCount)
        ]
    }

    var stableHash: String {
        let stableInput = [
            day,
            timeZoneId,
            String(calories.bitPattern),
            String(protein.bitPattern),
            String(fat.bitPattern),
            String(carbs.bitPattern),
            String(entryCount)
        ].joined(separator: "|")
        return SHA256.hash(data: Data(stableInput.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

private extension CalendarDay {
    var sharingDayKey: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }
}
