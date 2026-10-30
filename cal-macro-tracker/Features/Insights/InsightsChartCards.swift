import Charts
import SwiftUI

extension [InsightsDayPoint] {
    /// Date span for chart accessibility values, e.g. "Oct 1 to Oct 7".
    fileprivate var chartRangeDescription: String {
        guard let first, let last else { return "No days" }
        return "\(first.day.chartLabel) to \(last.day.chartLabel)"
    }
}

struct InsightsCaloriesCard: View {
    let points: [InsightsDayPoint]
    let previousPoints: [InsightsDayPoint]
    let goals: MacroGoalsSnapshot
    let chartPoints: [InsightsChartPoint]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var chartStyle = InsightsChartStyle.bars
    @State private var selectedIndex: Double?

    private var summary: InsightsMetricSummary {
        InsightsAnalytics.metricSummary(current: points, previous: previousPoints, value: \.calories)
    }

    private var selectedPoint: InsightsIndexedPoint? {
        guard let selectedIndex = chartAxis.selectedDayIndex(for: selectedIndex) else { return nil }
        return indexedPoints.first { $0.index == selectedIndex }
    }

    private var indexedPoints: [InsightsIndexedPoint] {
        chartPoints.indexedForCharts(startingAt: chartStartDay)
    }

    private var axisLabelIndices: [Double] {
        chartAxis.labelIndices.map(Double.init)
    }

    private var chartStartDay: CalendarDay? {
        points.first?.day
    }

    private var chartAxis: InsightsChartAxis {
        InsightsChartAxis(dayCount: points.count)
    }

