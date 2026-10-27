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
        .appGlassRoundedRect(cornerRadius: 24, interactive: false)
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
            .frame(maxWidth: 148)
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
        .appGlassRoundedRect(cornerRadius: 16, interactive: false)
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

struct InsightsMacroSegment: Identifiable {
    let point: InsightsIndexedPoint
    let metric: MacroMetric

    var id: String { "\(point.index)-\(metric.title)" }
    var value: Double { metric.value(from: point.totals) }
}

extension [InsightsChartPoint] {
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

extension [InsightsIndexedPoint] {
    var axisLabelIndices: [Int] {
        let interval = Swift.max(1, Int(ceil(Double(count) / 6)))
        return stride(from: 0, to: count, by: interval).map { $0 }
    }
}

extension InsightsChartBucket {
    var averageLabel: String {
        switch self {
        case .daily: "Daily totals"
        case .weekly: "Weekly avg"
        case .monthly: "Monthly avg"
        }
    }
}

extension CalendarDay {
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

extension Array {
    subscript(safe index: Int?) -> Element? {
        guard let index, indices.contains(index) else { return nil }
        return self[index]
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
