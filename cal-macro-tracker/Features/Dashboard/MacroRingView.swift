import SwiftUI

struct MacroRingView: View {
    let totals: NutritionSnapshot
    let goals: DailyGoals

    private let proteinColor = Color.blue
    private let carbColor = Color.orange
    private let fatColor = Color.pink

    var body: some View {
        let shares = NutritionMath.macroShare(snapshot: totals)
        let calorieProgress = NutritionMath.caloriesProgress(consumed: totals.calories, goal: goals.calorieGoal)

        ZStack {
            Circle()
                .stroke(Color.black.opacity(0.06), lineWidth: 28)

            Circle()
                .trim(from: 0, to: calorieProgress)
                .stroke(
                    Color.green,
                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            macroArc(start: 0.0, end: shares.protein, color: proteinColor)
            macroArc(start: shares.protein, end: shares.protein + shares.carbs, color: carbColor)
            macroArc(start: shares.protein + shares.carbs, end: 1.0, color: fatColor)

            VStack(spacing: 4) {
                Text(totals.calories.roundedForDisplay)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                Text("of \(goals.calorieGoal.roundedForDisplay) kcal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 240, height: 240)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func macroArc(start: Double, end: Double, color: Color) -> some View {
        let clampedStart = max(0, min(start, 1))
        let clampedEnd = max(0, min(end, 1))
        let adjustedStart = clampedEnd > clampedStart ? clampedStart + 0.004 : clampedStart
        let adjustedEnd = clampedEnd > clampedStart ? clampedEnd - 0.004 : clampedEnd

        Circle()
            .trim(from: adjustedStart, to: adjustedEnd)
            .stroke(
                color,
                style: StrokeStyle(lineWidth: 28, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
    }
}
