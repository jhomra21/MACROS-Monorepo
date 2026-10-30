import SwiftData
import SwiftUI

struct InsightsScreen: View {
    @Query private var latestWeightEntries: [WeightEntry]
    @Environment(AppDayContext.self) private var dayContext
    @Environment(AppEntitlements.self) private var entitlements

    @AppStorage(AppStorageKeys.insightsSelectedRange)
    private var selectedRangeRawValue = InsightsRange.sevenDays.rawValue
    @AppStorage(AppStorageKeys.insightsWeightNoticeDismissedAt)
    private var weightNoticeDismissedAt = 0.0
    @State private var isPresentingPro = false
    @State private var isPresentingWeightTrendsPro = false

    init() {
        var descriptor = FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\WeightEntry.recordedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        _latestWeightEntries = Query(descriptor)
    }

    var body: some View {
        Group {
            PaidFeatureGate(.nutritionInsights) {
                InsightsUnlockedContent(
                    selectedRange: selectedRange,
                    today: dayContext.today,
                    isPresentingWeightTrendsPro: $isPresentingWeightTrendsPro
                )
            } locked: {
                ScrollView {
                    VStack(spacing: 0) {
                        InsightsWeightCard(
                            range: .sevenDays,
                            today: dayContext.today,
                            isPresentingPro: $isPresentingWeightTrendsPro
                        )
                        InsightsRangeQueryContent(range: .sevenDays, today: dayContext.today, isPresentingPro: $isPresentingPro)
                    }
                }
            }
        }
        .background(PlatformColors.groupedBackground)
        .navigationTitle("Insights")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                rangeMenu
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let message = noWeightMessage {
                noWeightNotice(message: message)
                    .accessibilityElement(children: .contain)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
            }
        }
        .sheet(isPresented: $isPresentingPro) {
            ProPaywallSheet(context: .insights)
        }
        .sheet(isPresented: $isPresentingWeightTrendsPro) {
            ProPaywallSheet(context: .weightTrends)
        }
    }

    private var selectedRange: Binding<InsightsRange> {
        Binding(
            get: { InsightsRange(rawValue: selectedRangeRawValue) ?? .sevenDays },
            set: { selectedRangeRawValue = $0.rawValue }
        )
    }

    private var effectiveRange: InsightsRange {
        entitlements.canUse(.nutritionInsights) ? selectedRange.wrappedValue : .sevenDays
    }

    private var rangeMenu: some View {
        Menu {
            if entitlements.canUse(.nutritionInsights) {
                Picker("Insights range", selection: selectedRange) {
                    ForEach(InsightsRange.allCases) { range in
                        Text(range.displayTitle)
                            .tag(range)
                    }
                }
                .pickerStyle(.inline)
            } else {
                ForEach(InsightsRange.allCases) { range in
                    Button {
                        if range != .sevenDays {
                            isPresentingPro = true
                        }
                    } label: {
                        Label(range.displayTitle, systemImage: range == .sevenDays ? "checkmark" : "lock.fill")
                            .labelStyle(.titleAndIcon)
                    }
                    .accessibilityLabel(range.displayTitle)
                    .accessibilityValue(range == .sevenDays ? "Selected" : "Requires Pro")
                    .accessibilityHint(range == .sevenDays ? "Current range" : "Opens the Pro paywall")
                }
            }
        } label: {
            rangeMenuLabel
        }
        .menuIndicator(.hidden)
        .accessibilityLabel("Insights range")
        .accessibilityValue("\(effectiveRange.displayTitle) selected")
        .accessibilityHint(entitlements.canUse(.nutritionInsights) ? "Choose a date range" : "Other ranges require Pro")
        .frame(minHeight: 44)
        .contentShape(Capsule())
        .menuStyle(.button)
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Capsule())
    }

    private var rangeMenuLabel: some View {
        HStack(spacing: 6) {
            Text(effectiveRange.displayTitle)
                .fixedSize(horizontal: true, vertical: true)
            Image(systemName: "chevron.down")
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .contentShape(Rectangle().inset(by: -6))
    }

    private func noWeightNotice(message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "scalemass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(message)
                    .font(.subheadline.weight(.medium))
                NavigationLink("View weight log") {
                    WeightScreen()
                }
                .font(.subheadline)
                .frame(minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
                .accessibilityHint("Opens your weight log")
            }
            Spacer(minLength: 0)
            Button {
                weightNoticeDismissedAt = dayContext.today.startDate.timeIntervalSince1970
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss weight notice")
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(InsightsWeightNoticeStyle())
    }

    private var noWeightMessage: String? {
        InsightsWeightNotice.message(
            latestWeightDate: latestWeightEntries.first?.recordedAt,
            today: dayContext.today,
            dismissedAt: weightNoticeDismissedAt.isFinite && weightNoticeDismissedAt > 0
                ? Date(timeIntervalSince1970: weightNoticeDismissedAt)
                : nil
        )
    }
}

private struct InsightsUnlockedContent: View {
    @Binding var selectedRange: InsightsRange
    let today: CalendarDay
    @Binding var isPresentingWeightTrendsPro: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                InsightsWeightCard(
                    range: selectedRange,
                    today: today,
                    isPresentingPro: $isPresentingWeightTrendsPro
                )
                InsightsRangeQueryContent(range: selectedRange, today: today)
            }
        }
    }
}

