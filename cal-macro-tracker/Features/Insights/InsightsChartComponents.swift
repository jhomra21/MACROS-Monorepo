import Charts
import SwiftUI

struct InsightsCard<Content: View>: View {
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
        .appCardBackground(cornerRadius: 24)
    }
}

struct InsightsChartHeader: View {
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
            .fixedSize()
        }
    }
}

struct InsightsStatTile: View {
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
        .appCardBackground(cornerRadius: 16)
    }
}

struct InsightsSelectedValueLabel: View {
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

struct InsightsIndexedPoint: Identifiable {
    let index: Int
    let day: CalendarDay
    let totals: NutritionSnapshot
    let secondaryTotals: SecondaryNutritionSnapshot

    var id: Int { index }
}

struct InsightsChartAxis: Equatable {
    let dayCount: Int

    var visibleDayCount: Int {
        max(1, min(dayCount, 30))
    }

    var usesHorizontalScrolling: Bool {
        dayCount > visibleDayCount
    }

    func selectedDayIndex(for chartValue: Double?) -> Int? {
        guard let chartValue, chartValue >= 0, chartValue < Double(dayCount) else { return nil }
        let index = Int(chartValue.rounded())
        return (0..<dayCount).contains(index) ? index : nil
    }

    var labelIndices: [Int] {
        guard dayCount > 0 else { return [] }
        if dayCount <= 7 {
            return Array(0..<dayCount)
        }
        let intervalCount =
            dayCount <= 30
            ? min(6, dayCount - 1)
            : max(1, Int((Double(dayCount - 1) / 7).rounded()))
        return (0...intervalCount).map { interval in
            Int((Double(interval) * Double(dayCount - 1) / Double(intervalCount)).rounded())
        }
    }
}

struct InsightsMacroSegment: Identifiable {
    let point: InsightsIndexedPoint
    let metric: MacroMetric

    var id: String { "\(point.index)-\(metric.title)" }
    var value: Double { metric.value(from: point.totals) }
}

extension [InsightsChartPoint] {
    func indexedForCharts(startingAt firstDay: CalendarDay?) -> [InsightsIndexedPoint] {
        guard let firstDay else { return [] }
        return map { point in
            InsightsIndexedPoint(
                index: CalendarDay.dateDistance(from: firstDay, through: point.day),
                day: point.day,
                totals: point.totals,
                secondaryTotals: point.secondaryTotals
            )
        }
    }
}

extension CalendarDay {
    var chartLabel: String {
        startDate.formatted(.dateTime.month(.abbreviated).day())
    }

    func chartAxisLabel(inRangeFrom firstDay: CalendarDay?, through lastDay: CalendarDay?) -> String {
        let calendar = resolvedCalendar
        let includesYear =
            firstDay.map { calendar.component(.year, from: $0.startDate) }
            != lastDay.map { calendar.component(.year, from: $0.startDate) }
        return includesYear
            ? startDate.formatted(.dateTime.month(.defaultDigits).day().year(.twoDigits))
            : startDate.formatted(.dateTime.month(.defaultDigits).day())
    }
}

extension View {
    @ViewBuilder
    func insightsDailyChartXScale(dayCount: Int) -> some View {
        let axis = InsightsChartAxis(dayCount: dayCount)
        let finalDayOffset = Double(max(dayCount, 1))

        if axis.usesHorizontalScrolling {
            chartScrollableAxes(.horizontal)
                .chartXScale(domain: -1...(finalDayOffset + 1))
                .chartXVisibleDomain(length: axis.visibleDayCount + 1)
                .chartScrollPosition(initialX: max(0, dayCount - axis.visibleDayCount))
        } else {
            chartXScale(domain: -1...finalDayOffset)
        }
    }
}

extension Optional where Wrapped == Double {
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

extension Double {
    func insightsFormattedValue(unit: String) -> String {
        "\(roundedForDisplay) \(unit)"
    }
}

extension InsightsGoalAdherence {
    var insightsRateText: String {
        guard loggedDayCount > 0 else { return "No data" }
        return "\(successfulDays)/\(loggedDayCount)"
    }
}
