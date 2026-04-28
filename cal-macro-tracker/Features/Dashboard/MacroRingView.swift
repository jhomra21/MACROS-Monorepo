import SwiftUI

struct MacroRingView: View {
    let totals: NutritionSnapshot
    let goals: MacroGoalsSnapshot
    let selectedMetric: MacroMetric?
    let ringDiameter: CGFloat

    init(
        totals: NutritionSnapshot,
        goals: MacroGoalsSnapshot,
        selectedMetric: MacroMetric? = nil,
        ringDiameter: CGFloat = 224
    ) {
        self.totals = totals
        self.goals = goals
        self.selectedMetric = selectedMetric
        self.ringDiameter = ringDiameter
    }

    var body: some View {
        MacroRingSetView(
            totals: totals,
            goals: goals,
            ringDiameter: ringDiameter,
            centerValueFontSize: 42,
            minimumLineWidth: 5,
            showsGoalSubtitle: true,
            selectedMetric: selectedMetric
        )
    }
}

struct CompactMacroRingView: View {
    let totals: NutritionSnapshot
    let goals: MacroGoalsSnapshot

    private let ringDiameter: CGFloat = 64

    var body: some View {
        MacroRingSetView(
            totals: totals,
            goals: goals,
            ringDiameter: ringDiameter,
            centerValueFontSize: 14,
            minimumLineWidth: 5,
            showsGoalSubtitle: false
        )
    }
}

struct WeekdayMacroRingView: View {
    let totals: NutritionSnapshot
    let goals: MacroGoalsSnapshot

    private let ringDiameter: CGFloat = 28

    var body: some View {
        MacroRingSetView(
            totals: totals,
            goals: goals,
            ringDiameter: ringDiameter,
            centerValueFontSize: nil,
            minimumLineWidth: 2.4,
            showsGoalSubtitle: false
        )
    }
}

struct MacroDashboardRingPanel: View {
    let totals: NutritionSnapshot
    let goals: MacroGoalsSnapshot
    let selectedMacro: MacroMetric?
    let isExpanded: Bool
    let onToggleExpansion: () -> Void

    private let collapsedRingDiameter: CGFloat = 269
    private let expandedRingDiameter: CGFloat = 321

    private var ringScale: CGFloat {
        isExpanded ? 1 : collapsedRingDiameter / expandedRingDiameter
    }

    private var bottomPadding: CGFloat {
        isExpanded ? 0 : collapsedRingDiameter - expandedRingDiameter
    }

    var body: some View {
        Button(action: onToggleExpansion) {
            ZStack(alignment: .top) {
                MacroRingView(
                    totals: totals,
                    goals: goals,
                    selectedMetric: selectedMacro,
                    ringDiameter: expandedRingDiameter
                )
                .compositingGroup()
                .scaleEffect(ringScale, anchor: .top)
            }
            .frame(width: expandedRingDiameter, height: expandedRingDiameter, alignment: .top)
            .padding(.bottom, bottomPadding)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isExpanded ? "Collapse nutrition details" : "Expand nutrition details")
    }
}

struct SecondaryNutritionDetailsView: View {
    let snapshot: SecondaryNutritionSnapshot

    var body: some View {
        LazyVGrid(columns: columns, alignment: .center, spacing: 14) {
            ForEach(SecondaryNutritionMetric.allCases) { metric in
                secondaryNutrientColumn(metric)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12, alignment: .center),
            GridItem(.flexible(), spacing: 12, alignment: .center),
            GridItem(.flexible(), spacing: 12, alignment: .center)
        ]
    }

    private func secondaryNutrientColumn(_ metric: SecondaryNutritionMetric) -> some View {
        VStack(alignment: .center, spacing: 2) {
            Text(metric.displayValue(from: snapshot))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(metric.value(from: snapshot) == nil ? .secondary : .primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(metric.title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private enum SecondaryNutritionMetric: CaseIterable, Identifiable {
    case saturatedFat
    case fiber
    case sugars
    case addedSugars
    case sodium
    case cholesterol

    var id: Self { self }

    var title: String {
        switch self {
        case .saturatedFat:
            "Sat Fat"
        case .fiber:
            "Fiber"
        case .sugars:
            "Sugars"
        case .addedSugars:
            "Added Sugar"
        case .sodium:
            "Sodium"
        case .cholesterol:
            "Cholesterol"
        }
    }

    var unit: String {
        switch self {
        case .saturatedFat, .fiber, .sugars, .addedSugars:
            "g"
        case .sodium, .cholesterol:
            "mg"
        }
    }

    func value(from snapshot: SecondaryNutritionSnapshot) -> Double? {
        switch self {
        case .saturatedFat:
            snapshot.saturatedFat
        case .fiber:
            snapshot.fiber
        case .sugars:
            snapshot.sugars
        case .addedSugars:
            snapshot.addedSugars
        case .sodium:
            snapshot.sodium
        case .cholesterol:
            snapshot.cholesterol
        }
    }

    func displayValue(from snapshot: SecondaryNutritionSnapshot) -> String {
        guard let value = value(from: snapshot) else { return "Not tracked" }
        return "\(value.roundedForDisplay) \(unit)"
    }
}

struct MacroLegendView: View {
    let totals: NutritionSnapshot
    let goals: MacroGoalsSnapshot
    @Binding var selectedMacro: MacroMetric?

    var body: some View {
        HStack(spacing: 24) {
            ForEach(MacroMetric.allCases) { metric in
                legendCard(metric: metric)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func legendCard(metric: MacroMetric) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) {
                selectedMacro = selectedMacro == metric ? nil : metric
            }
        } label: {
            MacroSummaryColumnView(
                metric: metric,
                totals: totals,
                goals: goals,
                alignment: .center,
                titleStyle: .full,
                style: .dashboardCard
            )
            .padding(16)
            .opacity(selectedMacro == nil || selectedMacro == metric ? 1 : 0.48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(selectedMacro == metric ? "Selected" : "")
    }
}
