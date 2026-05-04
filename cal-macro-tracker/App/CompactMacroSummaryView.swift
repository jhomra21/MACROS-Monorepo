import SwiftUI

struct CompactMacroSummaryView: View {
    let totals: NutritionSnapshot
    let goals: MacroGoalsSnapshot
    let horizontalPadding: CGFloat
    let ringColorPalette: MacroRingPalette?

    init(
        totals: NutritionSnapshot,
        goals: MacroGoalsSnapshot,
        horizontalPadding: CGFloat = 8,
        ringColorPalette: MacroRingPalette? = nil
    ) {
        self.totals = totals
        self.goals = goals
        self.horizontalPadding = horizontalPadding
        self.ringColorPalette = ringColorPalette
    }

    var body: some View {
        HStack(spacing: 0) {
            CompactMacroRingView(
                totals: totals,
                goals: goals,
                colorStyle: ringColorPalette.map(MacroRingColorStyle.custom) ?? .standard
            )
            .frame(width: 72, height: 72)
            .frame(maxWidth: .infinity)

            ForEach(MacroMetric.allCases) { metric in
                macroColumn(metric: metric)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .appGlassRoundedRect(cornerRadius: 28, interactive: false)
        .padding(.horizontal, horizontalPadding)
    }

    private func macroColumn(metric: MacroMetric) -> some View {
        MacroSummaryColumnView(
            metric: metric,
            totals: totals,
            goals: goals,
            titleStyle: .full,
            style: .compact,
            minimumHeight: 60,
            accentColor: ringColorPalette?.color(for: metric)
        )
    }
}