private struct InsightsWeightNoticeStyle: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 20))
        } else {
            content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
    }
}

private extension InsightsRange {
    var displayTitle: String {
        switch self {
        case .sevenDays: "7 days"
        case .fourteenDays: "14 days"
        case .thirtyDays: "30 days"
        case .ninetyDays: "90 days"
        case .oneYear: "1 year"
        case .allTime: "All time"
        }
    }
}

private struct InsightsRangeQueryContent: View {
    let range: InsightsRange
    let today: CalendarDay
    var isPresentingPro: Binding<Bool>?

    init(range: InsightsRange, today: CalendarDay, isPresentingPro: Binding<Bool>? = nil) {
        self.range = range
        self.today = today
        self.isPresentingPro = isPresentingPro
    }

    @ViewBuilder
    var body: some View {
        if range == .allTime {
            InsightsAllTimeRangeQueryContent(today: today, isPresentingPro: isPresentingPro)
        } else {
            InsightsRangeQueryResults(range: range, today: today, isPresentingPro: isPresentingPro)
        }
    }
}

private struct InsightsAllTimeRangeQueryContent: View {
    @Query private var earliestEntries: [LogEntry]

    let today: CalendarDay
    var isPresentingPro: Binding<Bool>?

    init(today: CalendarDay, isPresentingPro: Binding<Bool>?) {
        self.today = today
        self.isPresentingPro = isPresentingPro
        var descriptor = FetchDescriptor<LogEntry>(sortBy: [SortDescriptor(\LogEntry.dateLogged)])
        descriptor.fetchLimit = 1
        _earliestEntries = Query(descriptor)
    }

    @ViewBuilder
    var body: some View {
        if let earliestEntry = earliestEntries.first {
            InsightsRangeQueryResults(
                range: .allTime,
                today: today,
                startingAt: CalendarDay(date: earliestEntry.dateLogged, calendar: today.resolvedCalendar),
                isPresentingPro: isPresentingPro
            )
        } else {
            ContentUnavailableView("No entries yet", systemImage: "chart.bar.xaxis")
                .padding(20)
        }
    }
}

private struct InsightsRangeQueryResults: View {
    @Query private var entries: [LogEntry]
    @Query private var goals: [DailyGoals]

    let range: InsightsRange
    let today: CalendarDay
    let startingAt: CalendarDay?
    var isPresentingPro: Binding<Bool>?

