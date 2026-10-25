import Foundation

extension GoalSex {
    var title: String {
        switch self {
        case .female: "Female"
        case .male: "Male"
        case .unspecified: "Unspecified"
        }
    }
}

extension GoalActivityLevel {
    var title: String {
        switch self {
        case .sedentary: "Sedentary"
        case .light: "Light"
        case .moderate: "Moderate"
        case .active: "Active"
        case .veryActive: "Very active"
        }
    }

    var description: String {
        switch self {
        case .sedentary: "Mostly sitting, little planned exercise"
        case .light: "Light exercise 1–3 days per week"
        case .moderate: "Moderate exercise 3–5 days per week"
        case .active: "Hard exercise 6–7 days per week"
        case .veryActive: "Very hard training or a physical job"
        }
    }

    fileprivate var multiplier: Double {
        switch self {
        case .sedentary: 1.2
        case .light: 1.375
        case .moderate: 1.55
        case .active: 1.725
        case .veryActive: 1.9
        }
    }
}

extension GoalMacroPreset {
    var title: String {
        switch self {
        case .balanced: "Balanced"
        case .highProtein: "High protein"
        case .lowCarb: "Low carb"
        case .custom: "Custom"
        }
    }

    var proteinPercent: Double {
        switch self {
        case .balanced: 30
        case .highProtein: 40
        case .lowCarb: 35
        case .custom: 0
        }
    }

    var carbPercent: Double {
        switch self {
        case .balanced: 40
        case .highProtein: 30
        case .lowCarb: 20
        case .custom: 0
        }
    }

    var fatPercent: Double {
        switch self {
        case .balanced: 30
        case .highProtein: 30
        case .lowCarb: 45
        case .custom: 0
        }
    }
}

enum GoalCalculatorError: LocalizedError {
    case invalidAge
    case invalidMeasurement
    case invalidCalories
    case unsupportedMacroPreset

    var errorDescription: String? {
        switch self {
        case .invalidAge: "Enter an age from 1 to 120."
        case .invalidMeasurement: "Height and weight must be positive finite numbers."
        case .invalidCalories: "Calories must be a positive finite number."
        case .unsupportedMacroPreset: "Choose a supported macro preset."
        }
    }
}

struct GoalCalorieTarget: Equatable {
    let calories: Double
    let isBelowSafeMinimum: Bool
}

enum GoalCalculator {
    static func bmr(sex: GoalSex, ageYears: Int, heightCm: Double, weightKg: Double) throws -> Double {
        guard (1...120).contains(ageYears) else { throw GoalCalculatorError.invalidAge }
        guard heightCm.isFinite, weightKg.isFinite, heightCm > 0, weightKg > 0 else {
            throw GoalCalculatorError.invalidMeasurement
        }

        let sexConstant: Double =
            switch sex {
            case .female: -161
            case .male: 5
            case .unspecified: (-161 + 5) / 2
            }
        let result = 10 * weightKg + 6.25 * heightCm - 5 * Double(ageYears) + sexConstant
        guard result.isFinite, result > 0 else { throw GoalCalculatorError.invalidMeasurement }
        return result
    }

    static func tdee(bmr: Double, activity: GoalActivityLevel) throws -> Double {
        guard bmr.isFinite, bmr > 0 else { throw GoalCalculatorError.invalidMeasurement }
        let result = bmr * activity.multiplier
        guard result.isFinite else { throw GoalCalculatorError.invalidMeasurement }
        return result
    }

    static func targetCalories(tdee: Double, offset: Double, sex: GoalSex) throws -> GoalCalorieTarget {
        guard
            tdee.isFinite,
            offset.isFinite,
            tdee > 0,
            (-750...500).contains(offset)
        else {
            throw GoalCalculatorError.invalidCalories
        }
        let minimum = sex == .male ? 1_500.0 : 1_200.0
        let requestedCalories = tdee + offset
        guard requestedCalories.isFinite else { throw GoalCalculatorError.invalidCalories }
        return GoalCalorieTarget(
            calories: max(minimum, requestedCalories),
            isBelowSafeMinimum: requestedCalories < minimum
        )
    }

    static func macroGrams(calories: Double, preset: GoalMacroPreset) throws -> DailyGoalsDraft {
        guard calories.isFinite, calories > 0 else { throw GoalCalculatorError.invalidCalories }
        guard preset != .custom else { throw GoalCalculatorError.unsupportedMacroPreset }

        let protein = roundedToFive(calories * preset.proteinPercent / 100 / 4)
        let carbs = roundedToFive(calories * preset.carbPercent / 100 / 4)
        let fat = roundedToFive(calories * preset.fatPercent / 100 / 9)
        guard protein.isFinite, carbs.isFinite, fat.isFinite else { throw GoalCalculatorError.invalidCalories }
        var draft = DailyGoalsDraft()
        draft.proteinGoalGrams = protein
        draft.carbGoalGrams = carbs
        draft.fatGoalGrams = fat
        draft.calorieGoal = protein * 4 + carbs * 4 + fat * 9
        return draft
    }

    static func kg(fromPounds pounds: Double) throws -> Double {
        guard pounds.isFinite, pounds > 0 else { throw GoalCalculatorError.invalidMeasurement }
        return (pounds / 2.20462 * 10).rounded() / 10
    }

    static func pounds(fromKg kilograms: Double) -> Double {
        (kilograms * 2.20462).rounded()
    }

    static func cm(fromFeet feet: Int, inches: Double) throws -> Double {
        guard feet >= 0, inches.isFinite, inches >= 0, inches < 12, feet > 0 || inches > 0 else {
            throw GoalCalculatorError.invalidMeasurement
        }
        return ((Double(feet * 12) + inches) * 2.54).rounded()
    }

    static func feetAndInches(fromCm centimeters: Double) -> (feet: Int, inches: Double) {
        let totalInches = (centimeters / 2.54).rounded()
        let feet = Int(totalInches / 12)
        return (feet, totalInches - Double(feet * 12))
    }

    private static func roundedToFive(_ value: Double) -> Double {
        (value / 5).rounded() * 5
    }
}
