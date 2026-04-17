import SwiftData
import SwiftUI

struct DashboardScreen: View {
    @Environment(AppDayContext.self) private var dayContext
    @Environment(\.modelContext) private var modelContext

    let onOpenAddFood: () -> Void
    let onEditEntry: (LogEntry) -> Void
    let onOpenHistory: () -> Void
    let onOpenSettings: () -> Void

    @Query private var goals: [DailyGoals]

    @State private var errorMessage: String?
    @State private var logAgainFeedbackToken = 0
    @State private var deleteFeedbackToken = 0
    @State private var showsCompactSummary = false

    private var currentGoals: DailyGoals {
        goals.first ?? DailyGoals()
    }

    var body: some View {
        LogEntryDaySnapshotReader(day: dayContext.today) { snapshot in
            ZStack(alignment: .top) {
                List {
                    HStack {
                        Spacer(minLength: 0)
                        MacroRingView(totals: snapshot.totals, goals: currentGoals)
                        Spacer(minLength: 0)
                    }
                    .padding(.bottom, 20)
                    .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 0, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    MacroLegendView(totals: snapshot.totals, goals: currentGoals)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    LogEntryListSection(
                        title: "Today",
                        emptyTitle: "No food logged yet",
                        emptySystemImage: "fork.knife.circle",
                        emptyDescription: "Tap the add button to log your first food today.",
                        entries: snapshot.entries,
                        emptyVerticalPadding: 24,
                        layout: .list,
                        onDeleteEntry: deleteEntry,
                        onEditEntry: onEditEntry,
                        onLogAgain: logEntryAgain
                    )
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(PlatformColors.groupedBackground)
                .onScrollGeometryChange(for: CGFloat.self) { scrollGeometry in
                    max(0, scrollGeometry.contentOffset.y)
                } action: { _, newOffset in
                    updateCompactSummaryVisibility(for: newOffset)
                }

                if showsCompactSummary {
                    CompactMacroSummaryView(totals: snapshot.totals, goals: currentGoals)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                        .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                }
            }
            .navigationTitle(dayContext.today.historyNavigationTitle)
            .inlineNavigationTitle()
            .animation(.easeInOut(duration: 0.2), value: showsCompactSummary)
            .toolbar {
                ToolbarItem(placement: .appTopBarTrailing) {
                    Button(action: onOpenHistory) {
                        Image(systemName: "calendar")
                            .font(.title3.weight(.semibold))
                    }
                    .accessibilityLabel("Open history")
                }

                ToolbarItem(placement: .appTopBarTrailing) {
                    Button(action: onOpenSettings) {
                        Image(systemName: "gearshape")
                            .font(.title3.weight(.semibold))
                    }
                    .accessibilityLabel("Open settings")
                }
            }
            .safeAreaInset(edge: .bottom) {
                BottomPinnedActionBar(title: "Add Food", systemImage: "plus", isDisabled: false) {
                    onOpenAddFood()
                }
            }
            .sensoryFeedback(.success, trigger: logAgainFeedbackToken)
            .sensoryFeedback(.impact(weight: .medium), trigger: deleteFeedbackToken)
            .errorBanner(message: $errorMessage)
        }
    }

    private var logEntryRepository: LogEntryRepository {
        LogEntryRepository(modelContext: modelContext)
    }

    private func deleteEntry(_ entry: LogEntry) {
        do {
            try logEntryRepository.delete(entry: entry, operation: "Delete today entry")
            errorMessage = nil
            deleteFeedbackToken += 1
        } catch {
            errorMessage = error.localizedDescription
            assertionFailure(error.localizedDescription)
        }
    }

    private func logEntryAgain(_ entry: LogEntry) {
        do {
            try logEntryRepository.logAgain(entry: entry, operation: "Log food again")
            errorMessage = nil
            logAgainFeedbackToken += 1
        } catch {
            errorMessage = error.localizedDescription
            assertionFailure(error.localizedDescription)
        }
    }

    private func updateCompactSummaryVisibility(for offset: CGFloat) {
        let visibilityThreshold: CGFloat = showsCompactSummary ? 180 : 220
        showsCompactSummary = offset > visibilityThreshold
    }
}

private struct MacroLegendView: View {
    let totals: NutritionSnapshot
    let goals: DailyGoals

    private var goalSnapshot: MacroGoalsSnapshot {
        MacroGoalsSnapshot(goals: goals)
    }

    var body: some View {
        HStack(spacing: 24) {
            ForEach(MacroMetric.allCases) { metric in
                legendCard(metric: metric)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func legendCard(metric: MacroMetric) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(metric.accentColor)
                    .frame(width: 10, height: 10)
                Text(metric.title)
                    .font(.subheadline.weight(.medium))
            }

            Text("\(metric.value(from: totals).roundedForDisplay)g")
                .font(.title3.weight(.semibold))
                .monospacedDigit()

            Text("Goal \(metric.goal(from: goalSnapshot).roundedForDisplay)g")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
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
                Text("\(entry.quantitySummary) • \(entry.dateLogged.timeTitle)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text("\(entry.caloriesConsumed.roundedForDisplay) kcal")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                Text(
                    "P \(entry.proteinConsumed.roundedForDisplay) • C \(entry.carbsConsumed.roundedForDisplay) • F \(entry.fatConsumed.roundedForDisplay)"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 16)
    }
}