    init(
        range: InsightsRange,
        today: CalendarDay,
        startingAt: CalendarDay? = nil,
        isPresentingPro: Binding<Bool>? = nil
    ) {
        self.isPresentingPro = isPresentingPro
        self.range = range
        self.today = today
        self.startingAt = startingAt
        let currentDays = range.days(endingOn: today, startingAt: startingAt)
        let previousDays = range.previousDays(endingBefore: today)
        let start = previousDays.first?.startDate ?? currentDays.first?.startDate ?? today.startDate
        let end = currentDays.last?.dayInterval.end ?? today.dayInterval.end
        _entries = Query(LogEntryQuery.descriptor(start: start, end: end, order: .forward))
    }

    private var currentGoals: MacroGoalsSnapshot {
        MacroGoalsSnapshot(goals: DailyGoals.activeRecord(from: goals))
    }

    private var currentPoints: [InsightsDayPoint] {
        InsightsAnalytics.points(for: entries, days: range.days(endingOn: today, startingAt: startingAt))
    }

    private var previousPoints: [InsightsDayPoint] {
        InsightsAnalytics.points(for: entries, days: range.previousDays(endingBefore: today))
    }

    var body: some View {
        let currentPoints = currentPoints
        let previousPoints = previousPoints
        let chartPoints = InsightsAnalytics.chartPoints(for: currentPoints)
        let comparisons = range == .allTime ? [] : previousPoints

        VStack(spacing: 16) {
            InsightsSummaryTiles(
                points: currentPoints,
                previousPoints: comparisons,
                showsComparison: range != .allTime
            )

            ZStack(alignment: .top) {
                VStack(spacing: 16) {
                    InsightsCaloriesCard(
                        points: currentPoints,
                        previousPoints: comparisons,
                        goals: currentGoals,
                        chartPoints: chartPoints
                    )

                    InsightsMacrosCard(
                        points: currentPoints,
                        previousPoints: comparisons,
                        goals: currentGoals,
                        chartPoints: chartPoints
                    )

                    InsightsNutrientsCard(
                        points: currentPoints,
                        previousPoints: comparisons,
                        chartPoints: chartPoints
                    )
                }
                .blur(radius: isPresentingPro == nil ? 0 : 6)
                .allowsHitTesting(isPresentingPro == nil)
                .accessibilityHidden(isPresentingPro != nil)

                if let isPresentingPro {
                    VStack(spacing: 12) {
                        Text("Unlock Insights")
                            .font(.title2.bold())
                        Text("Explore your calorie, macro, and nutrient trends.")
                            .multilineTextAlignment(.center)
                        Text("Included with \(AppBrand.displayName) Pro")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        AppAccentActionButton(title: "Unlock Insights", systemImage: "lock.open.fill", isCompact: false) {
                            isPresentingPro.wrappedValue = true
                        }
                    }
                    .padding(24)
                    .background(PlatformColors.groupedBackground, in: RoundedRectangle(cornerRadius: 24))
                    .padding(.top, 40)
                }
            }
        }
        .padding(20)
        .padding(.bottom, 32)
    }
}

private struct InsightsSummaryTiles: View {
    let points: [InsightsDayPoint]
    let previousPoints: [InsightsDayPoint]
    let showsComparison: Bool

    private var summaries: [InsightsSummaryTileModel] {
        [
            InsightsSummaryTileModel(
                title: "Avg Calories",
                value: InsightsAnalytics.metricSummary(current: points, previous: previousPoints, value: \.calories),
                unit: "kcal"
            )
        ]
            + MacroMetric.allCases.map { metric in
                InsightsSummaryTileModel(
                    title: "Avg \(metric.title)",
                    value: InsightsAnalytics.metricSummary(
                        current: points,
                        previous: previousPoints,
                        value: { metric.value(from: $0) }
                    ),
                    unit: "g"
                )
            }
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(summaries) { summary in
                InsightsStatTile(
                    title: summary.title,
                    value: summary.value.average.insightsFormattedValue(unit: summary.unit),
                    detail: showsComparison ? summary.value.comparisonPercent.insightsComparisonText : nil
                )
            }
        }
    }
}

private struct InsightsSummaryTileModel: Identifiable {
    let title: String
    let value: InsightsMetricSummary
    let unit: String

    var id: String { title }
}
