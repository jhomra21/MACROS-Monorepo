import SwiftUI
import WidgetKit

#if os(iOS)
struct DailyMacroAccessoryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: SharedAppConfiguration.dailyMacroAccessoryWidgetKind,
            provider: DailyMacroWidgetProvider()
        ) { entry in
            DailyMacroAccessoryWidgetContentView(entry: entry)
                .containerBackground(for: .widget) {
                    AccessoryWidgetBackground()
                }
                .widgetURL(AppOpenRequest.dashboard.url)
        }
        .configurationDisplayName("Daily Macros")
        .description("Check today's calories and macros from your Lock Screen.")
        .supportedFamilies([
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

private struct DailyMacroAccessoryWidgetContentView: View {
    @Environment(\.widgetFamily) private var family

    let entry: DailyMacroWidgetEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularContent
        case .accessoryRectangular:
            rectangularContent
        default:
            inlineContent
        }
    }

    private var inlineContent: some View {
        Text(inlineSummary)
    }

    private var circularContent: some View {
        Gauge(value: calorieProgress, in: 0...1) {
            EmptyView()
        } currentValueLabel: {
            Text(entry.snapshot.totals.calories.roundedForDisplay)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .monospacedDigit()
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }

    private var rectangularContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Today")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(entry.snapshot.totals.calories.roundedForDisplay) kcal")
                    .font(.headline.weight(.semibold))
                    .monospacedDigit()

                Text("of \(entry.snapshot.goals.calorieGoal.roundedForDisplay)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Text(
                rectangularMacroSummary
            )
            .font(.caption2.weight(.medium))
            .monospacedDigit()
            .lineLimit(1)
        }
    }

    private var inlineSummary: String {
        "\(entry.snapshot.totals.calories.roundedForDisplay) cal · \(compactMacroSummary)"
    }

    private var rectangularMacroSummary: String {
        MacroMetric.allCases
            .map { metric in
                "\(metric.shortTitle) \(metric.value(from: entry.snapshot.totals).roundedForDisplay)g"
            }
            .joined(separator: "  ")
    }

    private var compactMacroSummary: String {
        MacroMetric.allCases
            .map { metric in
                "\(metric.shortTitle)\(metric.value(from: entry.snapshot.totals).roundedForDisplay)"
            }
            .joined(separator: " ")
    }

    private var calorieProgress: Double {
        let goal = entry.snapshot.goals.calorieGoal
        guard goal > 0 else { return 0 }
        return min(max(entry.snapshot.totals.calories / goal, 0), 1)
    }
}
#endif
