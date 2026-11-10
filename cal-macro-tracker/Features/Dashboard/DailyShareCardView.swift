import SwiftUI

/// Aspect ratios offered by the Share sheet. Cards lay out on a fixed 432 pt canvas and render at 2.5x,
/// so the exported pixels are exact on every device.
enum ShareImageSize: String, CaseIterable, Identifiable {
    case story = "Story"
    case post = "Post"
    case square = "Square"

    static let canvasWidth: CGFloat = 432
    static let renderScale: CGFloat = 2.5

    var id: Self { self }
    var title: String { rawValue }

    var canvasHeight: CGFloat {
        switch self {
        case .story: 768
        case .post: 540
        case .square: 432
        }
    }

    var canvas: CGSize { CGSize(width: Self.canvasWidth, height: canvasHeight) }

    func ringDiameter(for detail: ShareDetail) -> CGFloat {
        switch (self, detail) {
        case (.story, .rings): 360
        case (.story, .macros): 320
        case (.story, .full): 290
        case (.post, .rings): 340
        case (.post, .macros): 270
        case (.post, .full): 200
        case (.square, .rings): 300
        case (.square, .macros): 190
        case (.square, .full): 150
        }
    }
}

/// How much of the day a shared image shows. Food names are never an option.
enum ShareDetail: String, CaseIterable, Identifiable {
    case rings = "Rings"
    case macros = "Macros"
    case full = "Full"

    var id: Self { self }
    var title: String { rawValue }
}

struct DailyShareCardView: View {
    private static let sectionSpacing: CGFloat = 12

    let day: CalendarDay
    let snapshot: LogEntryDaySnapshot
    let goals: MacroGoalsSnapshot
    let size: ShareImageSize
    let detail: ShareDetail

    var body: some View {
        VStack(spacing: Self.sectionSpacing) {
            header

            Spacer(minLength: 0)

            MacroRingSetView(
                totals: snapshot.totals,
                goals: goals,
                ringDiameter: ringDiameter,
                centerValueFontSize: ringDiameter * 0.17,
                minimumLineWidth: 5,
                showsGoalSubtitle: ringDiameter >= 190
            )

            if detail != .rings {
                macroSummary
            }

            if detail == .full {
                SecondaryNutritionDetailsView(snapshot: snapshot.secondaryTotals)
                    .padding(.horizontal, 16)
            }

            Spacer(minLength: 0)

            footer
        }
        .padding(size == .square ? 20 : 24)
        .frame(width: size.canvas.width, height: size.canvas.height)
        .background(PlatformColors.groupedBackground)
        .environment(\.dynamicTypeSize, .large)
    }

    private var ringDiameter: CGFloat { size.ringDiameter(for: detail) }

    private var header: some View {
        HStack {
            Text(day.startDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year()))
                .font(.title2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 0)
        }
    }

    private var macroSummary: some View {
        HStack(spacing: 10) {
            ForEach(MacroMetric.allCases) { metric in
                MacroSummaryColumnView(
                    metric: metric,
                    totals: snapshot.totals,
                    goals: goals,
                    titleStyle: .full,
                    style: .dashboardCard
                )
            }
        }
    }

    private var footer: some View {
        HStack {
            Spacer()

            Text(AppBrand.displayName)
                .font(.caption.weight(.semibold))
                .tracking(1.6)
                .foregroundStyle(.secondary.opacity(0.72))
        }
    }
}

#Preview("Daily Share Card") {
    DailyShareCardView(
        day: CalendarDay(date: .now),
        snapshot: LogEntryDaySnapshot(
            entries: [],
            totals: NutritionSnapshot(calories: 18_400, protein: 132, fat: 58, carbs: 196),
            secondaryTotals: SecondaryNutritionSnapshot(
                saturatedFat: 18,
                fiber: 24,
                sugars: 52,
                addedSugars: nil,
                sodium: 1820,
                cholesterol: 140
            )
        ),
        goals: MacroGoalsSnapshot(
            calorieGoal: 2200,
            proteinGoalGrams: 160,
            fatGoalGrams: 70,
            carbGoalGrams: 240
        ),
        size: .square,
        detail: .full
    )
    .preferredColorScheme(.dark)
}
