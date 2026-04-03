import SwiftData
import SwiftUI

struct DashboardScreen: View {
    @Query(sort: \FoodItem.name) private var foods: [FoodItem]
    @Query private var goals: [DailyGoals]

    @State private var showingAddFood = false

    private var currentGoals: DailyGoals {
        goals.first ?? DailyGoals()
    }

    var body: some View {
        LogEntryDaySnapshotReader(date: .now) { snapshot in
            ScrollView {
                VStack(spacing: 24) {
                    MacroRingView(totals: snapshot.totals, goals: currentGoals)

                    MacroLegendView(totals: snapshot.totals, goals: currentGoals)

                    LogEntryListSection(
                        title: "Today",
                        emptyTitle: "No food logged yet",
                        emptySystemImage: "fork.knife.circle",
                        emptyDescription: "Tap the add button to log your first food today.",
                        entries: snapshot.entries,
                        emptyVerticalPadding: 24
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }
            .background(PlatformColors.groupedBackground)
            .safeAreaInset(edge: .bottom) {
                BottomPinnedActionBar(title: "Add Food", systemImage: "plus", isDisabled: false) {
                    showingAddFood = true
                }
            }
            .navigationTitle("Calories")
            .toolbar {
                ToolbarItemGroup(placement: .appTopBarTrailing) {
                    NavigationLink {
                        HistoryScreen()
                    } label: {
                        Image(systemName: "calendar")
                    }

                    NavigationLink {
                        SettingsScreen()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .largeNavigationTitle()
            .sheet(isPresented: $showingAddFood) {
                NavigationStack {
                    AddFoodScreen(logDate: .now, foods: foods)
                }
            }
        }
    }
}

private struct MacroLegendView: View {
    let totals: NutritionSnapshot
    let goals: DailyGoals

    var body: some View {
        HStack(spacing: 12) {
            legendCard(title: "Protein", value: totals.protein, goal: goals.proteinGoalGrams, color: .blue)
            legendCard(title: "Carbs", value: totals.carbs, goal: goals.carbGoalGrams, color: .orange)
            legendCard(title: "Fat", value: totals.fat, goal: goals.fatGoalGrams, color: .pink)
        }
    }

    private func legendCard(title: String, value: Double, goal: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                Text(title)
                    .font(.subheadline.weight(.medium))
            }

            Text("\(value.roundedForDisplay)g")
                .font(.title3.weight(.semibold))
                .monospacedDigit()

            Text("Goal \(goal.roundedForDisplay)g")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(PlatformColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.foodName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(entry.quantitySummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text("\(entry.caloriesConsumed.roundedForDisplay) kcal")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                Text("P \(entry.proteinConsumed.roundedForDisplay) • C \(entry.carbsConsumed.roundedForDisplay) • F \(entry.fatConsumed.roundedForDisplay)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(PlatformColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
