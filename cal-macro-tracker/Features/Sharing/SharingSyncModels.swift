import ConvexMobile
import CryptoKit
import Foundation

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

struct SharingDashboardSubscriptionKey: Equatable {
    let isDeviceSharingEnabled: Bool
    let day: CalendarDay
}

struct SharingDailySnapshotPayload {
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

extension CalendarDay {
    var sharingDayKey: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }
}
