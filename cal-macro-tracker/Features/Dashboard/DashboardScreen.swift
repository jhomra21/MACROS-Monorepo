import SwiftData
import SwiftUI

struct DashboardScreen: View {
    @Environment(AppDayContext.self) var dayContext
    @Environment(AppEntitlements.self) private var entitlements
    @Environment(SharingSyncService.self) private var sharingSyncService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(DashboardTutorial.self) var tutorial
    @AppStorage(AppStorageKeys.customProteinRingColor, store: .macroRingColors) private var customProteinRingColor =
        MacroRingColorStorage.defaultProteinHex
    @AppStorage(AppStorageKeys.customCarbRingColor, store: .macroRingColors) private var customCarbRingColor =
        MacroRingColorStorage.defaultCarbHex
    @AppStorage(AppStorageKeys.customFatRingColor, store: .macroRingColors) private var customFatRingColor =
        MacroRingColorStorage.defaultFatHex

    let cameraTransitionNamespace: Namespace.ID
    let onOpenAddFood: (CalendarDay) -> Void
    let onOpenFoodCamera: (CalendarDay) -> Void
    let onEditEntry: (LogEntry) -> Void
    let onOpenHistory: () -> Void
    let onOpenInsights: () -> Void
    let onOpenSettings: () -> Void
    let onOpenSharing: () -> Void

    @Query private var goals: [DailyGoals]

    @State var daySelection = AppDaySelection(today: CalendarDay(date: .now))
    @State private var errorMessage: String?
    @State private var logAgainFeedbackToken = 0
    @State private var deleteFeedbackToken = 0
    @State private var showsCompactSummary = false
    @State private var isAddFoodButtonCompact = false
    @State private var selectedMacro: MacroMetric?
    @State private var isMacroRingExpanded = false
    @State private var bottomBarHeight: CGFloat = 0
    #if os(iOS)
    @State var shareSheetItem: DashboardShareSheetItem?
    @State var isPreparingShare = false
    @State var shareFailureRequest: ShareFailureRequest?
    #endif

    private let compactSummaryTopPadding: CGFloat = 8
    var currentGoals: MacroGoalsSnapshot { MacroGoalsSnapshot(goals: DailyGoals.activeRecord(from: goals)) }

    private var customRingPalette: MacroRingPalette? {
        guard entitlements.canUse(.customMacroRingColors) else { return nil }
        return MacroRingColorStorage(
            proteinHex: customProteinRingColor,
            carbHex: customCarbRingColor,
            fatHex: customFatRingColor
        )
        .customPalette
    }

