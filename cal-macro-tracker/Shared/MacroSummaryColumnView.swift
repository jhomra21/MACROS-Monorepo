import SwiftUI

struct MacroSummaryColumnView: View {
    enum TitleStyle {
        case full
        case short
    }

    struct Style {
        let titleFont: Font
        let valueFont: Font
        let baselineFont: Font
        let valueIndicatorFont: Font
        let titleColor: Color
        let valueColor: Color
        let baselineColor: Color
        let showsTitleDot: Bool
        let titleSpacing: CGFloat
        let titleDotDiameter: CGFloat
        let verticalSpacing: CGFloat
        let goalSpacing: CGFloat
        let valueMinimumScaleFactor: CGFloat
        let baselineMinimumScaleFactor: CGFloat
        let deltaWeight: Font.Weight
        let showsOverGoalIndicatorInValueLine: Bool
        let showsOverGoalDeltaInGoalLine: Bool
        let showsTitleAfterValues: Bool
    }

    let metric: MacroMetric
    let totals: NutritionSnapshot
    let goals: MacroGoalsSnapshot
    let titleStyle: TitleStyle
    let style: Style
    let minimumHeight: CGFloat?
    let accentColor: Color?

    init(
        metric: MacroMetric,
        totals: NutritionSnapshot,
        goals: MacroGoalsSnapshot,
        titleStyle: TitleStyle,
        style: Style,
        minimumHeight: CGFloat? = nil,
        accentColor: Color? = nil
    ) {
        self.metric = metric
        self.totals = totals
        self.goals = goals
        self.titleStyle = titleStyle
        self.style = style
        self.minimumHeight = minimumHeight
        self.accentColor = accentColor
    }

    private var presentation: MacroGoalValuePresentation {
        metric.goalValuePresentation(totals: totals, goals: goals)
    }

    private var title: String {
        switch titleStyle {
        case .full:
            metric.title
        case .short:
            metric.shortTitle
        }
    }

    var body: some View {
        VStack(alignment: .center, spacing: style.verticalSpacing) {
            if style.showsTitleAfterValues == false {
                titleLine
            }

            currentValueLine

            goalLine
                .frame(maxWidth: .infinity, alignment: .center)

            if style.showsTitleAfterValues {
                titleLine
            }
        }
        .frame(maxWidth: .infinity, minHeight: minimumHeight, alignment: .center)
    }

    private var titleLine: some View {
        HStack(spacing: style.titleSpacing) {
            if style.showsTitleDot {
                Circle()
                    .fill(accentColor ?? metric.accentColor)
                    .frame(width: style.titleDotDiameter, height: style.titleDotDiameter)
            }

            Text(title)
                .font(style.titleFont)
                .foregroundStyle(style.titleColor)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private var currentValueLine: some View {
        if style.showsOverGoalIndicatorInValueLine, presentation.overGoalValueText != nil {
            HStack(spacing: 1) {
                currentValueText

                Text("↑")
                    .font(style.valueIndicatorFont)
                    .foregroundStyle(metric.overGoalHighlightColor)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)
            }
            .monospacedDigit()
            .frame(maxWidth: .infinity, alignment: .center)
        } else {
            currentValueText
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var currentValueText: some View {
        return Text(presentation.currentValueText)
            .font(style.valueFont)
            .foregroundStyle(style.valueColor)
            .lineLimit(1)
            .minimumScaleFactor(style.valueMinimumScaleFactor)
            .allowsTightening(true)
    }

    @ViewBuilder
    private var goalLine: some View {
        if style.showsOverGoalDeltaInGoalLine, let overGoalValueText = presentation.overGoalValueText {
            HStack(spacing: style.goalSpacing) {
                Text(presentation.goalValueText)
                    .foregroundStyle(style.baselineColor)
                    .lineLimit(1)
                    .minimumScaleFactor(style.baselineMinimumScaleFactor)

                Text(overGoalValueText)
                    .fontWeight(style.deltaWeight)
                    .foregroundStyle(metric.overGoalHighlightColor)
                    .lineLimit(1)
                    .minimumScaleFactor(style.baselineMinimumScaleFactor)
            }
            .font(style.baselineFont)
            .monospacedDigit()
        } else {
            Text(presentation.goalValueText)
                .font(style.baselineFont)
                .foregroundStyle(style.baselineColor)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(style.baselineMinimumScaleFactor)
                .allowsTightening(true)
        }
    }

}

struct MacroGoalValuePresentation {
    let currentValueText: String
    let goalValueText: String
    let overGoalValueText: String?
}

extension MacroMetric {
    var overGoalHighlightColor: Color {
        switch self {
        case .protein:
            accentColor
        case .carbs, .fat:
            .orange
        }
    }

    func goalValuePresentation(totals: NutritionSnapshot, goals: MacroGoalsSnapshot) -> MacroGoalValuePresentation {
        let currentValue = value(from: totals)
        let goalValue = goal(from: goals)
        let overGoalValue = currentValue - goalValue

        return MacroGoalValuePresentation(
            currentValueText: currentValue.roundedForDisplay,
            goalValueText: goalValue.roundedForDisplay,
            overGoalValueText: overGoalValue.hasVisiblePositiveDisplayValue ? "+\(overGoalValue.roundedForDisplay)" : nil
        )
    }
}
