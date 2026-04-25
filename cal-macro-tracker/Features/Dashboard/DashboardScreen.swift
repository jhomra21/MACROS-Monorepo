import SwiftData
import SwiftUI

struct DashboardScreen: View {
    @Environment(AppDayContext.self) private var dayContext
    @Environment(\.modelContext) private var modelContext

    let resetToTodayToken: Int
    let onOpenAddFood: (CalendarDay) -> Void
    let onEditEntry: (LogEntry) -> Void
    let onOpenHistory: () -> Void
    let onOpenSettings: () -> Void

    @Query private var goals: [DailyGoals]

    @State private var daySelection = AppDaySelection(today: CalendarDay(date: .now))
    @State private var errorMessage: String?
    @State private var logAgainFeedbackToken = 0
    @State private var deleteFeedbackToken = 0
    @State private var showsCompactSummary = false

    private let compactSummaryTopPadding: CGFloat = 8

    private var currentGoals: MacroGoalsSnapshot {
        MacroGoalsSnapshot(goals: DailyGoals.activeRecord(from: goals))
    }

    var body: some View {
        LogEntryDaySnapshotReader(day: daySelection.selectedDay) { snapshot in
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
                    .dashboardDaySwipe(dayNavigationGesture)

                    MacroLegendView(totals: snapshot.totals, goals: currentGoals)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .dashboardDaySwipe(dayNavigationGesture)

                    LogEntryListSection(
                        title: daySelection.selectedDay.dayTitle,
                        emptyTitle: "No food logged yet",
                        emptySystemImage: "fork.knife.circle",
                        emptyDescription: emptyLogDescription,
                        entries: snapshot.entries,
                        emptyVerticalPadding: 24,
                        layout: .list,
                        onHeaderSwipeTranslation: handleDaySwipe,
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
                    pinnedCompactSummaryView(totals: snapshot.totals)
                        .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                }
            }
            .navigationTitle(daySelection.selectedDay.historyNavigationTitle)
            .inlineNavigationTitle()
            .animation(.easeInOut(duration: 0.2), value: showsCompactSummary)
            .onAppear {
                guard daySelection.followsCurrentDay else { return }
                daySelection.resetToToday(dayContext.today)
            }
            .onChange(of: dayContext.today) { oldToday, newToday in
                daySelection.syncToday(from: oldToday, to: newToday)
            }
            .onChange(of: resetToTodayToken) { _, _ in
                withAnimation(.easeInOut(duration: 0.18)) {
                    daySelection.resetToToday(dayContext.today)
                }
            }
            .toolbar {
                if daySelection.selectedDay != dayContext.today {
                    ToolbarItem(placement: .appTopBarTrailing) {
                        Button("Today") {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                daySelection.resetToToday(dayContext.today)
                            }
                        }
                    }
                }

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
                dashboardBottomBar
            }
            .sensoryFeedback(.success, trigger: logAgainFeedbackToken)
            .sensoryFeedback(.impact(weight: .medium), trigger: deleteFeedbackToken)
            .errorBanner(message: $errorMessage)
        }
    }

    private var logEntryRepository: LogEntryRepository {
        LogEntryRepository(modelContext: modelContext)
    }

    private var emptyLogDescription: String {
        if daySelection.selectedDay.isToday {
            return "Tap the add button to log your first food today."
        }

        return "Tap the add button to log your first food for this day."
    }

    private var dayNavigationGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                handleDaySwipe(value.translation)
            }
    }

    private var pinnedCompactSummaryDayNavigationGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                guard showsCompactSummary else { return }
                handleDaySwipe(value.translation)
            }
    }

    private func deleteEntry(_ entry: LogEntry) {
        do {
            try logEntryRepository.delete(entry: entry, operation: "Delete dashboard entry")
            errorMessage = nil
            deleteFeedbackToken += 1
        } catch {
            errorMessage = error.localizedDescription
            assertionFailure(error.localizedDescription)
        }
    }

    private func logEntryAgain(_ entry: LogEntry) {
        do {
            try logEntryRepository.logAgain(
                entry: entry,
                loggedAt: daySelection.selectedDay.date(matchingTimeOf: .now),
                operation: "Log food again"
            )
            errorMessage = nil
            logAgainFeedbackToken += 1
        } catch {
            errorMessage = error.localizedDescription
            assertionFailure(error.localizedDescription)
        }
    }

    private func handleDaySwipe(_ translation: CGSize) {
        let horizontalThreshold: CGFloat = 70
        guard abs(translation.width) > abs(translation.height), abs(translation.width) >= horizontalThreshold else {
            return
        }

        if translation.width > 0 {
            moveSelection(by: -1)
        } else {
            moveSelection(by: 1)
        }
    }

    private var dashboardBottomBar: some View {
        BottomPinnedActionBar(title: "Add Food", systemImage: "plus", isDisabled: false) {
            onOpenAddFood(daySelection.selectedDay)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .simultaneousGesture(dayNavigationGesture)
    }

    private func pinnedCompactSummaryView(totals: NutritionSnapshot) -> some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: compactSummaryTopPadding)

            CompactMacroSummaryView(totals: totals, goals: currentGoals)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .gesture(pinnedCompactSummaryDayNavigationGesture)
    }

    private func moveSelection(by dayOffset: Int) {
        guard let candidateDay = daySelection.selectedDay.advanced(byDays: dayOffset) else { return }

        withAnimation(.easeInOut(duration: 0.18)) {
            daySelection.select(candidateDay, today: dayContext.today)
        }
    }

    private func updateCompactSummaryVisibility(for offset: CGFloat) {
        let visibilityThreshold: CGFloat = showsCompactSummary ? 180 : 220
        showsCompactSummary = offset > visibilityThreshold
    }
}

private extension View {
    func dashboardDaySwipe<G: Gesture>(_ gesture: G) -> some View {
        contentShape(Rectangle())
            .simultaneousGesture(gesture)
    }
}

private struct MacroLegendView: View {
    let totals: NutritionSnapshot
    let goals: MacroGoalsSnapshot

    var body: some View {
        HStack(spacing: 24) {
            ForEach(MacroMetric.allCases) { metric in
                legendCard(metric: metric)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func legendCard(metric: MacroMetric) -> some View {
        MacroSummaryColumnView(
            metric: metric,
            totals: totals,
            goals: goals,
            alignment: .center,
            titleStyle: .full,
            style: .dashboardCard
        )
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
