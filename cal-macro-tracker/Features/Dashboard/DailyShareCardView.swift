import SwiftUI

struct DailyShareCardView: View {
    let day: CalendarDay
    let snapshot: LogEntryDaySnapshot
    let goals: MacroGoalsSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header

            MacroRingView(totals: snapshot.totals, goals: goals, ringDiameter: 252)
                .frame(maxWidth: .infinity)

            macroSummary

            SecondaryNutritionDetailsView(snapshot: snapshot.secondaryTotals)
                .padding(.top, 8)

            footer
        }
        .padding(8)
        .frame(width: 390, alignment: .topLeading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Daily Summary")
                .font(.title2.weight(.semibold))

            Text(day.startDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year()))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var macroSummary: some View {
        HStack(spacing: 10) {
            ForEach(MacroMetric.allCases) { metric in
                MacroSummaryColumnView(
                    metric: metric,
                    totals: snapshot.totals,
                    goals: goals,
                    alignment: .center,
                    titleStyle: .full,
                    style: .dashboardCard
                )
            }
        }
    }

    private var footer: some View {
        HStack {
            Spacer()

            Text("MACROS")
                .font(.caption.weight(.semibold))
                .tracking(1.6)
                .foregroundStyle(.secondary.opacity(0.72))
        }
    }
}

// Temporary preview: remove after share-card visual testing is complete.
// It intentionally keeps representative sample data close to the temporary review surface.
#Preview("Daily Share Card - temporary") {
    DailyShareCardView(
        day: CalendarDay(date: .now),
        snapshot: LogEntryDaySnapshot(
            entries: [],
            totals: NutritionSnapshot(calories: 1840, protein: 132, fat: 58, carbs: 196),
            secondaryTotals: SecondaryNutritionSnapshot(
                saturatedFat: 18,
                fiber: 24,
                sugars: 52,
                addedSugars: nil,
                sodium: 1820,
                cholesterol: 140
            )
        ),
        goals: MacroGoalsSnapshot(
            calorieGoal: 2200,
            proteinGoalGrams: 160,
            fatGoalGrams: 70,
            carbGoalGrams: 240
        )
    )
    .padding()
    .background(PlatformColors.groupedBackground)
    .preferredColorScheme(.dark)
}
