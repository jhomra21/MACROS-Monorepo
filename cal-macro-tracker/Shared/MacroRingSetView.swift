import SwiftUI

enum MacroRingColorStyle {
    case standard
    case accentedWidget
    case custom(MacroRingPalette)
}

struct MacroRingSetView: View {
    let totals: NutritionSnapshot
    let goals: MacroGoalsSnapshot
    let ringDiameter: CGFloat
    let centerValueFontSize: CGFloat?
    let minimumLineWidth: CGFloat
    let showsGoalSubtitle: Bool
    let colorStyle: MacroRingColorStyle
    let selectedMetric: MacroMetric?

    init(
        totals: NutritionSnapshot,
        goals: MacroGoalsSnapshot,
        ringDiameter: CGFloat,
        centerValueFontSize: CGFloat?,
        minimumLineWidth: CGFloat,
        showsGoalSubtitle: Bool,
        colorStyle: MacroRingColorStyle = .standard,
        selectedMetric: MacroMetric? = nil
    ) {
        self.totals = totals
        self.goals = goals
        self.ringDiameter = ringDiameter
        self.centerValueFontSize = centerValueFontSize
        self.minimumLineWidth = minimumLineWidth
        self.showsGoalSubtitle = showsGoalSubtitle
        self.colorStyle = colorStyle
        self.selectedMetric = selectedMetric
    }

    private struct RingMetric {
        let progress: Double
        let trackColor: Color
        let gradientStartColor: Color
        let gradientEndColor: Color
    }

    private var ringLineWidth: CGFloat {
        max(minimumLineWidth, ringDiameter * 0.08)
    }

    private var ringBandOverlap: CGFloat {
        max(0.3, ringDiameter * 0.004)
    }

    private var minimumRingDiameter: CGFloat {
        max(ringLineWidth * 2, 1)
    }

    private typealias RingColors = (track: Color, start: Color, end: Color)

    private func baseColors(for metric: MacroMetric) -> RingColors {
        switch colorStyle {
        case .standard:
            standardColors(for: metric)
        case .accentedWidget:
            accentedWidgetColors(for: metric)
        case let .custom(palette):
            customColors(for: metric, palette: palette)
        }
    }

    private func standardColors(for metric: MacroMetric) -> RingColors {
        let start = MacroRingPalette.standard.color(for: metric)
        return switch metric {
        case .protein:
            (
                track: Color(red: 0.62, green: 0.75, blue: 0.93),
                start: start,
                end: Color(red: 0.40, green: 0.68, blue: 1.0)
            )
        case .carbs:
            (
                track: Color(red: 0.84, green: 0.62, blue: 0.24),
                start: start,
                end: Color(red: 1.0, green: 0.76, blue: 0.34)
            )
        case .fat:
            (
                track: Color(red: 0.84, green: 0.48, blue: 0.62),
                start: start,
                end: Color(red: 1.0, green: 0.44, blue: 0.62)
            )
        }
    }

    private func accentedWidgetColors(for metric: MacroMetric) -> RingColors {
        switch metric {
        case .protein:
            (track: .primary.opacity(0.16), start: .primary.opacity(0.55), end: .primary)
        case .carbs:
            (track: .primary.opacity(0.12), start: .primary.opacity(0.45), end: .primary.opacity(0.82))
        case .fat:
            (track: .primary.opacity(0.08), start: .primary.opacity(0.35), end: .primary.opacity(0.64))
        }
    }

    private func customColors(for metric: MacroMetric, palette: MacroRingPalette) -> RingColors {
        let color = palette.color(for: metric)
        return (track: color.opacity(0.45), start: color.opacity(0.82), end: color)
    }

    private func colors(for metric: MacroMetric) -> RingColors {
        guard let selectedMetric, selectedMetric != metric else {
            return baseColors(for: metric)
        }

        return (track: .secondary.opacity(0.18), start: .secondary.opacity(0.38), end: .secondary.opacity(0.62))
    }

    private var ringMetrics: [RingMetric] {
        MacroMetric.allCases.map { metric in
            let colors = colors(for: metric)
            return RingMetric(
                progress: progress(consumed: metric.value(from: totals), goal: metric.goal(from: goals)),
                trackColor: colors.track,
                gradientStartColor: colors.start,
                gradientEndColor: colors.end
            )
        }
    }

