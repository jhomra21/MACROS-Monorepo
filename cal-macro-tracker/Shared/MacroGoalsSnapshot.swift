import Foundation

struct MacroGoalsSnapshot: Hashable {
    var calorieGoal: Double
    var proteinGoalGrams: Double
    var fatGoalGrams: Double
    var carbGoalGrams: Double

    static let `default` = MacroGoalsSnapshot(
        calorieGoal: DailyGoalsDefaults.calorieGoal,
        proteinGoalGrams: DailyGoalsDefaults.proteinGoalGrams,
        fatGoalGrams: DailyGoalsDefaults.fatGoalGrams,
        carbGoalGrams: DailyGoalsDefaults.carbGoalGrams
    )

    init(
        calorieGoal: Double = DailyGoalsDefaults.calorieGoal,
        proteinGoalGrams: Double = DailyGoalsDefaults.proteinGoalGrams,
        fatGoalGrams: Double = DailyGoalsDefaults.fatGoalGrams,
        carbGoalGrams: Double = DailyGoalsDefaults.carbGoalGrams
    ) {
        self.calorieGoal = calorieGoal
        self.proteinGoalGrams = proteinGoalGrams
        self.fatGoalGrams = fatGoalGrams
        self.carbGoalGrams = carbGoalGrams
    }

    init(goals: DailyGoals?) {
        self = goals.map(\.macroGoalsSnapshot) ?? .default
    }
}

extension DailyGoals {
    var macroGoalsSnapshot: MacroGoalsSnapshot {
        MacroGoalsSnapshot(
            calorieGoal: calorieGoal,
            proteinGoalGrams: proteinGoalGrams,
            fatGoalGrams: fatGoalGrams,
            carbGoalGrams: carbGoalGrams
        )
    }
}
