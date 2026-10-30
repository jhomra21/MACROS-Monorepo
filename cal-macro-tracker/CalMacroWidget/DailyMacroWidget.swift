import Foundation
import OSLog
import SwiftUI
import WidgetKit
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct DailyMacroWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: DailyMacroSnapshot
    let customRingPalette: MacroRingPalette?
    let appearance: WidgetAppearanceRecord?
    let proAccess: WidgetProAccess
    let backgroundPhotoData: Data?
}

struct DailyMacroWidgetProvider: TimelineProvider {
    private static let logger = Logger(subsystem: "juan-test.cal-macro-tracker", category: "Widget")
    private let includesAppearance: Bool

    init(includesAppearance: Bool = true) {
        self.includesAppearance = includesAppearance
    }

    func placeholder(in context: Context) -> DailyMacroWidgetEntry {
        DailyMacroWidgetEntry(
            date: .now,
            snapshot: DailyMacroSnapshot(
                totals: NutritionSnapshot(calories: 1_840, protein: 132, fat: 58, carbs: 176),
                goals: .default
            ),
            customRingPalette: nil,
            appearance: nil,
            proAccess: .unknown,
            backgroundPhotoData: nil
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

        let appearanceStorage = WidgetAppearanceStorage.shared
        let appearance = includesAppearance ? appearanceStorage.appearanceRecord : nil
        let proAccess = includesAppearance ? appearanceStorage.proAccess : .unknown
        return DailyMacroWidgetEntry(
            date: .now,
            snapshot: snapshot,
            customRingPalette: MacroRingColorStorage.storedPalette(),
            appearance: appearance,
            proAccess: proAccess,
            backgroundPhotoData: includesAppearance ? backgroundPhotoData(for: appearance, access: proAccess) : nil
        )
    }

    private func backgroundPhotoData(
        for appearance: WidgetAppearanceRecord?,
        access: WidgetProAccess
    ) -> Data? {
        let storage = WidgetAppearanceStorage.shared
        guard access == .allowed,
            let identifier = appearance?.background.photoIdentifier,
            let url = storage.photoURL(for: identifier),
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
            let size = attributes[.size] as? NSNumber,
            size.uint64Value <= UInt64(WidgetAppearanceStorage.maximumPhotoBytes),
            let data = try? Data(contentsOf: url, options: .mappedIfSafe),
            data.count <= WidgetAppearanceStorage.maximumPhotoBytes
        else { return nil }
        return data
    }
}

struct DailyMacroWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SharedAppConfiguration.dailyMacroWidgetKind, provider: DailyMacroWidgetProvider()) { entry in
            DailyMacroWidgetContentView(entry: entry)
                .containerBackground(for: .widget) {
                    DailyMacroWidgetBackground(entry: entry)
                }
                .widgetURL(AppOpenRequest.dashboard.url)
        }
        .configurationDisplayName("Daily Macros")
        .description("Track calories and macros at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .containerBackgroundRemovable(true)
    }
}

private struct DailyMacroWidgetContentView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.showsWidgetContainerBackground) private var showsWidgetContainerBackground
    @Environment(\.colorScheme) private var colorScheme

    let entry: DailyMacroWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                mediumContent
            default:
                smallContent
            }
        }
        .environment(
            \.colorScheme,
            usesCustomBackground ? .dark : colorScheme
        )
    }

    private var usesCustomBackground: Bool {
        entry.customBackground(
            renderingMode: renderingMode,
            showsContainerBackground: showsWidgetContainerBackground
        ) != nil
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
        MacroSummaryColumnsGrid(
            metrics: MacroMetric.allCases,
            totals: entry.snapshot.totals,
            goals: entry.snapshot.goals,
            style: .widgetSmall(valueFontSize: smallMetricValueFontSize),
            columnWidth: columnWidth,
            columnSpacing: spacing
        )
        .frame(width: columnWidth * CGFloat(MacroMetric.allCases.count) + spacing * CGFloat(MacroMetric.allCases.count - 1))
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

private enum CustomWidgetBackground {
    case color(Color)
    case photo(Image)
}

private extension DailyMacroWidgetEntry {
    /// The Pro background that is actually drawn, or nil when iOS draws the native container.
    /// Foreground and background both read this so the text scheme always matches the drawn background.
    func customBackground(renderingMode: WidgetRenderingMode, showsContainerBackground: Bool) -> CustomWidgetBackground? {
        guard renderingMode == .fullColor, showsContainerBackground, proAccess == .allowed,
            let selection = appearance?.background
        else { return nil }
        switch selection {
        case .native:
            return nil
        case let .color(hex):
            return Color(hex: hex).map(CustomWidgetBackground.color)
        case .photo:
            return photoImage.map(CustomWidgetBackground.photo)
        }
    }

    private var photoImage: Image? {
        guard let data = backgroundPhotoData else { return nil }
        #if os(iOS)
        guard let image = UIImage(data: data) else { return nil }
        return Image(uiImage: image)
        #elseif os(macOS)
        guard let image = NSImage(data: data) else { return nil }
        return Image(nsImage: image)
        #else
        return nil
        #endif
    }
}

private struct DailyMacroWidgetBackground: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.showsWidgetContainerBackground) private var showsWidgetContainerBackground

    let entry: DailyMacroWidgetEntry

    var body: some View {
        switch entry.customBackground(renderingMode: renderingMode, showsContainerBackground: showsWidgetContainerBackground) {
        case let .color(color)?:
            color.overlay(Color.black.opacity(0.82))
        case let .photo(image)?:
            image
                .resizable()
                .scaledToFill()
                .overlay(Color.black.opacity(0.82))
                .clipped()
        case nil:
            Color.clear
        }
    }
}
