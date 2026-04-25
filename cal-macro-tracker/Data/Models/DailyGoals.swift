import Foundation
import SwiftData

enum DailyGoalsDefaults {
    static let calorieGoal = 2_200.0
    static let proteinGoalGrams = 160.0
    static let fatGoalGrams = 70.0
    static let carbGoalGrams = 220.0
}

enum DailyGoalsValidationError: LocalizedError {
    case negativeCalories
    case negativeProtein
    case negativeFat
    case negativeCarbs

    var errorDescription: String? {
        switch self {
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
        if calorieGoal < 0 {
            return .negativeCalories
        }

        if proteinGoalGrams < 0 {
            return .negativeProtein
        }

        if fatGoalGrams < 0 {
            return .negativeFat
        }

        if carbGoalGrams < 0 {
            return .negativeCarbs
        }

        return nil
    }

    func apply(to goals: DailyGoals) {
        goals.calorieGoal = calorieGoal
        goals.proteinGoalGrams = proteinGoalGrams
        goals.fatGoalGrams = fatGoalGrams
        goals.carbGoalGrams = carbGoalGrams
        goals.updatedAt = .now
    }
}
