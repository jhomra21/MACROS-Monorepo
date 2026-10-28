import Charts
import SwiftUI

struct InsightsCaloriesCard: View {
    let points: [InsightsDayPoint]
    let previousPoints: [InsightsDayPoint]
    let goals: MacroGoalsSnapshot
    let chartPoints: [InsightsChartPoint]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var chartStyle = InsightsChartStyle.bars
    @State private var selectedIndex: Double?
    @State private var hasAnimatedIn = false

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
        InsightsCard(title: "Calories", subtitle: "Calories compared with your current goal range. Daily totals.") {
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
                            y: .value("Calories", animatedValue(point.totals.calories))
                        )
                        .foregroundStyle(Color.accentColor.gradient)
                    case .lines:
                        LineMark(
                            x: .value("Day", Double(point.index)),
                            y: .value("Calories", animatedValue(point.totals.calories))
                        )
                        .foregroundStyle(Color.accentColor)
                        .interpolationMethod(.linear)

                        PointMark(
                            x: .value("Day", Double(point.index)),
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
                    AxisValueLabel(centered: true, collisionResolution: .disabled) {
                        if let index = value.as(Double.self),
                            let day = chartStartDay?.advanced(byDays: Int(index))
                        {
                            Text(day.chartAxisLabel(inRangeFrom: chartStartDay, through: points.last?.day))
                                .offset(
                                    x: chartAxis.usesHorizontalScrolling && index == Double(chartAxis.labelIndices.last ?? -1) ? -18 : 0
                                )
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
            .accessibilityLabel("Calories chart")
            .onAppear {
                guard !hasAnimatedIn else { return }
                withAnimation(reduceMotion ? .easeOut(duration: 0.16) : .easeOut(duration: 0.28)) {
                    hasAnimatedIn = true
                }
            }
            .onChange(of: points.map(\.day)) {
                selectedIndex = nil
            }
        }
    }

    private func animatedValue(_ value: Double) -> Double {
        reduceMotion || hasAnimatedIn ? value : 0
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
    @State private var hasAnimatedIn = false

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
        InsightsCard(title: "Macros", subtitle: "Composition and protein consistency. Daily totals.") {
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
                            y: .value("Grams", animatedValue(segment.value))
                        )
                        .foregroundStyle(by: .value("Macro", segment.metric.title))
                    }
                case .lines:
                    ForEach(macroSegments) { segment in
                        LineMark(
                            x: .value("Day", Double(segment.point.index)),
                            y: .value("Grams", animatedValue(segment.value))
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
                    AxisValueLabel(centered: true, collisionResolution: .disabled) {
                        if let index = value.as(Double.self),
                            let day = chartStartDay?.advanced(byDays: Int(index))
                        {
                            Text(day.chartAxisLabel(inRangeFrom: chartStartDay, through: points.last?.day))
                                .offset(
                                    x: chartAxis.usesHorizontalScrolling && index == Double(chartAxis.labelIndices.last ?? -1) ? -18 : 0
                                )
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
            .accessibilityLabel("Macros chart")
            .onAppear {
                guard !hasAnimatedIn else { return }
                withAnimation(reduceMotion ? .easeOut(duration: 0.16) : .easeOut(duration: 0.28)) {
                    hasAnimatedIn = true
                }
            }
            .onChange(of: points.map(\.day)) {
                selectedIndex = nil
            }
        }
    }

    private func animatedValue(_ value: Double) -> Double {
        reduceMotion || hasAnimatedIn ? value : 0
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
    @State private var hasAnimatedIn = false

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
        InsightsCard(title: "Nutrients", subtitle: "\(coverageText) Daily totals.") {
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
                                y: .value(selectedNutrient.title, animatedValue(value))
                            )
                            .foregroundStyle(Color.green.gradient)
                        }
                    case .lines:
                        if let value {
                            LineMark(
                                x: .value("Day", Double(point.index)),
                                y: .value(selectedNutrient.title, animatedValue(value))
                            )
                            .foregroundStyle(Color.green)
                            .interpolationMethod(.linear)

                            PointMark(
                                x: .value("Day", Double(point.index)),
                                y: .value(selectedNutrient.title, animatedValue(value))
                            )
                            .foregroundStyle(Color.green)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: axisLabelIndices) { value in
                        AxisGridLine()
                        AxisValueLabel(centered: true, collisionResolution: .disabled) {
                            if let index = value.as(Double.self),
                                let day = chartStartDay?.advanced(byDays: Int(index))
                            {
                                Text(day.chartAxisLabel(inRangeFrom: chartStartDay, through: points.last?.day))
                                    .offset(
                                        x: chartAxis.usesHorizontalScrolling && index == Double(chartAxis.labelIndices.last ?? -1) ? -18 : 0
                                    )
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
                .accessibilityLabel("\(selectedNutrient.title) chart")
            }
        }
        .onAppear {
            guard !hasAnimatedIn else { return }
            withAnimation(reduceMotion ? .easeOut(duration: 0.16) : .easeOut(duration: 0.28)) {
                hasAnimatedIn = true
            }
        }
        .onChange(of: points.map(\.day)) {
            selectedIndex = nil
        }
    }

    private var coverageText: String {
        "\(selectedNutrient.title) data available on \(summary.availableDayCount)/\(summary.loggedDayCount) logged days."
    }

    private func animatedValue(_ value: Double) -> Double {
        reduceMotion || hasAnimatedIn ? value : 0
    }
}
