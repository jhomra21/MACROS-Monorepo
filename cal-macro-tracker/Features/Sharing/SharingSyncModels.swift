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
    let foodsShared: Bool
    let outgoingScope: SharingOutgoingScope
    let connectionPaused: Bool

    var id: String { relationshipId }
}

enum SharingOutgoingScope: String, Decodable, Equatable {
    case off
    case macros
    case macrosAndFoods
}

struct SharingScope: Decodable, Equatable {
    let macros: Bool
}

struct SharedFood: Decodable, Equatable, Identifiable {
    let localEntryId: String
    let sortIndex: Int
    let name: String
    let quantityText: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double

    var id: String { localEntryId }
}

struct SharingPersonDay: Decodable, Equatable {
    let snapshot: SharedDailySnapshot?
    let foods: [SharedFood]
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

struct SharingDailySnapshotPayload {
    let day: String
    let timeZoneId: String
    let calories: Double
    let protein: Double
    let fat: Double
    let carbs: Double
    let entryCount: Int
    let foods: [SharedFoodPayload]?

    init(
        day: String,
        timeZoneId: String,
        calories: Double,
        protein: Double,
        fat: Double,
        carbs: Double,
        entryCount: Int,
        foods: [SharedFoodPayload]? = nil
    ) {
        self.day = day
        self.timeZoneId = timeZoneId
        self.calories = calories
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.entryCount = entryCount
        self.foods = foods
    }

    var convexArguments: [String: ConvexEncodable?] {
        let snapshot: [String: ConvexEncodable?] = [
            "day": day,
            "timeZoneId": timeZoneId,
            "calories": calories,
            "protein": protein,
            "fat": fat,
            "carbs": carbs,
            "entryCount": Double(entryCount)
        ]
        var arguments: [String: ConvexEncodable?] = [
            "snapshot": snapshot
        ]
        if let foods {
            arguments["foods"] = foods.map(\.convexArguments)
        }
        return arguments
    }

    var stableHash: String {
        let snapshotInput = [
            day,
            timeZoneId,
            String(calories.bitPattern),
            String(protein.bitPattern),
            String(fat.bitPattern),
            String(carbs.bitPattern),
            String(entryCount)
        ]
        let foodInput = (foods ?? [])
            .sorted { $0.sortIndex == $1.sortIndex ? $0.localEntryId < $1.localEntryId : $0.sortIndex < $1.sortIndex }
            .flatMap {
                [
                    $0.localEntryId, String($0.sortIndex), $0.name, $0.quantityText,
                    String($0.calories.bitPattern), String($0.protein.bitPattern),
                    String($0.carbs.bitPattern), String($0.fat.bitPattern)
                ]
            }
        let stableInput = (snapshotInput + foodInput).joined(separator: "|")
        return SHA256.hash(data: Data(stableInput.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

struct SharedFoodPayload: Equatable {
    let localEntryId: String
    let sortIndex: Int
    let name: String
    let quantityText: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double

    init(
        localEntryId: String,
        sortIndex: Int,
        name: String,
        quantityText: String,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double
    ) {
        self.localEntryId = localEntryId
        self.sortIndex = sortIndex
        self.name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        self.quantityText = String(quantityText.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }

    init(entry: LogEntry, sortIndex: Int) {
        self.init(
            localEntryId: entry.id.uuidString,
            sortIndex: sortIndex,
            name: entry.foodName,
            quantityText: entry.quantitySummary,
            calories: entry.caloriesConsumed,
            protein: entry.proteinConsumed,
            carbs: entry.carbsConsumed,
            fat: entry.fatConsumed
        )
    }

    var convexArguments: [String: ConvexEncodable?] {
        [
            "localEntryId": localEntryId,
            "sortIndex": Double(sortIndex),
            "name": name,
            "quantityText": quantityText,
            "calories": calories,
            "protein": protein,
            "carbs": carbs,
            "fat": fat
        ]
    }
}

struct PurchaseSubmissionDeduplicator {
    private(set) var submittedKeys = Set<String>()

    mutating func insert(transactionID: UInt64, expiresAt: Date?) -> Bool {
        let expiryKey = expiresAt.map { String($0.timeIntervalSince1970) } ?? "lifetime"
        return submittedKeys.insert("\(transactionID):\(expiryKey)").inserted
    }

    mutating func remove(transactionID: UInt64, expiresAt: Date?) {
        let expiryKey = expiresAt.map { String($0.timeIntervalSince1970) } ?? "lifetime"
        submittedKeys.remove("\(transactionID):\(expiryKey)")
    }
}

extension CalendarDay {
    var sharingDayKey: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }
}
