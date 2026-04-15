import Foundation

struct MacroGoalsSnapshot: Hashable {
    var calorieGoal: Double
    var proteinGoalGrams: Double
    var fatGoalGrams: Double
    var carbGoalGrams: Double

    static let `default` = MacroGoalsSnapshot(
        calorieGoal: 2_200,
        proteinGoalGrams: 160,
        fatGoalGrams: 70,
        carbGoalGrams: 220
    )

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
