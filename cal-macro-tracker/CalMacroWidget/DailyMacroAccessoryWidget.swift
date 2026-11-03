import SwiftUI
import WidgetKit

#if os(iOS)
struct DailyMacroAccessoryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: SharedAppConfiguration.dailyMacroAccessoryWidgetKind,
            provider: DailyMacroWidgetProvider(includesAppearance: false)
        ) { entry in
            DailyMacroAccessoryWidgetContentView(entry: entry)
                .redacted(reason: entry.isPlaceholder ? .placeholder : [])
                .containerBackground(for: .widget) {
                    AccessoryWidgetBackground()
                }
        }
        .configurationDisplayName("Macros Lock Screen")
        .description("Check today’s calories and macros from your Lock Screen.")
        .supportedFamilies([
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

struct DailyMacroAccessoryWidgetContentView: View {
    @Environment(\.widgetFamily) private var family

    let entry: DailyMacroWidgetEntry
    var personName: String? = nil
    var freshness: String? = nil
    var offline = false

    var body: some View {
        if let freshness {
            content.accessibilityValue(freshness)
        } else {
            content
        }
    }

    private var content: some View {
        Group {
            switch family {
            case .accessoryCircular:
                circularContent
                    .overlay(alignment: .bottom) {
                        if let personName {
                            Text(offline ? "Offline" : personName)
                                .font(.system(size: 11))
                                .lineLimit(1)
                                .offset(y: 4)
                        }
                    }
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    if let personName {
                        HStack {
                            Text(personName).font(.caption.weight(.semibold))
                            Spacer(minLength: 2)
                            if let freshness { Text(freshness).font(.system(size: 11)) }
                        }
                        .lineLimit(1)
                    }
                    rectangularContent
                }
            default:
                inlineContent
            }
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
        var style = MacroSummaryColumnView.Style.accessoryRectangular
        style.hidesMissingGoals = personName != nil
        return
            HStack(spacing: 6) {
                ForEach(MacroMetric.allCases) { metric in
                    MacroSummaryColumnView(
                        metric: metric,
                        totals: entry.snapshot.totals,
                        goals: entry.snapshot.goals,
                        titleStyle: .short,
                        style: style
                    )
                }
            }
    }

    private var inlineSummary: String {
        if let personName {
            return offline ? "\(personName) · Offline" : "\(personName) · \(entry.snapshot.totals.calories.roundedForDisplay) cal"
        }
        return "\(entry.snapshot.totals.calories.roundedForDisplay) cal · \(compactMacroSummary)"
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
