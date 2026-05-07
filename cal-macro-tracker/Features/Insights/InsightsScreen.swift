import Charts
import SwiftData
import SwiftUI

struct InsightsScreen: View {
    @Environment(AppDayContext.self) private var dayContext

    @State private var isPresentingFullUnlock = false

    var body: some View {
        PaidFeatureGate(.nutritionInsights) {
            InsightsUnlockedContent(today: dayContext.today)
        } locked: {
            InsightsLockedPreview(isPresentingFullUnlock: $isPresentingFullUnlock)
        }
        .background(PlatformColors.groupedBackground)
        .navigationTitle("")
        .inlineNavigationTitle()
        .toolbar {
            AppTopBarLeadingTitle("Insights")
        }
        .sheet(isPresented: $isPresentingFullUnlock) {
            FullUnlockPaywallSheet()
                .presentationDetents([.medium, .large])
        }
    }
}

private struct InsightsUnlockedContent: View {
    let today: CalendarDay

    @State private var selectedRange = InsightsRange.thirtyDays

    var body: some View {
        VStack(spacing: 0) {
            rangePicker
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)

            InsightsRangeQueryContent(range: selectedRange, today: today)
        }
    }

    private var rangePicker: some View {
        Picker("Range", selection: $selectedRange) {
            ForEach(InsightsRange.allCases) { range in
                Text(range.title)
                    .tag(range)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Insights range")
    }
}

private struct InsightsRangeQueryContent: View {
    @Query private var entries: [LogEntry]
    @Query private var goals: [DailyGoals]

    let range: InsightsRange
    let today: CalendarDay

    init(range: InsightsRange, today: CalendarDay) {
        self.range = range
        self.today = today

        let currentDays = range.days(endingOn: today)
        let previousDays = range.previousDays(endingBefore: today)
        let start = previousDays.first?.startDate ?? currentDays.first?.startDate ?? today.startDate
        let end = currentDays.last?.dayInterval.end ?? today.dayInterval.end
        _entries = Query(LogEntryQuery.descriptor(start: start, end: end, order: .forward))
    }

    private var currentGoals: MacroGoalsSnapshot {
        MacroGoalsSnapshot(goals: DailyGoals.activeRecord(from: goals))
    }

    private var currentPoints: [InsightsDayPoint] {
        InsightsAnalytics.points(for: entries, days: range.days(endingOn: today))
    }

    private var previousPoints: [InsightsDayPoint] {
        InsightsAnalytics.points(for: entries, days: range.previousDays(endingBefore: today))
    }

    var body: some View {
        let currentPoints = currentPoints
        let previousPoints = previousPoints

        ScrollView {
            VStack(spacing: 16) {
                InsightsOverviewCard(
                    points: currentPoints,
                    previousPoints: previousPoints,
                    goals: currentGoals
                )

                InsightsCaloriesCard(
                    points: currentPoints,
                    previousPoints: previousPoints,
                    goals: currentGoals
                )

                InsightsMacrosCard(
                    points: currentPoints,
                    previousPoints: previousPoints,
                    goals: currentGoals
                )

                InsightsNutrientsCard(
                    points: currentPoints,
                    previousPoints: previousPoints
                )
            }
            .padding(20)
            .padding(.bottom, 32)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

private struct InsightsOverviewCard: View {
    let points: [InsightsDayPoint]
    let previousPoints: [InsightsDayPoint]
    let goals: MacroGoalsSnapshot

    private var calorieSummary: InsightsMetricSummary {
        InsightsAnalytics.metricSummary(current: points, previous: previousPoints, value: \.calories)
    }

    private var proteinSummary: InsightsMetricSummary {
        InsightsAnalytics.metricSummary(current: points, previous: previousPoints, value: \.protein)
    }

    private var calorieAdherence: InsightsGoalAdherence {
        InsightsAnalytics.calorieAdherence(in: points, calorieGoal: goals.calorieGoal)
    }

    private var proteinAdherence: InsightsGoalAdherence {
        InsightsAnalytics.proteinAdherence(in: points, proteinGoal: goals.proteinGoalGrams)
    }

    private var loggingConsistency: Double? {
        InsightsAnalytics.loggingConsistency(in: points)
    }

    var body: some View {
        InsightsCard(title: "Summary", subtitle: "Averages use days with logged foods.") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                InsightsStatTile(
                    title: "Avg Calories",
                    value: calorieSummary.average.insightsFormattedValue(unit: "kcal"),
                    detail: calorieSummary.comparisonPercent.insightsComparisonText
                )
                InsightsStatTile(
                    title: "Avg Protein",
                    value: proteinSummary.average.insightsFormattedValue(unit: "g"),
                    detail: proteinSummary.comparisonPercent.insightsComparisonText
                )
                InsightsStatTile(
                    title: "Logged Days",
                    value: "\(calorieSummary.loggedDayCount)/\(calorieSummary.totalDayCount)",
                    detail: loggingConsistency.insightsPercentText
                )
                InsightsStatTile(
                    title: "Calorie Target",
                    value: calorieAdherence.insightsRateText,
                    detail: "Within ±10%"
                )
                InsightsStatTile(
                    title: "Protein Goal",
                    value: proteinAdherence.insightsRateText,
                    detail: "At least \(goals.proteinGoalGrams.roundedForDisplay)g"
                )
            }
        }
    }
}

private struct InsightsCaloriesCard: View {
    let points: [InsightsDayPoint]
    let previousPoints: [InsightsDayPoint]
    let goals: MacroGoalsSnapshot

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
        points.indexedForCharts()
    }

    var body: some View {
        InsightsCard(title: "Calories", subtitle: "Daily totals compared with your current goal range.") {
            InsightsChartHeader(
                primary: summary.average.insightsFormattedValue(unit: "kcal avg"),
                secondary: summary.comparisonPercent.insightsComparisonText,
                chartStyle: $chartStyle
            )

            selectedPoint.map { point in
                InsightsSelectedValueLabel(
                    title: point.day.dayTitle,
                    value: point.snapshot.totals.calories.insightsFormattedValue(unit: "kcal")
                )
            }

            Chart {
                ForEach(indexedPoints) { point in
                    switch chartStyle {
                    case .bars:
                        BarMark(
                            x: .value("Day", point.index),
                            y: .value("Calories", animatedValue(point.snapshot.totals.calories))
                        )
                        .foregroundStyle(Color.accentColor.gradient)
                    case .lines:
                        LineMark(
                            x: .value("Day", point.index),
                            y: .value("Calories", animatedValue(point.snapshot.totals.calories))
                        )
                        .foregroundStyle(Color.accentColor)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Day", point.index),
                            y: .value("Calories", animatedValue(point.snapshot.totals.calories))
                        )
                        .foregroundStyle(Color.accentColor)
                    }
                }
                RuleMark(y: .value("Goal", goals.calorieGoal))
                    .foregroundStyle(.secondary.opacity(0.7))
                    .lineStyle(.init(lineWidth: 1, dash: [4, 4]))
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let index = value.as(Int.self), let point = indexedPoints[safe: index] {
                            Text(point.day.startDate.formatted(.dateTime.month(.abbreviated).day()))
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var chartStyle = InsightsChartStyle.bars
    @State private var selectedIndex: Int?
    @State private var hasAnimatedIn = false

    private var proteinSummary: InsightsMetricSummary {
        InsightsAnalytics.metricSummary(current: points, previous: previousPoints, value: \.protein)
    }

    private var indexedPoints: [InsightsIndexedPoint] {
        points.indexedForCharts()
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
        InsightsCard(title: "Macros", subtitle: "Composition and protein consistency across logged days.") {
            InsightsChartHeader(
                primary: proteinSummary.average.insightsFormattedValue(unit: "g protein avg"),
                secondary: InsightsAnalytics.proteinAdherence(in: points, proteinGoal: goals.proteinGoalGrams).insightsRateText,
                chartStyle: $chartStyle
            )

            selectedPoint.map { point in
                InsightsSelectedValueLabel(
                    title: point.day.dayTitle,
                    value:
                        "P \(point.snapshot.totals.protein.roundedForDisplay)g • C \(point.snapshot.totals.carbs.roundedForDisplay)g • F \(point.snapshot.totals.fat.roundedForDisplay)g"
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
                AxisMarks(values: .automatic(desiredCount: 6)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let index = value.as(Int.self), let point = indexedPoints[safe: index] {
                            Text(point.day.startDate.formatted(.dateTime.month(.abbreviated).day()))
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedNutrient = InsightsNutrient.fiber
    @State private var chartStyle = InsightsChartStyle.bars
    @State private var selectedIndex: Int?
    @State private var hasAnimatedIn = false

    private var summary: InsightsNutrientSummary {
        InsightsAnalytics.nutrientSummary(current: points, previous: previousPoints, nutrient: selectedNutrient)
    }

    private var indexedPoints: [InsightsIndexedPoint] {
        points.indexedForCharts()
    }

    private var selectedPoint: InsightsIndexedPoint? {
        indexedPoints[safe: selectedIndex]
    }

    var body: some View {
        InsightsCard(title: "Nutrients", subtitle: coverageText) {
            Picker("Nutrient", selection: $selectedNutrient) {
                ForEach(InsightsNutrient.allCases) { nutrient in
                    Text(nutrient.shortTitle)
                        .tag(nutrient)
                }
            }
            .pickerStyle(.menu)

            InsightsChartHeader(
                primary: summary.average.insightsFormattedValue(unit: selectedNutrient.unit),
                secondary: summary.comparisonPercent.insightsComparisonText,
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
                    selectedNutrient.value(from: point.snapshot.secondaryTotals).map { value in
                        InsightsSelectedValueLabel(
                            title: point.day.dayTitle,
                            value: value.insightsFormattedValue(unit: selectedNutrient.unit)
                        )
                    }
                }

                Chart(indexedPoints) { point in
                    let value = selectedNutrient.value(from: point.snapshot.secondaryTotals)

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
                    AxisMarks(values: .automatic(desiredCount: 6)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let index = value.as(Int.self), let point = indexedPoints[safe: index] {
                                Text(point.day.startDate.formatted(.dateTime.month(.abbreviated).day()))
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
    let secondary: String
    @Binding var chartStyle: InsightsChartStyle

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(primary)
                    .font(.title3.weight(.semibold))
                Text(secondary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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

private struct InsightsLockedPreview: View {
    @Binding var isPresentingFullUnlock: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 10) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                    Text("Unlock Nutrition Insights")
                        .font(.title2.weight(.bold))
                    Text("See monthly calorie, macro, and nutrient trends with goal adherence and previous-period comparisons.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 28)

                VStack(spacing: 12) {
                    InsightsPreviewChart(title: "Calories", color: .accentColor)
                    InsightsPreviewChart(title: "Macros", color: .orange)
                    InsightsPreviewChart(title: "Nutrients", color: .green)
                }
                .blur(radius: 1.5)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

                AppAccentActionButton(title: "Unlock Insights", systemImage: "lock.open.fill", isCompact: false) {
                    isPresentingFullUnlock = true
                }
            }
            .padding(20)
            .padding(.bottom, 32)
        }
    }
}

private struct InsightsPreviewChart: View {
    let title: String
    let color: Color

    private let values: [Double] = [0.35, 0.62, 0.48, 0.78, 0.57, 0.86, 0.66]

    var body: some View {
        InsightsCard(title: title, subtitle: "Premium trend preview") {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(color.gradient)
                        .frame(height: 110 * value)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .bottom)
        }
    }
}

private struct InsightsIndexedPoint: Identifiable {
    let index: Int
    let day: CalendarDay
    let snapshot: LogEntryDaySnapshot

    var id: Int { index }
}

private struct InsightsMacroSegment: Identifiable {
    let point: InsightsIndexedPoint
    let metric: MacroMetric

    var id: String { "\(point.index)-\(metric.title)" }
    var value: Double { metric.value(from: point.snapshot.totals) }
}

private extension [InsightsDayPoint] {
    func indexedForCharts() -> [InsightsIndexedPoint] {
        enumerated().map { index, point in
            InsightsIndexedPoint(index: index, day: point.day, snapshot: point.snapshot)
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
