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
        VStack(spacing: 10) {
            MacroRingSetView(
                totals: entry.snapshot.totals,
                goals: entry.snapshot.goals,
                ringDiameter: 84,
                centerValueFontSize: 18,
                minimumLineWidth: 5,
                showsGoalSubtitle: false,
                colorStyle: ringColorStyle
            )
            .widgetAccentable()
            .frame(maxWidth: .infinity)

            HStack(spacing: 10) {
                smallMetric(title: "P", value: entry.snapshot.totals.protein)
                smallMetric(title: "C", value: entry.snapshot.totals.carbs)
                smallMetric(title: "F", value: entry.snapshot.totals.fat)
            }
        }
        .padding(12)
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

                mediumMetric(title: "Protein", value: entry.snapshot.totals.protein)
                mediumMetric(title: "Carbs", value: entry.snapshot.totals.carbs)
                mediumMetric(title: "Fat", value: entry.snapshot.totals.fat)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
    }

    private func smallMetric(title: String, value: Double) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value.roundedForDisplay)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    private func mediumMetric(title: String, value: Double) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Text("\(value.roundedForDisplay)g")
                .font(.headline.weight(.semibold))
                .monospacedDigit()
        }
    }
}
