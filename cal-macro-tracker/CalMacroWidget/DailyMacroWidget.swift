import SwiftUI
import WidgetKit

struct DailyMacroWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: DailyMacroSnapshot
}

struct DailyMacroWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyMacroWidgetEntry {
        DailyMacroWidgetEntry(
            date: .now,
            snapshot: DailyMacroSnapshot(
                totals: NutritionSnapshot(calories: 1_840, protein: 132, fat: 58, carbs: 176),
                goals: .default
            )
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
            snapshot = .empty
        }

        return DailyMacroWidgetEntry(date: .now, snapshot: snapshot)
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
        renderingMode == .accented ? .accentedWidget : .standard
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
        HStack(spacing: 16) {
            MacroRingSetView(
                totals: entry.snapshot.totals,
                goals: entry.snapshot.goals,
                ringDiameter: 96,
                centerValueFontSize: 22,
                minimumLineWidth: 5,
                showsGoalSubtitle: false,
                colorStyle: ringColorStyle
            )
            .widgetAccentable()

            VStack(alignment: .leading, spacing: 10) {
                Text("Today")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                ForEach(MacroMetric.allCases) { metric in
                    mediumMetric(metric: metric)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
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
            return 20
        case 3:
            return 15
        case 4:
            return 13
        case 5:
            return 11
        default:
            return 10
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
            alignment: .center,
            titleStyle: .short,
            style: .widgetSmall(valueFontSize: fontSize)
        )
    }

    private func mediumMetric(metric: MacroMetric) -> some View {
        MacroSummaryColumnView(
            metric: metric,
            totals: entry.snapshot.totals,
            goals: entry.snapshot.goals,
            alignment: .leading,
            titleStyle: .full,
            style: .widgetMedium
        )
    }
}
