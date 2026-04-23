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
    }

    let metric: MacroMetric
    let totals: NutritionSnapshot
    let goals: MacroGoalsSnapshot
    let alignment: HorizontalAlignment
    let titleStyle: TitleStyle
    let style: Style
    let minimumHeight: CGFloat?

    init(
        metric: MacroMetric,
        totals: NutritionSnapshot,
        goals: MacroGoalsSnapshot,
        alignment: HorizontalAlignment,
        titleStyle: TitleStyle,
        style: Style,
        minimumHeight: CGFloat? = nil
    ) {
        self.metric = metric
        self.totals = totals
        self.goals = goals
        self.alignment = alignment
        self.titleStyle = titleStyle
        self.style = style
        self.minimumHeight = minimumHeight
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

    private var frameAlignment: Alignment {
        alignment == .center ? .center : .leading
    }

    var body: some View {
        VStack(alignment: alignment, spacing: style.verticalSpacing) {
            titleLine

            currentValueLine

            goalLine
                .frame(maxWidth: .infinity, alignment: frameAlignment)
        }
        .frame(maxWidth: .infinity, minHeight: minimumHeight, alignment: frameAlignment)
    }

    private var titleLine: some View {
        HStack(spacing: style.titleSpacing) {
            if style.showsTitleDot {
                Circle()
                    .fill(metric.accentColor)
                    .frame(width: style.titleDotDiameter, height: style.titleDotDiameter)
            }

            Text(title)
                .font(style.titleFont)
                .foregroundStyle(style.titleColor)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
    }

    @ViewBuilder
    private var currentValueLine: some View {
        if style.showsOverGoalIndicatorInValueLine {
            if presentation.overGoalValueText != nil {
                HStack(spacing: 1) {
                    currentValueText

                    Text("↑")
                        .font(style.valueIndicatorFont)
                        .foregroundStyle(metric.overGoalHighlightColor)
                        .fixedSize(horizontal: true, vertical: false)
                        .layoutPriority(1)
                }
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: frameAlignment)
            } else {
                currentValueText
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
            }
        } else {
            currentValueText
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: frameAlignment)
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

extension MacroSummaryColumnView.Style {
    static let dashboardCard = MacroSummaryColumnView.Style(
        titleFont: .subheadline.weight(.medium),
        valueFont: .title3.weight(.semibold),
        baselineFont: .footnote,
        valueIndicatorFont: .title3.weight(.semibold),
        titleColor: .primary,
        valueColor: .primary,
        baselineColor: .secondary,
        showsTitleDot: true,
        titleSpacing: 8,
        titleDotDiameter: 10,
        verticalSpacing: 4,
        goalSpacing: 4,
        valueMinimumScaleFactor: 0.75,
        baselineMinimumScaleFactor: 0.75,
        deltaWeight: .bold,
        showsOverGoalIndicatorInValueLine: false,
        showsOverGoalDeltaInGoalLine: true
    )

    static let compact = MacroSummaryColumnView.Style(
        titleFont: .caption.weight(.medium),
        valueFont: .headline.weight(.semibold),
        baselineFont: .caption2,
        valueIndicatorFont: .headline.weight(.semibold),
        titleColor: .primary,
        valueColor: .primary,
        baselineColor: .secondary,
        showsTitleDot: true,
        titleSpacing: 6,
        titleDotDiameter: 8,
        verticalSpacing: 4,
        goalSpacing: 3,
        valueMinimumScaleFactor: 0.75,
        baselineMinimumScaleFactor: 0.75,
        deltaWeight: .bold,
        showsOverGoalIndicatorInValueLine: false,
        showsOverGoalDeltaInGoalLine: true
    )

    static func widgetSmall(valueFontSize: CGFloat) -> MacroSummaryColumnView.Style {
        MacroSummaryColumnView.Style(
            titleFont: .caption2.weight(.semibold),
            valueFont: .system(size: valueFontSize, weight: .semibold),
            baselineFont: .caption2.weight(.medium),
            valueIndicatorFont: .system(size: valueFontSize, weight: .semibold),
            titleColor: .secondary,
            valueColor: .primary,
            baselineColor: .secondary,
            showsTitleDot: false,
            titleSpacing: 0,
            titleDotDiameter: 0,
            verticalSpacing: 2,
            goalSpacing: 2,
            valueMinimumScaleFactor: 0.6,
            baselineMinimumScaleFactor: 0.65,
            deltaWeight: .bold,
            showsOverGoalIndicatorInValueLine: true,
            showsOverGoalDeltaInGoalLine: false
        )
    }

    static let widgetMedium = MacroSummaryColumnView.Style(
        titleFont: .caption.weight(.medium),
        valueFont: .headline.weight(.semibold),
        baselineFont: .caption2,
        valueIndicatorFont: .caption.weight(.semibold),
        titleColor: .secondary,
        valueColor: .primary,
        baselineColor: .secondary,
        showsTitleDot: false,
        titleSpacing: 0,
        titleDotDiameter: 0,
        verticalSpacing: 2,
        goalSpacing: 3,
        valueMinimumScaleFactor: 0.75,
        baselineMinimumScaleFactor: 0.75,
        deltaWeight: .bold,
        showsOverGoalIndicatorInValueLine: true,
        showsOverGoalDeltaInGoalLine: false
    )

    static let accessoryRectangular = MacroSummaryColumnView.Style(
        titleFont: .caption2.weight(.semibold),
        valueFont: .caption.weight(.semibold),
        baselineFont: .caption2,
        valueIndicatorFont: .caption2.weight(.semibold),
        titleColor: .secondary,
        valueColor: .primary,
        baselineColor: .secondary,
        showsTitleDot: false,
        titleSpacing: 0,
        titleDotDiameter: 0,
        verticalSpacing: 1,
        goalSpacing: 2,
        valueMinimumScaleFactor: 0.75,
        baselineMinimumScaleFactor: 0.65,
        deltaWeight: .bold,
        showsOverGoalIndicatorInValueLine: true,
        showsOverGoalDeltaInGoalLine: false
    )
}
