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

    private enum CodingKeys: String, CodingKey {
        case relationshipId, profileId, displayName, incomingActive, outgoingActive
        case scope, snapshot, foodsShared, outgoingScope, connectionPaused
    }

    init(
        relationshipId: String,
        profileId: String,
        displayName: String,
        incomingActive: Bool,
        outgoingActive: Bool,
        scope: SharingScope,
        snapshot: SharedDailySnapshot?,
        foodsShared: Bool,
        outgoingScope: SharingOutgoingScope,
        connectionPaused: Bool
    ) {
        self.relationshipId = relationshipId
        self.profileId = profileId
        self.displayName = displayName
        self.incomingActive = incomingActive
        self.outgoingActive = outgoingActive
        self.scope = scope
        self.snapshot = snapshot
        self.foodsShared = foodsShared
        self.outgoingScope = outgoingScope
        self.connectionPaused = connectionPaused
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        relationshipId = try container.decode(String.self, forKey: .relationshipId)
        profileId = try container.decode(String.self, forKey: .profileId)
        displayName = try container.decode(String.self, forKey: .displayName)
        incomingActive = try container.decode(Bool.self, forKey: .incomingActive)
        outgoingActive = try container.decode(Bool.self, forKey: .outgoingActive)
        scope = try container.decode(SharingScope.self, forKey: .scope)
        snapshot = try container.decodeIfPresent(SharedDailySnapshot.self, forKey: .snapshot)
        foodsShared = try container.decodeIfPresent(Bool.self, forKey: .foodsShared) ?? false
        connectionPaused = try container.decodeIfPresent(Bool.self, forKey: .connectionPaused) ?? false
        outgoingScope =
            try container.decodeIfPresent(SharingOutgoingScope.self, forKey: .outgoingScope)
            ?? (outgoingActive ? .macros : .off)
    }
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
    enum Visibility: String, Decodable {
        case shared
        case notShared
        case paused
    }

    let visibility: Visibility
    let snapshot: SharedDailySnapshot?
    let foods: [SharedFood]

    private enum CodingKeys: String, CodingKey {
        case visibility, snapshot, foods
    }

    init(visibility: Visibility = .shared, snapshot: SharedDailySnapshot?, foods: [SharedFood]) {
        self.visibility = visibility
        self.snapshot = snapshot
        self.foods = foods
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        visibility = try container.decodeIfPresent(Visibility.self, forKey: .visibility) ?? .shared
        snapshot = try container.decodeIfPresent(SharedDailySnapshot.self, forKey: .snapshot)
        foods = try container.decode([SharedFood].self, forKey: .foods)
    }
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
    let calorieGoal: Double?
    let proteinGoal: Double?
    let carbsGoal: Double?
    let fatGoal: Double?

    private enum CodingKeys: String, CodingKey {
        case day, timeZoneId, calories, protein, fat, carbs, entryCount, updatedAt
        case calorieGoal, proteinGoal, carbsGoal, fatGoal
    }

    init(
        day: String,
        timeZoneId: String,
        calories: Double,
        protein: Double,
        fat: Double,
        carbs: Double,
        entryCount: Int,
        updatedAt: Double,
        calorieGoal: Double? = nil,
        proteinGoal: Double? = nil,
        carbsGoal: Double? = nil,
        fatGoal: Double? = nil
    ) {
        self.day = day
        self.timeZoneId = timeZoneId
        self.calories = calories
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.entryCount = entryCount
        self.updatedAt = updatedAt
        self.calorieGoal = calorieGoal
        self.proteinGoal = proteinGoal
        self.carbsGoal = carbsGoal
        self.fatGoal = fatGoal
    }

    var macroGoalsSnapshot: MacroGoalsSnapshot? {
        guard let calorieGoal, let proteinGoal, let carbsGoal, let fatGoal else { return nil }
        return MacroGoalsSnapshot(
            calorieGoal: calorieGoal,
            proteinGoalGrams: proteinGoal,
            fatGoalGrams: fatGoal,
            carbGoalGrams: carbsGoal
        )
    }
}

struct SharingInvite: Equatable, Identifiable {
    var id: String { inviteId }
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
    let calorieGoal: Double?
    let proteinGoal: Double?
    let carbsGoal: Double?
    let fatGoal: Double?

    init(
        day: String,
        timeZoneId: String,
        calories: Double,
        protein: Double,
        fat: Double,
        carbs: Double,
        entryCount: Int,
        foods: [SharedFoodPayload]? = nil,
        calorieGoal: Double? = nil,
        proteinGoal: Double? = nil,
        carbsGoal: Double? = nil,
        fatGoal: Double? = nil
    ) {
        self.day = day
        self.timeZoneId = timeZoneId
        self.calories = calories
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.entryCount = entryCount
        self.foods = foods
        self.calorieGoal = calorieGoal
        self.proteinGoal = proteinGoal
        self.carbsGoal = carbsGoal
        self.fatGoal = fatGoal
    }

    var convexArguments: [String: ConvexEncodable?] {
        var snapshot: [String: ConvexEncodable?] = [
            "day": day,
            "timeZoneId": timeZoneId,
            "calories": calories,
            "protein": protein,
            "fat": fat,
            "carbs": carbs,
            "entryCount": Double(entryCount)
        ]
        if let calorieGoal { snapshot["calorieGoal"] = calorieGoal }
        if let proteinGoal { snapshot["proteinGoal"] = proteinGoal }
        if let carbsGoal { snapshot["carbsGoal"] = carbsGoal }
        if let fatGoal { snapshot["fatGoal"] = fatGoal }
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
            String(entryCount),
            calorieGoal.map { String($0.bitPattern) } ?? "no-calorie-goal",
            proteinGoal.map { String($0.bitPattern) } ?? "no-protein-goal",
            carbsGoal.map { String($0.bitPattern) } ?? "no-carbs-goal",
            fatGoal.map { String($0.bitPattern) } ?? "no-fat-goal"
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
        self.name = Self.truncate(name.trimmingCharacters(in: .whitespacesAndNewlines), utf16Limit: 80)
        self.quantityText = Self.truncate(quantityText.trimmingCharacters(in: .whitespacesAndNewlines), utf16Limit: 40)
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

    private static func truncate(_ value: String, utf16Limit: Int) -> String {
        var result = ""
        var utf16Count = 0
        for character in value {
            let characterLength = String(character).utf16.count
            guard utf16Count + characterLength <= utf16Limit else { break }
            result.append(character)
            utf16Count += characterLength
        }
        return result
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

    mutating func insert(transactionID: UInt64, expiresAt: Date?, renewalInfo: String?) -> Bool {
        let expiryKey = expiresAt.map { String($0.timeIntervalSince1970) } ?? "lifetime"
        return submittedKeys.insert("\(transactionID):\(expiryKey):\(renewalKey(renewalInfo))").inserted
    }

    mutating func remove(transactionID: UInt64, expiresAt: Date?, renewalInfo: String?) {
        let expiryKey = expiresAt.map { String($0.timeIntervalSince1970) } ?? "lifetime"
        submittedKeys.remove("\(transactionID):\(expiryKey):\(renewalKey(renewalInfo))")
    }

    private func renewalKey(_ renewalInfo: String?) -> String {
        guard let renewalInfo else { return "none" }
        return SHA256.hash(data: Data(renewalInfo.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

extension CalendarDay {
    var sharingDayKey: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }
}