    var body: some View {
        LogEntryDaySnapshotReader(day: daySelection.selectedDay) { snapshot in
            let customRingPalette = customRingPalette

            ZStack(alignment: .top) {
                dashboardList(snapshot: snapshot, customRingPalette: customRingPalette)

                if daySelection.selectedDay != dayContext.today {
                    todayReturnRow
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                        .zIndex(2)
                }

                if showsCompactSummary {
                    pinnedCompactSummaryView(totals: snapshot.totals, customRingPalette: customRingPalette)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .navigationTitle("")
            .inlineNavigationTitle()
            .accessibilityHidden(tutorial.isRunning)
            .tutorialAccessibilityMask(tutorial.isRunning)
            .overlayPreferenceValue(TutorialTargetKey.self) { anchors in
                ZStack {
                    Color.clear
                        .allowsHitTesting(false)
                        .onChange(of: anchors[.ringPanel] != nil, initial: true) { _, isReady in
                            tutorial.isDashboardReady = isReady
                        }
                    if let step = tutorial.step, step != .returnFromSharing {
                        GeometryReader { safeArea in
                            GeometryReader { proxy in
                                DashboardTutorialOverlay(
                                    step: step,
                                    targetRect: step.target.flatMap { anchors[$0] }.map { proxy[$0] },
                                    size: proxy.size,
                                    safeAreaInsets: EdgeInsets(
                                        top: safeArea.safeAreaInsets.top,
                                        leading: safeArea.safeAreaInsets.leading,
                                        bottom: safeArea.safeAreaInsets.bottom + bottomBarHeight,
                                        trailing: safeArea.safeAreaInsets.trailing
                                    ),
                                    onAction: performTutorialAction
                                )
                            }
                            .ignoresSafeArea()
                        }
                    }
                }
            }
            .onChange(of: daySelection.selectedDay) { _, day in
                tutorial.didChangeDay(isToday: day == dayContext.today)
            }
            .onChange(of: isMacroRingExpanded) { _, isExpanded in
                if isExpanded { tutorial.didExpandRing() }
            }
            .onChange(of: selectedMacro) { _, metric in
                if let metric { tutorial.didSelectMacro(metric) }
            }
            .onChange(of: tutorial.step) { _, step in
                normalizeState(for: step)
            }
            .animation(.easeOut(duration: 0.18), value: showsCompactSummary)
            .onAppear {
                guard daySelection.followsCurrentDay else { return }
                daySelection.resetToToday(dayContext.today)
            }
            .onChange(of: dayContext.today) { oldToday, newToday in
                daySelection.syncToday(from: oldToday, to: newToday)
            }
            .toolbar {
                AppTopBarLeadingTitle(
                    daySelection.selectedDay.topBarTitle,
                    compactTitle: daySelection.selectedDay.dayTitle
                )
                dashboardToolbarTrailing(snapshot: snapshot)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                dashboardBottomBar
                    .onGeometryChange(for: CGFloat.self) {
                        $0.size.height
                    } action: {
                        bottomBarHeight = $0
                    }
            }
            .sensoryFeedback(.success, trigger: logAgainFeedbackToken)
            .sensoryFeedback(.impact(weight: .medium), trigger: deleteFeedbackToken)
            .sensoryFeedback(.selection, trigger: daySelection.selectedDay)
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
        LogEntryRepository(modelContext: modelContext, onDailyTotalsChanged: sharingSyncService.syncAfterDailyTotalsChange)
    }

    private var emptyLogDescription: String {
        daySelection.selectedDay.isToday
            ? "Tap the add button to log your first food today."
            : "Tap the add button to log your first food for this day."
    }

    private var dayNavigationGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                handleDaySwipe(value.translation)
            }
    }

    private var todayReturnRow: some View {
        HStack {
            Button(action: returnToToday) {
                Text("Today")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(minHeight: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .appGlassRoundedRect(cornerRadius: 18)
            .accessibilityLabel("Return to today")
            .tutorialTarget(.todayPill)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private func dashboardList(snapshot: LogEntryDaySnapshot, customRingPalette: MacroRingPalette?) -> some View {
        List {
            dashboardContent(snapshot: snapshot, customRingPalette: customRingPalette)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .scrollDisabled(tutorial.isRunning)
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
    private func dashboardContent(snapshot: LogEntryDaySnapshot, customRingPalette: MacroRingPalette?) -> some View {
        macroRows(snapshot: snapshot, customRingPalette: customRingPalette)

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
            onHeaderDayStep: handleHeaderDayStep,
            onDeleteEntry: deleteEntry,
            onEditEntry: onEditEntry,
            onLogAgain: logEntryAgain
        )
    }

    @ViewBuilder
    private func macroRows(snapshot: LogEntryDaySnapshot, customRingPalette: MacroRingPalette?) -> some View {
        MacroDashboardRingPanel(
            totals: snapshot.totals,
            goals: currentGoals,
            selectedMacro: selectedMacro,
            isExpanded: isMacroRingExpanded,
            colorStyle: customRingPalette.map(MacroRingColorStyle.custom) ?? .standard,
            onToggleExpansion: toggleMacroRingExpansion
        )
        .tutorialTarget(.ringPanel)
        .padding(.top, 8)
        .dashboardListRow(bottom: 0)
        .dashboardDaySwipe(dayNavigationGesture)

        MacroLegendView(
            totals: snapshot.totals,
            goals: currentGoals,
            selectedMacro: $selectedMacro,
            palette: customRingPalette,
            canCustomizeColors: entitlements.canUse(.customMacroRingColors),
            onChangeColor: presentColorPicker
        )
        .tutorialTarget(.legend)
        .dashboardListRow(bottom: 0)
        .dashboardDaySwipe(dayNavigationGesture)

        LoggingStreakLine(today: dayContext.today, onOpenInsights: onOpenInsights)
            .dashboardListRow(bottom: 8)

        if isMacroRingExpanded {
            SecondaryNutritionDetailsView(snapshot: snapshot.secondaryTotals)
                .padding(.top, 4)
                .dashboardListRow(bottom: 8)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
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
            try withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) {
                try logEntryRepository.delete(entry: entry, operation: "Delete dashboard entry")
            }
            errorMessage = nil
            deleteFeedbackToken += 1
        } catch {
            errorMessage = error.localizedDescription
            assertionFailure(error.localizedDescription)
        }
    }

    private func logEntryAgain(_ entry: LogEntry) {
        do {
            try withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) {
                try logEntryRepository.logAgain(
                    entry: entry,
                    loggedAt: daySelection.selectedDay.date(matchingTimeOf: .now),
                    operation: "Log food again"
                )
            }
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

        if tutorial.isRunning {
            switch tutorial.step {
            case .openSharing?:
                guard translation.width < 0 else { return }
                onOpenSharing()
            case .previousDay?:
                guard translation.width > 0 else { return }
                moveSelection(by: -1)
            default:
                break
            }
            return
        }

        if translation.width > 0 {
            moveSelection(by: -1)
        } else {
            moveSelection(by: 1)
        }
    }

    private func handleHeaderDayStep(_ offset: Int) {
        if tutorial.isRunning {
            guard tutorial.step == .previousDay, offset < 0 else { return }
        } else {
            guard offset < 0 || daySelection.selectedDay.isToday == false else { return }
        }
        moveSelection(by: offset)
    }

    private var dashboardBottomBar: some View {
        BottomPinnedDualActionBar(
            leadingAction: BottomPinnedDualAction(
                title: "Camera",
                systemImage: "camera",
                action: { onOpenFoodCamera(daySelection.selectedDay) },
                transitionSourceID: FoodCameraSheet.zoomTransitionID
            ),
            trailingAction: BottomPinnedDualAction(
                title: "Add Food",
                systemImage: "plus",
                action: { onOpenAddFood(daySelection.selectedDay) }
            ),
            transitionNamespace: cameraTransitionNamespace,
            displayMode: isAddFoodButtonCompact ? .compactIcon : .expanded,
            compactActionsAreHorizontal: true,
            topPadding: 0,
            bottomOffset: 6
        )
        .frame(maxWidth: .infinity)
        .disabled(tutorial.isRunning)
        .accessibilityHidden(tutorial.isRunning)
        .tutorialAccessibilityMask(tutorial.isRunning)
    }

    private func pinnedCompactSummaryView(totals: NutritionSnapshot, customRingPalette: MacroRingPalette?) -> some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: compactSummaryTopPadding)

            CompactMacroSummaryView(totals: totals, goals: currentGoals, ringColorPalette: customRingPalette)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .gesture(pinnedCompactSummaryDayNavigationGesture)
    }

    private func moveSelection(by dayOffset: Int) {
        guard let candidateDay = daySelection.selectedDay.advanced(byDays: dayOffset) else { return }
        guard candidateDay.startDate <= dayContext.today.startDate else {
            withAnimation(.easeInOut(duration: 0.18)) {
                daySelection.resetToToday(dayContext.today)
            }
            onOpenSharing()
            return
        }

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
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.3)) {
            isMacroRingExpanded.toggle()
        }
    }

    /// Brings private dashboard state to what the step expects, whatever the user did while it was not current.
    private func normalizeState(for step: DashboardTutorial.Step?) {
        switch step {
        case .openSharing?, .previousDay?, .expandRing?, .done?:
            if step == .openSharing || step == .previousDay { daySelection.resetToToday(dayContext.today) }
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.3)) {
                isMacroRingExpanded = false
                selectedMacro = nil
            }
        case .macros?:
            withAnimation(.easeOut(duration: 0.18)) { selectedMacro = nil }
        default:
            break
        }
    }

    private func returnToToday() {
        withAnimation(.easeInOut(duration: 0.18)) {
            daySelection.resetToToday(dayContext.today)
        }
    }

    private func performTutorialAction() {
        switch tutorial.step {
        case .openSharing?: onOpenSharing()
        case .previousDay?: moveSelection(by: -1)
        case .backToToday?: returnToToday()
        case .expandRing?: toggleMacroRingExpansion()
        case .macros?:
            withAnimation(.easeOut(duration: 0.18)) { selectedMacro = tutorial.nextMacro }
        default: break
        }
    }

    private func presentColorPicker(for metric: MacroMetric) {
        #if os(iOS)
        MacroRingColorPickerPresenter.present(for: metric, hex: hex(for: metric))
        #endif
    }

    private func hex(for metric: MacroMetric) -> Binding<String> {
        switch metric {
        case .protein:
            $customProteinRingColor
        case .carbs:
            $customCarbRingColor
        case .fat:
            $customFatRingColor
        }
    }
}

private struct TutorialAccessibilityMask: ViewModifier {
    let isRunning: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isRunning {
            content.accessibilityRepresentation { EmptyView() }
        } else {
            content
        }
    }
}

private extension View {
    func tutorialAccessibilityMask(_ isRunning: Bool) -> some View {
        modifier(TutorialAccessibilityMask(isRunning: isRunning))
    }
}
