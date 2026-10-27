import Charts
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

private struct InsightsCaloriesCard: View {
    let points: [InsightsDayPoint]
    let previousPoints: [InsightsDayPoint]
    let goals: MacroGoalsSnapshot
    let chartPoints: [InsightsChartPoint]
    let bucket: InsightsChartBucket

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var chartStyle = InsightsChartStyle.bars
    @State private var selectedIndex: Int?
    @State private var hasAnimatedIn = false

    private var summary: InsightsMetricSummary {
        InsightsAnalytics.metricSummary(current: points, previous: previousPoints, value: \.calories)
    }

    private var selectedPoint: InsightsIndexedPoint? {
        indexedPoints[safe: selectedIndex]
    }

    private var indexedPoints: [InsightsIndexedPoint] {
        chartPoints.indexedForCharts()
    }

    private var axisLabelIndices: [Int] {
        indexedPoints.axisLabelIndices
    }

    var body: some View {
        InsightsCard(title: "Calories", subtitle: "Calories compared with your current goal range. \(bucket.averageLabel).") {
            InsightsChartHeader(
                primary: summary.average.insightsFormattedValue(unit: "kcal avg"),
                secondary: previousPoints.isEmpty ? nil : summary.comparisonPercent.insightsComparisonText,
                chartStyle: $chartStyle
            )

            selectedPoint.map { point in
                InsightsSelectedValueLabel(
                    title: point.day.chartLabel(for: bucket),
                    value: point.totals.calories.insightsFormattedValue(unit: "kcal")
                )
            }

            Chart {
                ForEach(indexedPoints) { point in
                    switch chartStyle {
                    case .bars:
                        BarMark(
                            x: .value("Day", point.index),
                            y: .value("Calories", animatedValue(point.totals.calories))
                        )
                        .foregroundStyle(Color.accentColor.gradient)
                    case .lines:
                        LineMark(
                            x: .value("Day", point.index),
                            y: .value("Calories", animatedValue(point.totals.calories))
                        )
                        .foregroundStyle(Color.accentColor)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Day", point.index),
                            y: .value("Calories", animatedValue(point.totals.calories))
                        )
                        .foregroundStyle(Color.accentColor)
                    }
                }
                RuleMark(y: .value("Goal", goals.calorieGoal))
                    .foregroundStyle(.secondary.opacity(0.7))
                    .lineStyle(.init(lineWidth: 1, dash: [4, 4]))
            }
            .chartXAxis {
                AxisMarks(values: axisLabelIndices) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let index = value.as(Int.self), let point = indexedPoints[safe: index] {
                            Text(point.day.chartLabel(for: bucket))
                        }
                    }
                }
            }
            .chartXSelection(value: $selectedIndex)
            .frame(height: 220)
            .accessibilityLabel("Calories chart")
            .onAppear {
                guard !hasAnimatedIn else { return }
                withAnimation(reduceMotion ? .easeOut(duration: 0.16) : .easeOut(duration: 0.28)) {
                    hasAnimatedIn = true
                }
            }
        }
    }

    private func animatedValue(_ value: Double) -> Double {
        reduceMotion || hasAnimatedIn ? value : 0
    }
}

private struct InsightsMacrosCard: View {
    let points: [InsightsDayPoint]
    let previousPoints: [InsightsDayPoint]
    let goals: MacroGoalsSnapshot
    let chartPoints: [InsightsChartPoint]
    let bucket: InsightsChartBucket

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var chartStyle = InsightsChartStyle.bars
    @State private var selectedIndex: Int?
    @State private var hasAnimatedIn = false

    private var proteinSummary: InsightsMetricSummary {
        InsightsAnalytics.metricSummary(current: points, previous: previousPoints, value: \.protein)
    }

    private var indexedPoints: [InsightsIndexedPoint] {
        chartPoints.indexedForCharts()
    }

    private var axisLabelIndices: [Int] {
        indexedPoints.axisLabelIndices
    }

    private var macroSegments: [InsightsMacroSegment] {
        indexedPoints.flatMap { point in
            MacroMetric.allCases.map { metric in
                InsightsMacroSegment(point: point, metric: metric)
            }
        }
    }

    private var selectedPoint: InsightsIndexedPoint? {
        indexedPoints[safe: selectedIndex]
    }

