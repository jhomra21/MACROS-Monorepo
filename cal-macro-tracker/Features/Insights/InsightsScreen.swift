import SwiftData
import SwiftUI

struct InsightsScreen: View {
    @Environment(AppDayContext.self) private var dayContext

    @State private var isPresentingPro = false
    @State private var isPresentingWeightTrendsPro = false

    var body: some View {
        PaidFeatureGate(.nutritionInsights) {
            InsightsUnlockedContent(
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
                    Menu {
                        ForEach(InsightsRange.allCases) { range in
                            Button {
                                if range != .sevenDays {
                                    isPresentingPro = true
                                }
                            } label: {
                                Label(
                                    range.title,
                                    systemImage: range == .sevenDays ? "checkmark" : "lock.fill"
                                )
                            }
                        }
                    } label: {
                        Label("7D", systemImage: "chevron.down")
                            .frame(maxWidth: .infinity)
                    }
                    .accessibilityLabel("Insights range, 7D selected. Other ranges require Pro.")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    InsightsRangeQueryContent(range: .sevenDays, today: dayContext.today, isPresentingPro: $isPresentingPro)
                }
            }
        }
        .background(PlatformColors.groupedBackground)
        .navigationTitle("Insights")
        .inlineNavigationTitle()
        .sheet(isPresented: $isPresentingPro) {
            ProPaywallSheet(context: .insights)
        }
        .sheet(isPresented: $isPresentingWeightTrendsPro) {
            ProPaywallSheet(context: .weightTrends)
        }
    }
}

private struct InsightsUnlockedContent: View {
    let today: CalendarDay
    @Binding var isPresentingWeightTrendsPro: Bool

    @State private var selectedRange = InsightsRange.thirtyDays

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                rangePicker
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                InsightsWeightCard(
                    range: selectedRange,
                    today: today,
                    isPresentingPro: $isPresentingWeightTrendsPro
                )
                InsightsRangeQueryContent(range: selectedRange, today: today)
            }
        }
    }

    private var rangePicker: some View {
        HStack {
            Text("Range")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Picker("Range", selection: $selectedRange) {
                ForEach(InsightsRange.allCases) { range in
                    Text(range.title)
                        .tag(range)
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel("Insights range")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
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
        let bucket = InsightsAnalytics.chartBucket(for: range, points: currentPoints)
        let chartPoints = InsightsAnalytics.chartPoints(
            for: currentPoints,
            bucket: bucket
        )
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
                        chartPoints: chartPoints,
                        bucket: bucket
                    )

                    InsightsMacrosCard(
                        points: currentPoints,
                        previousPoints: comparisons,
                        goals: currentGoals,
                        chartPoints: chartPoints,
                        bucket: bucket
                    )

                    InsightsNutrientsCard(
                        points: currentPoints,
                        previousPoints: comparisons,
                        chartPoints: chartPoints,
                        bucket: bucket
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
