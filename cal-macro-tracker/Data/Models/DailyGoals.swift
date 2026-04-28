import Foundation
import SwiftData

enum DailyGoalsDefaults {
    static let calorieGoal = 2_200.0
    static let proteinGoalGrams = 160.0
    static let fatGoalGrams = 70.0
    static let carbGoalGrams = 220.0
}

enum DailyGoalsValidationError: LocalizedError {
    case invalidCalories
    case invalidProtein
    case invalidFat
    case invalidCarbs
    case negativeCalories
    case negativeProtein
    case negativeFat
    case negativeCarbs

    var errorDescription: String? {
        switch self {
        case .invalidCalories:
            "Calorie goal must be a finite number."
        case .invalidProtein:
            "Protein goal must be a finite number."
        case .invalidFat:
            "Fat goal must be a finite number."
        case .invalidCarbs:
            "Carb goal must be a finite number."
        case .negativeCalories:
            "Calorie goal cannot be negative."
        case .negativeProtein:
            "Protein goal cannot be negative."
        case .negativeFat:
            "Fat goal cannot be negative."
        case .negativeCarbs:
            "Carb goal cannot be negative."
        }
    }
}

@Model
final class DailyGoals {
    var id: UUID = UUID()
    var calorieGoal: Double
    var proteinGoalGrams: Double
    var fatGoalGrams: Double
    var carbGoalGrams: Double
    var createdAt: Date = Foundation.Date()
    var updatedAt: Date = Foundation.Date()

    init(
        id: UUID = UUID(),
        calorieGoal: Double = DailyGoalsDefaults.calorieGoal,
        proteinGoalGrams: Double = DailyGoalsDefaults.proteinGoalGrams,
        fatGoalGrams: Double = DailyGoalsDefaults.fatGoalGrams,
        carbGoalGrams: Double = DailyGoalsDefaults.carbGoalGrams,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.calorieGoal = calorieGoal
        self.proteinGoalGrams = proteinGoalGrams
        self.fatGoalGrams = fatGoalGrams
        self.carbGoalGrams = carbGoalGrams
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension DailyGoals {
    static func activeRecord(from goals: [DailyGoals]) -> DailyGoals? {
        goals.max(by: isOrderedBeforeActiveRecord(_:_:))
    }

    private static func isOrderedBeforeActiveRecord(_ lhs: DailyGoals, _ rhs: DailyGoals) -> Bool {
        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt < rhs.updatedAt
        }

        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }
}

struct DailyGoalsDraft: Hashable {
    var calorieGoal: Double = DailyGoalsDefaults.calorieGoal
    var proteinGoalGrams: Double = DailyGoalsDefaults.proteinGoalGrams
    var fatGoalGrams: Double = DailyGoalsDefaults.fatGoalGrams
    var carbGoalGrams: Double = DailyGoalsDefaults.carbGoalGrams

    init() {}

    var isValid: Bool {
        validationError == nil
    }

    var validationError: DailyGoalsValidationError? {
        validationError(for: calorieGoal, invalidError: .invalidCalories, negativeError: .negativeCalories)
            ?? validationError(for: proteinGoalGrams, invalidError: .invalidProtein, negativeError: .negativeProtein)
            ?? validationError(for: fatGoalGrams, invalidError: .invalidFat, negativeError: .negativeFat)
            ?? validationError(for: carbGoalGrams, invalidError: .invalidCarbs, negativeError: .negativeCarbs)
    }

    func apply(to goals: DailyGoals) {
        goals.calorieGoal = calorieGoal
        goals.proteinGoalGrams = proteinGoalGrams
        goals.fatGoalGrams = fatGoalGrams
        goals.carbGoalGrams = carbGoalGrams
        goals.updatedAt = .now
    }

    private func validationError(
        for value: Double,
        invalidError: DailyGoalsValidationError,
        negativeError: DailyGoalsValidationError
    ) -> DailyGoalsValidationError? {
        guard value.isFinite else { return invalidError }
        return value < 0 ? negativeError : nil
    }
}