    var body: some View {
        InsightsCard(title: "Macros", subtitle: "Composition and protein consistency. \(bucket.averageLabel).") {
            InsightsChartHeader(
                primary: proteinSummary.average.insightsFormattedValue(unit: "g protein avg"),
                secondary: InsightsAnalytics.proteinAdherence(in: points, proteinGoal: goals.proteinGoalGrams).insightsRateText,
                chartStyle: $chartStyle
            )

            selectedPoint.map { point in
                InsightsSelectedValueLabel(
                    title: point.day.chartLabel(for: bucket),
                    value:
                        "P \(point.totals.protein.roundedForDisplay)g • C \(point.totals.carbs.roundedForDisplay)g • F \(point.totals.fat.roundedForDisplay)g"
                )
            }

            Chart {
                switch chartStyle {
                case .bars:
                    ForEach(macroSegments) { segment in
                        BarMark(
                            x: .value("Day", segment.point.index),
                            y: .value("Grams", animatedValue(segment.value))
                        )
                        .foregroundStyle(by: .value("Macro", segment.metric.title))
                    }
                case .lines:
                    ForEach(macroSegments) { segment in
                        LineMark(
                            x: .value("Day", segment.point.index),
                            y: .value("Grams", animatedValue(segment.value))
                        )
                        .foregroundStyle(by: .value("Macro", segment.metric.title))
                        .interpolationMethod(.catmullRom)
                    }
                }
            }
            .chartForegroundStyleScale([
                MacroMetric.protein.title: MacroMetric.protein.accentColor,
                MacroMetric.carbs.title: MacroMetric.carbs.accentColor,
                MacroMetric.fat.title: MacroMetric.fat.accentColor
            ])
            .chartXAxis {
                AxisMarks(values: axisLabelIndices) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let index = value.as(Int.self), let point = indexedPoints[safe: index] {
                            Text(point.day.chartLabel(for: bucket))
                        }
                    }
                }
            }
            .chartXSelection(value: $selectedIndex)
            .frame(height: 240)
            .accessibilityLabel("Macros chart")
            .onAppear {
                guard !hasAnimatedIn else { return }
                withAnimation(reduceMotion ? .easeOut(duration: 0.16) : .easeOut(duration: 0.28)) {
                    hasAnimatedIn = true
                }
            }
        }
    }

    private func animatedValue(_ value: Double) -> Double {
        reduceMotion || hasAnimatedIn ? value : 0
    }
}

private struct InsightsNutrientsCard: View {
    let points: [InsightsDayPoint]
    let previousPoints: [InsightsDayPoint]
    let chartPoints: [InsightsChartPoint]
    let bucket: InsightsChartBucket

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedNutrient = InsightsNutrient.fiber
    @State private var chartStyle = InsightsChartStyle.bars
    @State private var selectedIndex: Int?
    @State private var hasAnimatedIn = false

    private var summary: InsightsNutrientSummary {
        InsightsAnalytics.nutrientSummary(current: points, previous: previousPoints, nutrient: selectedNutrient)
    }

    private var indexedPoints: [InsightsIndexedPoint] {
        chartPoints.indexedForCharts()
    }

    private var axisLabelIndices: [Int] {
        indexedPoints.axisLabelIndices
    }

    private var selectedPoint: InsightsIndexedPoint? {
        indexedPoints[safe: selectedIndex]
    }

    var body: some View {
        InsightsCard(title: "Nutrients", subtitle: "\(coverageText) \(bucket.averageLabel).") {
            Picker("Nutrient", selection: $selectedNutrient) {
                ForEach(InsightsNutrient.allCases) { nutrient in
                    Text(nutrient.shortTitle)
                        .tag(nutrient)
                }
            }
            .pickerStyle(.menu)

            InsightsChartHeader(
                primary: summary.average.insightsFormattedValue(unit: selectedNutrient.unit),
                secondary: previousPoints.isEmpty ? nil : summary.comparisonPercent.insightsComparisonText,
                chartStyle: $chartStyle
            )

            if summary.availableDayCount == 0 {
                ContentUnavailableView(
                    "No \(selectedNutrient.title) Data",
                    systemImage: "chart.bar.xaxis",
                    description: Text("Logged foods in this range do not include \(selectedNutrient.title.lowercased()) values.")
                )
                .frame(minHeight: 180)
            } else {
                selectedPoint.flatMap { point in
                    selectedNutrient.value(from: point.secondaryTotals).map { value in
                        InsightsSelectedValueLabel(
                            title: point.day.chartLabel(for: bucket),
                            value: value.insightsFormattedValue(unit: selectedNutrient.unit)
                        )
                    }
                }

                Chart(indexedPoints) { point in
                    let value = selectedNutrient.value(from: point.secondaryTotals)

                    switch chartStyle {
                    case .bars:
                        BarMark(
                            x: .value("Day", point.index),
                            y: .value(selectedNutrient.title, animatedValue(value ?? 0))
                        )
                        .foregroundStyle(Color.green.gradient)
                        .opacity(value == nil ? 0.18 : 1)
                    case .lines:
                        if let value {
                            LineMark(
                                x: .value("Day", point.index),
                                y: .value(selectedNutrient.title, animatedValue(value))
                            )
                            .foregroundStyle(Color.green)
                            .interpolationMethod(.catmullRom)

                            PointMark(
                                x: .value("Day", point.index),
                                y: .value(selectedNutrient.title, animatedValue(value))
                            )
                            .foregroundStyle(Color.green)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: axisLabelIndices) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let index = value.as(Int.self), let point = indexedPoints[safe: index] {
                                Text(point.day.chartLabel(for: bucket))
                            }
                        }
                    }
                }
                .chartXSelection(value: $selectedIndex)
                .frame(height: 220)
                .accessibilityLabel("\(selectedNutrient.title) chart")
            }
        }
        .onAppear {
            guard !hasAnimatedIn else { return }
            withAnimation(reduceMotion ? .easeOut(duration: 0.16) : .easeOut(duration: 0.28)) {
                hasAnimatedIn = true
            }
        }
    }

    private var coverageText: String {
        "\(selectedNutrient.title) data available on \(summary.availableDayCount)/\(summary.loggedDayCount) logged days."
    }

    private func animatedValue(_ value: Double) -> Double {
        reduceMotion || hasAnimatedIn ? value : 0
    }
}

