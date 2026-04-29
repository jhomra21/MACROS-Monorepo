import SwiftData
import SwiftUI

struct DashboardScreen: View {
    @Environment(AppDayContext.self) var dayContext
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) var colorScheme

    let resetToTodayToken: Int
    let onOpenAddFood: (CalendarDay) -> Void
    let onEditEntry: (LogEntry) -> Void
    let onOpenHistory: () -> Void
    let onOpenSettings: () -> Void

    @Query private var goals: [DailyGoals]

    @State var daySelection = AppDaySelection(today: CalendarDay(date: .now))
    @State private var errorMessage: String?
    @State private var logAgainFeedbackToken = 0
    @State private var deleteFeedbackToken = 0
    @State private var showsCompactSummary = false
    @State private var isAddFoodButtonCompact = false
    @State private var selectedMacro: MacroMetric?
    @State private var isMacroRingExpanded = false
    #if os(iOS)
    @State var shareSheetItem: DashboardShareSheetItem?
    @State var isPreparingShare = false
    @State var shareFailureRequest: ShareFailureRequest?
    #endif

    private let compactSummaryTopPadding: CGFloat = 8
    var currentGoals: MacroGoalsSnapshot {
        MacroGoalsSnapshot(goals: DailyGoals.activeRecord(from: goals))
    }

    var body: some View {
        LogEntryDaySnapshotReader(day: daySelection.selectedDay) { snapshot in
            ZStack(alignment: .top) {
                dashboardList(snapshot: snapshot)

                if daySelection.selectedDay != dayContext.today {
                    todayReturnRow
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .zIndex(2)
                }

                if showsCompactSummary {
                    pinnedCompactSummaryView(totals: snapshot.totals)
                        .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                        .zIndex(1)
                }
            }
            .navigationTitle("")
            .inlineNavigationTitle()
            .animation(.easeOut(duration: 0.18), value: showsCompactSummary)
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
                dashboardToolbarLeading
                dashboardToolbarTrailing(snapshot: snapshot)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                dashboardBottomBar
            }
            .sensoryFeedback(.success, trigger: logAgainFeedbackToken)
            .sensoryFeedback(.impact(weight: .medium), trigger: deleteFeedbackToken)
            .errorBanner(message: $errorMessage)
            #if os(iOS)
            .sheet(item: $shareSheetItem) { item in
                ShareSheet(itemSource: item.itemSource)
            }
            .alert(item: $shareFailureRequest) { request in
                Alert(
                    title: Text("Something went wrong sharing."),
                    primaryButton: .default(Text("Retry")) {
                        prepareShare(day: request.day, snapshot: request.snapshot)
                    },
                    secondaryButton: .cancel()
                )
            }
            #endif
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

    private var dashboardNavigationTitle: String {
        daySelection.selectedDay.topBarTitle
    }

    private var dashboardToolbarLeading: some ToolbarContent {
        ToolbarItem(placement: .appTopBarLeading) {
            Text(dashboardNavigationTitle)
                .appTopBarTitleStyle()
        }
        .sharedBackgroundVisibility(.hidden)
    }

    private var dayNavigationGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                handleDaySwipe(value.translation)
            }
    }

    private var todayReturnRow: some View {
        HStack {
            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    daySelection.resetToToday(dayContext.today)
                }
            } label: {
                Text("Today")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .appGlassRoundedRect(cornerRadius: 18)
            .accessibilityLabel("Return to today")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private func dashboardList(snapshot: LogEntryDaySnapshot) -> some View {
        List {
            dashboardContent(snapshot: snapshot)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .contentMargins(.top, 0, for: .scrollContent)
        .background(PlatformColors.groupedBackground)
        .onScrollGeometryChange(for: CGFloat.self) { scrollGeometry in
            max(0, scrollGeometry.contentOffset.y)
        } action: { _, newOffset in
            updateCompactSummaryVisibility(for: newOffset)
            updateAddFoodButtonDisplay(for: newOffset)
        }
    }

    @ViewBuilder
    private func dashboardContent(snapshot: LogEntryDaySnapshot) -> some View {
        macroRows(snapshot: snapshot)

        LogEntryListSection(
            title: daySelection.selectedDay.dayTitle,
            emptyTitle: "No food logged yet",
            emptySystemImage: "fork.knife.circle",
            emptyDescription: emptyLogDescription,
            entries: snapshot.entries,
            emptyVerticalPadding: 12,
            emptyStyle: .plain,
            layout: .list,
            onHeaderSwipeTranslation: handleDaySwipe,
            onDeleteEntry: deleteEntry,
            onEditEntry: onEditEntry,
            onLogAgain: logEntryAgain
        )
    }

    @ViewBuilder
    private func macroRows(snapshot: LogEntryDaySnapshot) -> some View {
        MacroDashboardRingPanel(
            totals: snapshot.totals,
            goals: currentGoals,
            selectedMacro: selectedMacro,
            isExpanded: isMacroRingExpanded,
            onToggleExpansion: toggleMacroRingExpansion
        )
        .dashboardListRow(bottom: 0)
        .dashboardDaySwipe(dayNavigationGesture)

        MacroLegendView(totals: snapshot.totals, goals: currentGoals, selectedMacro: $selectedMacro)
            .dashboardListRow(bottom: 0)
            .dashboardDaySwipe(dayNavigationGesture)

        if isMacroRingExpanded {
            SecondaryNutritionDetailsView(snapshot: snapshot.secondaryTotals)
                .padding(.top, 4)
                .dashboardListRow(bottom: 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .dashboardDaySwipe(dayNavigationGesture)
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
        BottomPinnedActionBar(
            title: "Add Food",
            systemImage: "plus",
            isDisabled: false,
            displayMode: isAddFoodButtonCompact ? .compactIcon : .expanded,
            topPadding: 0
        ) {
            onOpenAddFood(daySelection.selectedDay)
        }
        .frame(maxWidth: .infinity)
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
        let shouldShowCompactSummary = offset > visibilityThreshold
        guard shouldShowCompactSummary != showsCompactSummary else { return }

        showsCompactSummary = shouldShowCompactSummary
    }

    private func updateAddFoodButtonDisplay(for offset: CGFloat) {
        let compactThreshold: CGFloat = isAddFoodButtonCompact ? 2 : 12
        let shouldCompact = offset > compactThreshold
        guard shouldCompact != isAddFoodButtonCompact else { return }

        withAnimation(.smooth(duration: 0.22)) {
            isAddFoodButtonCompact = shouldCompact
        }
    }

    private func toggleMacroRingExpansion() {
        withAnimation(.easeOut(duration: 0.18)) {
            isMacroRingExpanded.toggle()
        }
    }

}
