import OSLog
import SwiftUI
import WidgetKit

struct DailyMacroWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: DailyMacroSnapshot
    let customRingPalette: MacroRingPalette?
}

struct DailyMacroWidgetProvider: TimelineProvider {
    private static let logger = Logger(subsystem: "juan-test.cal-macro-tracker", category: "Widget")

    func placeholder(in context: Context) -> DailyMacroWidgetEntry {
        DailyMacroWidgetEntry(
            date: .now,
            snapshot: DailyMacroSnapshot(
                totals: NutritionSnapshot(calories: 1_840, protein: 132, fat: 58, carbs: 176),
                goals: .default
            ),
            customRingPalette: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyMacroWidgetEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyMacroWidgetEntry>) -> Void) {
        let entry = loadEntry()
        let midnight = Calendar.current.startOfDay(for: entry.date)
        let nextMidnight = Calendar.current.date(byAdding: .day, value: 1, to: midnight) ?? entry.date.addingTimeInterval(60 * 60 * 24)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }

    private func loadEntry() -> DailyMacroWidgetEntry {
        let snapshot: DailyMacroSnapshot

        do {
            if let container = try SharedModelContainerFactory.makeReadablePersistentContainerIfAvailable() {
                snapshot = try DailyMacroSnapshotLoader.load(in: container)
            } else {
                snapshot = .empty
            }
        } catch {
            Self.logger.error("Unable to load widget snapshot: \(error.localizedDescription, privacy: .public)")
            snapshot = .empty
        }

        return DailyMacroWidgetEntry(
            date: .now,
            snapshot: snapshot,
            customRingPalette: MacroRingColorStorage.storedPalette()
        )
    }
}

struct DailyMacroWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SharedAppConfiguration.dailyMacroWidgetKind, provider: DailyMacroWidgetProvider()) { entry in
            DailyMacroWidgetContentView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
                .widgetURL(AppOpenRequest.dashboard.url)
        }
        .configurationDisplayName("Daily Macros")
        .description("Track calories and macros at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct DailyMacroWidgetContentView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    let entry: DailyMacroWidgetEntry

    var body: some View {
        switch family {
        case .systemMedium:
            mediumContent
        default:
            smallContent
        }
    }

    private var ringColorStyle: MacroRingColorStyle {
        if renderingMode == .accented {
            .accentedWidget
        } else if let customRingPalette = entry.customRingPalette {
            .custom(customRingPalette)
        } else {
            .standard
        }
    }

    private var smallContent: some View {
        GeometryReader { geometry in
            let horizontalPadding: CGFloat = 8
            let verticalPadding: CGFloat = 10
            let metricSpacing: CGFloat = 2
            let availableWidth = max(geometry.size.width - (horizontalPadding * 2), 0)
            let columnCount = CGFloat(MacroMetric.allCases.count)
            let totalSpacing = metricSpacing * (columnCount - 1)
            let columnWidth = max((availableWidth - totalSpacing) / columnCount, 0)

            VStack(spacing: 8) {
                MacroRingSetView(
                    totals: entry.snapshot.totals,
                    goals: entry.snapshot.goals,
                    ringDiameter: 80,
                    centerValueFontSize: 18,
                    minimumLineWidth: 5,
                    showsGoalSubtitle: false,
                    colorStyle: ringColorStyle
                )
                .widgetAccentable()
                .frame(maxWidth: .infinity)

                smallMetricsRow(columnWidth: columnWidth, spacing: metricSpacing)
                    .frame(width: availableWidth)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
    }

    private var mediumContent: some View {
        GeometryReader { geometry in
            let horizontalPadding: CGFloat = 16
            let verticalPadding: CGFloat = 14
            let ringMetricSpacing: CGFloat = 24
            let contentWidth = max(geometry.size.width - (horizontalPadding * 2), 0)
            let ringDiameter = min(112, max(92, geometry.size.height - (verticalPadding * 2)))
            let metricWidth = max(contentWidth - ringDiameter - ringMetricSpacing, 0)
            let metricSpacing: CGFloat = 10
            let metricCount = CGFloat(MacroMetric.allCases.count)
            let metricTotalSpacing = metricSpacing * (metricCount - 1)
            let columnWidth = max((metricWidth - metricTotalSpacing) / metricCount, 0)

            HStack(spacing: ringMetricSpacing) {
                MacroRingSetView(
                    totals: entry.snapshot.totals,
                    goals: entry.snapshot.goals,
                    ringDiameter: ringDiameter,
                    centerValueFontSize: 24,
                    minimumLineWidth: 5,
                    showsGoalSubtitle: false,
                    colorStyle: ringColorStyle
                )
                .widgetAccentable()

                HStack(alignment: .center, spacing: metricSpacing) {
                    ForEach(MacroMetric.allCases) { metric in
                        mediumMetric(metric: metric)
                            .frame(width: columnWidth, alignment: .center)
                    }
                }
                .frame(width: metricWidth, alignment: .center)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
        }
    }

    private var smallMetricDisplayLengths: [Int] {
        MacroMetric.allCases.map { metric in
            let presentation = metric.goalValuePresentation(
                totals: entry.snapshot.totals,
                goals: entry.snapshot.goals
            )
            return presentation.currentValueText.count
        }
    }

    private var smallMetricValueFontSize: CGFloat {
        let widestValueLength = smallMetricDisplayLengths.max() ?? 1

        switch widestValueLength {
        case 0...2:
            return 21
        case 3:
            return 16
        case 4:
            return 14
        case 5:
            return 12
        default:
            return 11
        }
    }

    private func smallMetricsRow(columnWidth: CGFloat, spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            ForEach(MacroMetric.allCases) { metric in
                smallMetric(metric: metric, fontSize: smallMetricValueFontSize)
                    .frame(width: columnWidth)
            }
        }
    }

    private func smallMetric(metric: MacroMetric, fontSize: CGFloat) -> some View {
        MacroSummaryColumnView(
            metric: metric,
            totals: entry.snapshot.totals,
            goals: entry.snapshot.goals,
            titleStyle: .short,
            style: .widgetSmall(valueFontSize: fontSize)
        )
    }

    private func mediumMetric(metric: MacroMetric) -> some View {
        let presentation = metric.goalValuePresentation(
            totals: entry.snapshot.totals,
            goals: entry.snapshot.goals
        )

        return VStack(spacing: 4) {
            VStack(spacing: 2) {
                Text(presentation.currentValueText)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(presentation.goalValueText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            VStack(spacing: 1) {
                Capsule()
                    .fill(metric.accentColor.opacity(0.55))
                    .frame(width: 24, height: 1)

                Text(metric.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
    }
}