    var body: some View {
        ZStack {
            ForEach(Array(ringMetrics.enumerated()), id: \.offset) { index, metric in
                GoalProgressRing(
                    diameter: ringDiameter(at: index),
                    lineWidth: ringLineWidth,
                    progress: metric.progress,
                    trackColor: metric.trackColor,
                    gradientStartColor: metric.gradientStartColor,
                    gradientEndColor: metric.gradientEndColor
                )
            }

            if let centerValueFontSize {
                VStack(spacing: showsGoalSubtitle ? 4 : 0) {
                    Text(totals.calories.roundedForDisplay)
                        .font(.system(size: centerValueFontSize, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)

                    if showsGoalSubtitle {
                        Text("of \(goals.calorieGoal.roundedForDisplay) kcal")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, ringDiameter * 0.18)
                .padding(.vertical, ringDiameter * (showsGoalSubtitle ? 0.10 : 0.06))
            }
        }
        .frame(width: ringDiameter, height: ringDiameter)
    }

    private func ringDiameter(at index: Int) -> CGFloat {
        guard index > 0 else { return max(ringDiameter, minimumRingDiameter) }

        var diameter = max(ringDiameter, minimumRingDiameter)
        for _ in 1...index {
            diameter = max(minimumRingDiameter, diameter - ((ringLineWidth * 2) - ringBandOverlap))
        }

        return diameter
    }

    private func progress(consumed: Double, goal: Double) -> Double {
        guard goal > 0 else { return 0 }
        return max(consumed / goal, 0)
    }
}

private struct GoalProgressRing: View {
    @Environment(\.colorScheme) private var colorScheme

    let diameter: CGFloat
    let lineWidth: CGFloat
    let progress: Double
    let trackColor: Color
    let gradientStartColor: Color
    let gradientEndColor: Color

    private var resolvedTrackColor: Color {
        colorScheme == .dark ? trackColor.opacity(0.2) : trackColor.opacity(0.45)
    }

    private var usesOverlapRenderer: Bool {
        progress >= 1.0
    }

    private var overlapFraction: Double {
        let remainder = progress.truncatingRemainder(dividingBy: 1.0)
        return (remainder == 0 && usesOverlapRenderer) ? 1.0 : remainder
    }

    private var overlapTailLength: Double {
        0.15
    }

    private func dynamicSingleLapGradient(fraction: Double) -> AngularGradient {
        let span = max(fraction, 0.001) * 360.0
        return AngularGradient(
            gradient: Gradient(colors: [gradientStartColor, gradientEndColor]),
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(span)
        )
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(resolvedTrackColor, lineWidth: lineWidth)

            if progress > 0 {
                if usesOverlapRenderer {
                    // Exact-goal and exact-multiple states intentionally use the overlap renderer.
                    // A full lap still reads as one continuous ouroboros ring with the seam hidden.
                    Circle()
                        .stroke(
                            dynamicSingleLapGradient(fraction: 1.0),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90 + (overlapFraction * 360)))

                    Circle()
                        .fill(Color.black)
                        .frame(width: lineWidth * 0.9, height: lineWidth * 0.9)
                        .shadow(
                            color: .black.opacity(colorScheme == .dark ? 0.8 : 0.45),
                            radius: lineWidth * 0.25,
                            x: -lineWidth * 0.15,
                            y: 0
                        )
                        .offset(y: -diameter / 2)
                        .rotationEffect(.degrees(overlapFraction * 360))

                    let tailSpan = overlapTailLength * 360.0

                    Circle()
                        .trim(from: 0.0, to: overlapTailLength)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(stops: [
                                    .init(color: gradientEndColor.opacity(0), location: 0.0),
                                    .init(color: gradientEndColor, location: 0.90),
                                    .init(color: gradientEndColor, location: 1.0)
                                ]),
                                center: .center,
                                startAngle: .degrees(0),
                                endAngle: .degrees(tailSpan)
                            ),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90 + ((overlapFraction - overlapTailLength) * 360)))
                        .mask {
                            Circle()
                                .trim(from: 0.0, to: overlapTailLength + 0.1)
                                .stroke(style: StrokeStyle(lineWidth: lineWidth * 2, lineCap: .butt))
                                .rotationEffect(.degrees(-90 + ((overlapFraction - overlapTailLength) * 360)))
                        }
                } else {
                    Circle()
                        .trim(from: 0.0, to: progress)
                        .stroke(
                            dynamicSingleLapGradient(fraction: progress),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                }
            }
        }
        .frame(width: diameter, height: diameter)
    }
}
