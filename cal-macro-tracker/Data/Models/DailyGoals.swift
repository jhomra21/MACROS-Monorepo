import Foundation
import SwiftData

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
    var calorieGoal: Double
    var proteinGoalGrams: Double
    var fatGoalGrams: Double
    var carbGoalGrams: Double

    init(
        calorieGoal: Double = 2_200,
        proteinGoalGrams: Double = 160,
        fatGoalGrams: Double = 70,
        carbGoalGrams: Double = 220
    ) {
        self.calorieGoal = calorieGoal
        self.proteinGoalGrams = proteinGoalGrams
        self.fatGoalGrams = fatGoalGrams
        self.carbGoalGrams = carbGoalGrams
    }
}

struct DailyGoalsDraft: Hashable {
    var calorieGoal: Double = 2_200
    var proteinGoalGrams: Double = 160
    var fatGoalGrams: Double = 70
    var carbGoalGrams: Double = 220

    init() {}

    init(goals: DailyGoals) {
        calorieGoal = goals.calorieGoal
        proteinGoalGrams = goals.proteinGoalGrams
        fatGoalGrams = goals.fatGoalGrams
        carbGoalGrams = goals.carbGoalGrams
    }

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
    }
}
