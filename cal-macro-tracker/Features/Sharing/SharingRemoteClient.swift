import Combine
import ConvexMobile
import Foundation

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
struct SharingRemoteClient {
    let authService: SharingAuthService

    func authenticate(displayName: String) async throws {
        _ = try await authService.authenticate(displayName: displayName)
    }

    func updateDisplayName(_ displayName: String) async throws {
        let _: SharingMutationStatus = try await authService.client.mutation(
            "sharing:updateDisplayName",
            with: ["displayName": displayName]
        )
    }

    func upsertDailySnapshot(_ payload: SharingDailySnapshotPayload) async throws {
        let _: UpsertDailySnapshotResponse = try await authService.client.mutation(
            "sharing:upsertMyDailySnapshot",
            with: payload.convexArguments
        )
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

    func createInvite(tokenHash: String) async throws -> (inviteId: String, expiresAt: Date) {
        let response: CreateInviteResponse = try await authService.client.mutation(
            "sharing:createInvite",
            with: ["tokenHash": tokenHash]
        )
        return (response.inviteId, Date(timeIntervalSince1970: response.expiresAt / 1000))
    }

    func revokeInvite(id inviteId: String) async throws {
        let _: SharingMutationStatus = try await authService.client.mutation(
            "sharing:revokePendingInvite",
            with: ["inviteId": inviteId]
        )
    }

    func acceptInvite(tokenHash: String, ownerDay: CalendarDay) async throws {
        let _: [String: String] = try await authService.client.mutation(
            "sharing:acceptInvite",
            with: ["tokenHash": tokenHash, "ownerDay": ownerDay.sharingDayKey]
        )
    }

    func setOutgoingSharing(to profileId: String, enabled: Bool, ownerDay: CalendarDay) async throws {
        let _: SharingMutationStatus = try await authService.client.mutation(
            "sharing:setOutgoingSharingForPerson",
            with: ["toProfileId": profileId, "enabled": enabled, "ownerDay": ownerDay.sharingDayKey]
        )
    }

    func stopSharingMyData(ownerDay: CalendarDay) async throws {
        let _: SharingMutationStatus = try await authService.client.mutation(
            "sharing:stopSharingMyData",
            with: ["ownerDay": ownerDay.sharingDayKey]
        )
    }

    func removePerson(_ profileId: String, ownerDay: CalendarDay) async throws {
        let _: SharingMutationStatus = try await authService.client.mutation(
            "sharing:removePerson",
            with: ["otherProfileId": profileId, "ownerDay": ownerDay.sharingDayKey]
        )
    }

    func deleteSharingProfile() async throws {
        let _: SharingMutationStatus = try await authService.client.mutation("sharing:deleteMySharingProfile")
        try await authService.clearLocalIdentity()
    }
}