private struct InsightsCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appGlassRoundedRect(cornerRadius: 24, interactive: false)
    }
}

private struct InsightsChartHeader: View {
    let primary: String
    let secondary: String?
    @Binding var chartStyle: InsightsChartStyle

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(primary)
                    .font(.title3.weight(.semibold))
                if let secondary {
                    Text(secondary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Picker("Chart style", selection: $chartStyle) {
                ForEach(InsightsChartStyle.allCases) { style in
                    Text(style.title)
                        .tag(style)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 148)
        }
    }
}

private struct InsightsStatTile: View {
    let title: String
    let value: String
    let detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appGlassRoundedRect(cornerRadius: 16, interactive: false)
    }
}

private struct InsightsSelectedValueLabel: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.08), in: Capsule())
    }
}

private struct InsightsIndexedPoint: Identifiable {
    let index: Int
    let day: CalendarDay
    let totals: NutritionSnapshot
    let secondaryTotals: SecondaryNutritionSnapshot

    var id: Int { index }
}

private struct InsightsMacroSegment: Identifiable {
    let point: InsightsIndexedPoint
    let metric: MacroMetric

    var id: String { "\(point.index)-\(metric.title)" }
    var value: Double { metric.value(from: point.totals) }
}

private extension [InsightsChartPoint] {
    func indexedForCharts() -> [InsightsIndexedPoint] {
        enumerated().map { index, point in
            InsightsIndexedPoint(
                index: index,
                day: point.day,
                totals: point.totals,
                secondaryTotals: point.secondaryTotals
            )
        }
    }
}

private extension [InsightsIndexedPoint] {
    var axisLabelIndices: [Int] {
        let interval = Swift.max(1, Int(ceil(Double(count) / 6)))
        return stride(from: 0, to: count, by: interval).map { $0 }
    }
}

private extension InsightsChartBucket {
    var averageLabel: String {
        switch self {
        case .daily: "Daily totals"
        case .weekly: "Weekly avg"
        case .monthly: "Monthly avg"
        }
    }
}

private extension CalendarDay {
    func chartLabel(for bucket: InsightsChartBucket) -> String {
        switch bucket {
        case .daily:
            startDate.formatted(.dateTime.month(.abbreviated).day())
        case .weekly:
            "Wk of \(startDate.formatted(.dateTime.month(.abbreviated).day()))"
        case .monthly:
            startDate.formatted(.dateTime.month(.abbreviated).year(.twoDigits))
        }
    }
}

private extension Array {
    subscript(safe index: Int?) -> Element? {
        guard let index, indices.contains(index) else { return nil }
        return self[index]
    }
}

private extension Optional where Wrapped == Double {
    func insightsFormattedValue(unit: String) -> String {
        guard let self else { return "No data" }
        return self.insightsFormattedValue(unit: unit)
    }

    var insightsComparisonText: String {
        guard let self else { return "No previous comparison" }
        if self == 0 {
            return "No change vs previous"
        }

        let sign = self > 0 ? "+" : ""
        return "\(sign)\(self.roundedForDisplay)% vs previous"
    }

    var insightsPercentText: String {
        guard let self else { return "No data" }
        return "\(Int((self * 100).rounded()))%"
    }
}

private extension Double {
    func insightsFormattedValue(unit: String) -> String {
        "\(roundedForDisplay) \(unit)"
    }
}

private extension InsightsGoalAdherence {
    var insightsRateText: String {
        guard loggedDayCount > 0 else { return "No data" }
        return "\(successfulDays)/\(loggedDayCount)"
    }
}
