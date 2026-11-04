import Foundation

nonisolated struct SharedWidgetPerson: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let name: String
}

nonisolated struct SharedPersonWidgetControl: Codable, Equatable, Sendable {
    let version: Int
    var generation: UUID
    var enabled: Bool
    var defaultProfileId: String?
    var people: [SharedWidgetPerson]

    init(enabled: Bool = false) {
        version = 1
        generation = UUID()
        self.enabled = enabled
        defaultProfileId = nil
        people = []
    }
}

nonisolated struct SharedWidgetSnapshot: Codable, Sendable {
    let day: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let entryCount: Int
    let updatedAt: Double
    let calorieGoal: Double?
    let proteinGoal: Double?
    let carbsGoal: Double?
    let fatGoal: Double?

    var isValid: Bool {
        let values =
            [calories, protein, carbs, fat, updatedAt]
            + [calorieGoal, proteinGoal, carbsGoal, fatGoal].compactMap { $0 }
        return entryCount >= 0 && values.allSatisfy { $0.isFinite && $0 >= 0 }
    }

    @MainActor var dailySnapshot: DailyMacroSnapshot {
        let goals: MacroGoalsSnapshot
        if let calorieGoal, let proteinGoal, let carbsGoal, let fatGoal {
            goals = MacroGoalsSnapshot(
                calorieGoal: calorieGoal, proteinGoalGrams: proteinGoal,
                fatGoalGrams: fatGoal, carbGoalGrams: carbsGoal
            )
        } else {
            goals = .empty
        }
        return DailyMacroSnapshot(
            totals: NutritionSnapshot(calories: calories, protein: protein, fat: fat, carbs: carbs),
            goals: goals
        )
    }
}

nonisolated struct SharedWidgetPersonDay: Decodable, Sendable {
    nonisolated enum Visibility: String, Decodable, Sendable {
        case shared, notShared, paused
    }
    let visibility: Visibility
    let snapshot: SharedWidgetSnapshot?
}

nonisolated struct SharedPersonWidgetCache: Codable, Sendable {
    let snapshot: SharedWidgetSnapshot
    let fetchedAt: Date
}

nonisolated enum SharedPersonWidgetClock {
    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    static func nextMidnight(after date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))!
    }

    static func refreshDate(after date: Date, calendar: Calendar = .current) -> Date {
        min(date.addingTimeInterval(1800), nextMidnight(after: date, calendar: calendar))
    }
}