    var body: some View {
        InsightsCard(title: "Calories", subtitle: "Calories compared with your goal range.") {
            InsightsChartHeader(
                primary: summary.average.insightsFormattedValue(unit: "kcal avg"),
                secondary: previousPoints.isEmpty ? nil : summary.comparisonPercent.insightsComparisonText,
                chartStyle: $chartStyle
            )

            selectedPoint.map { point in
                InsightsSelectedValueLabel(
                    title: point.day.chartLabel,
                    value: point.totals.calories.insightsFormattedValue(unit: "kcal")
                )
            }

            Chart {
                ForEach(indexedPoints) { point in
                    switch chartStyle {
                    case .bars:
                        BarMark(
                            x: .value("Day", Double(point.index)),
                            y: .value("Calories", point.totals.calories)
                        )
                        .foregroundStyle(Color.accentColor.gradient)
                    case .lines:
                        LineMark(
                            x: .value("Day", Double(point.index)),
                            y: .value("Calories", point.totals.calories)
                        )
                        .foregroundStyle(Color.accentColor)
                        .interpolationMethod(.linear)

                        PointMark(
                            x: .value("Day", Double(point.index)),
                            y: .value("Calories", point.totals.calories)
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
                    AxisValueLabel(collisionResolution: .disabled) {
                        if let index = value.as(Double.self),
                            let day = chartStartDay?.advanced(byDays: Int(index))
                        {
                            Text(day.chartAxisLabel(inRangeFrom: chartStartDay, through: points.last?.day))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .insightsDailyChartXScale(dayCount: points.count)
            .chartGesture { proxy in
                SpatialTapGesture()
                    .onEnded { value in
                        selectedIndex = proxy.value(atX: value.location.x, as: Double.self)
                    }
            }
            .frame(height: 220)
            .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: points.map(\.day))
            .accessibilityLabel("Calories chart")
            .accessibilityValue(
                "\(summary.average.insightsFormattedValue(unit: "kcal avg")), \(points.chartRangeDescription)"
            )
            .onChange(of: points.map(\.day)) {
                selectedIndex = nil
            }
        }
    }
}

struct InsightsMacrosCard: View {
    let points: [InsightsDayPoint]
    let previousPoints: [InsightsDayPoint]
    let goals: MacroGoalsSnapshot
    let chartPoints: [InsightsChartPoint]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var chartStyle = InsightsChartStyle.bars
    @State private var selectedIndex: Double?

    private var proteinSummary: InsightsMetricSummary {
        InsightsAnalytics.metricSummary(current: points, previous: previousPoints, value: \.protein)
    }

    private var indexedPoints: [InsightsIndexedPoint] {
        chartPoints.indexedForCharts(startingAt: chartStartDay)
    }

    private var axisLabelIndices: [Double] {
        chartAxis.labelIndices.map(Double.init)
    }

    private var chartStartDay: CalendarDay? {
        points.first?.day
    }

    private var chartAxis: InsightsChartAxis {
        InsightsChartAxis(dayCount: points.count)
    }

    private var macroSegments: [InsightsMacroSegment] {
        indexedPoints.flatMap { point in
            MacroMetric.allCases.map { metric in
                InsightsMacroSegment(point: point, metric: metric)
            }
        }
    }

    private var selectedPoint: InsightsIndexedPoint? {
        guard let selectedIndex = chartAxis.selectedDayIndex(for: selectedIndex) else { return nil }
        return indexedPoints.first { $0.index == selectedIndex }
    }

    var body: some View {
        InsightsCard(title: "Macros", subtitle: "Macro split and protein consistency.") {
            InsightsChartHeader(
                primary: proteinSummary.average.insightsFormattedValue(unit: "g protein avg"),
                secondary: InsightsAnalytics.proteinAdherence(in: points, proteinGoal: goals.proteinGoalGrams).insightsRateText,
                chartStyle: $chartStyle
            )

            selectedPoint.map { point in
                InsightsSelectedValueLabel(
                    title: point.day.chartLabel,
                    value:
                        "P \(point.totals.protein.roundedForDisplay)g • C \(point.totals.carbs.roundedForDisplay)g • F \(point.totals.fat.roundedForDisplay)g"
                )
            }

            Chart {
                switch chartStyle {
                case .bars:
                    ForEach(macroSegments) { segment in
                        BarMark(
                            x: .value("Day", Double(segment.point.index)),
                            y: .value("Grams", segment.value)
                        )
                        .foregroundStyle(by: .value("Macro", segment.metric.title))
                    }
                case .lines:
                    ForEach(macroSegments) { segment in
                        LineMark(
                            x: .value("Day", Double(segment.point.index)),
                            y: .value("Grams", segment.value)
                        )
                        .foregroundStyle(by: .value("Macro", segment.metric.title))
                        .interpolationMethod(.linear)
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
                    AxisValueLabel(collisionResolution: .disabled) {
                        if let index = value.as(Double.self),
                            let day = chartStartDay?.advanced(byDays: Int(index))
                        {
                            Text(day.chartAxisLabel(inRangeFrom: chartStartDay, through: points.last?.day))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .insightsDailyChartXScale(dayCount: points.count)
            .chartGesture { proxy in
                SpatialTapGesture()
                    .onEnded { value in
                        selectedIndex = proxy.value(atX: value.location.x, as: Double.self)
                    }
            }
            .frame(height: 240)
            .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: points.map(\.day))
            .accessibilityLabel("Macros chart")
            .accessibilityValue(
                "\(proteinSummary.average.insightsFormattedValue(unit: "g protein avg")), \(points.chartRangeDescription)"
            )
            .onChange(of: points.map(\.day)) {
                selectedIndex = nil
            }
        }
    }
}

struct InsightsNutrientsCard: View {
    let points: [InsightsDayPoint]
    let previousPoints: [InsightsDayPoint]
    let chartPoints: [InsightsChartPoint]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedNutrient = InsightsNutrient.fiber
    @State private var chartStyle = InsightsChartStyle.bars
    @State private var selectedIndex: Double?

    private var summary: InsightsNutrientSummary {
        InsightsAnalytics.nutrientSummary(current: points, previous: previousPoints, nutrient: selectedNutrient)
    }

    private var indexedPoints: [InsightsIndexedPoint] {
        chartPoints.indexedForCharts(startingAt: chartStartDay)
    }

    private var axisLabelIndices: [Double] {
        chartAxis.labelIndices.map(Double.init)
    }

    private var chartStartDay: CalendarDay? {
        points.first?.day
    }

    private var chartAxis: InsightsChartAxis {
        InsightsChartAxis(dayCount: points.count)
    }

    private var selectedPoint: InsightsIndexedPoint? {
        guard let selectedIndex = chartAxis.selectedDayIndex(for: selectedIndex) else { return nil }
        return indexedPoints.first { $0.index == selectedIndex }
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
                            title: point.day.chartLabel,
                            value: value.insightsFormattedValue(unit: selectedNutrient.unit)
                        )
                    }
                }

                Chart(indexedPoints) { point in
                    let value = selectedNutrient.value(from: point.secondaryTotals)

                    switch chartStyle {
                    case .bars:
                        if let value {
                            BarMark(
                                x: .value("Day", Double(point.index)),
                                y: .value(selectedNutrient.title, value)
                            )
                            .foregroundStyle(Color.accentColor.gradient)
                        }
                    case .lines:
                        if let value {
                            LineMark(
                                x: .value("Day", Double(point.index)),
                                y: .value(selectedNutrient.title, value)
                            )
                            .foregroundStyle(Color.accentColor)
                            .interpolationMethod(.linear)

                            PointMark(
                                x: .value("Day", Double(point.index)),
                                y: .value(selectedNutrient.title, value)
                            )
                            .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: axisLabelIndices) { value in
                        AxisGridLine()
                        AxisValueLabel(collisionResolution: .disabled) {
                            if let index = value.as(Double.self),
                                let day = chartStartDay?.advanced(byDays: Int(index))
                            {
                                Text(day.chartAxisLabel(inRangeFrom: chartStartDay, through: points.last?.day))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .insightsDailyChartXScale(dayCount: points.count)
                .chartGesture { proxy in
                    SpatialTapGesture()
                        .onEnded { value in
                            selectedIndex = proxy.value(atX: value.location.x, as: Double.self)
                        }
                }
                .frame(height: 220)
                .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: points.map(\.day))
                .accessibilityLabel("\(selectedNutrient.title) chart")
                .accessibilityValue(
                    "\(summary.average.insightsFormattedValue(unit: selectedNutrient.unit)), \(points.chartRangeDescription)"
                )
            }
        }
        .onChange(of: points.map(\.day)) {
            selectedIndex = nil
        }
    }

    private var coverageText: String {
        "\(selectedNutrient.title) data available on \(summary.availableDayCount)/\(summary.loggedDayCount) logged days."
    }
}
