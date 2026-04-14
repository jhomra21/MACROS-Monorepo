import SwiftUI

struct MacroRingView: View {
    let totals: NutritionSnapshot
    let goals: DailyGoals

    private let ringDiameter: CGFloat = 224

    var body: some View {
        MacroRingSetView(
            totals: totals,
            goals: goals.macroGoalsSnapshot,
            ringDiameter: ringDiameter,
            centerValueFontSize: 42,
            minimumLineWidth: 5,
            showsGoalSubtitle: true
        )
    }
}

struct CompactMacroRingView: View {
    let totals: NutritionSnapshot
    let goals: DailyGoals

    private let ringDiameter: CGFloat = 64

    var body: some View {
        MacroRingSetView(
            totals: totals,
            goals: goals.macroGoalsSnapshot,
            ringDiameter: ringDiameter,
            centerValueFontSize: 14,
            minimumLineWidth: 5,
            showsGoalSubtitle: false
        )
    }
}

struct WeekdayMacroRingView: View {
    let totals: NutritionSnapshot
    let goals: DailyGoals

    private let ringDiameter: CGFloat = 28

    var body: some View {
        MacroRingSetView(
            totals: totals,
            goals: goals.macroGoalsSnapshot,
            ringDiameter: ringDiameter,
            centerValueFontSize: nil,
            minimumLineWidth: 2.4,
            showsGoalSubtitle: false
        )
    }
}
