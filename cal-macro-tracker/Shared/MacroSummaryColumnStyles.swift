import SwiftUI

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
        showsOverGoalDeltaInGoalLine: true,
        showsTitleAfterValues: true
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
        showsOverGoalDeltaInGoalLine: true,
        showsTitleAfterValues: false
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
            showsOverGoalDeltaInGoalLine: false,
            showsTitleAfterValues: false
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
        showsOverGoalDeltaInGoalLine: false,
        showsTitleAfterValues: false
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
        showsOverGoalDeltaInGoalLine: false,
        showsTitleAfterValues: false
    )
}
