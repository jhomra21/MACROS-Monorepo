import SwiftUI

enum MacroRingColorStyle {
    case standard
    case accentedWidget
}

struct MacroRingSetView: View {
    let totals: NutritionSnapshot
    let goals: MacroGoalsSnapshot
    let ringDiameter: CGFloat
    let centerValueFontSize: CGFloat?
    let minimumLineWidth: CGFloat
    let showsGoalSubtitle: Bool
    let colorStyle: MacroRingColorStyle

    init(
        totals: NutritionSnapshot,
        goals: MacroGoalsSnapshot,
        ringDiameter: CGFloat,
        centerValueFontSize: CGFloat?,
        minimumLineWidth: CGFloat,
        showsGoalSubtitle: Bool,
        colorStyle: MacroRingColorStyle = .standard
    ) {
        self.totals = totals
        self.goals = goals
        self.ringDiameter = ringDiameter
        self.centerValueFontSize = centerValueFontSize
        self.minimumLineWidth = minimumLineWidth
        self.showsGoalSubtitle = showsGoalSubtitle
        self.colorStyle = colorStyle
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

    private var baseMetrics: [(track: Color, start: Color, end: Color)] {
        switch colorStyle {
        case .standard:
            [
                (
                    track: Color(red: 0.62, green: 0.75, blue: 0.93),
                    start: Color(red: 0.14, green: 0.40, blue: 0.90),
                    end: Color(red: 0.40, green: 0.68, blue: 1.0)
                ),
                (
                    track: Color(red: 0.84, green: 0.62, blue: 0.24),
                    start: Color(red: 0.92, green: 0.50, blue: 0.02),
                    end: Color(red: 1.0, green: 0.76, blue: 0.34)
                ),
                (
                    track: Color(red: 0.84, green: 0.48, blue: 0.62),
                    start: Color(red: 0.90, green: 0.18, blue: 0.44),
                    end: Color(red: 1.0, green: 0.44, blue: 0.62)
                )
            ]
        case .accentedWidget:
            [
                (track: .primary.opacity(0.16), start: .primary.opacity(0.55), end: .primary),
                (track: .primary.opacity(0.12), start: .primary.opacity(0.45), end: .primary.opacity(0.82)),
                (track: .primary.opacity(0.08), start: .primary.opacity(0.35), end: .primary.opacity(0.64))
            ]
        }
    }

    private var ringMetrics: [RingMetric] {
        let progresses = MacroMetric.allCases.map { metric in
            progress(consumed: metric.value(from: totals), goal: metric.goal(from: goals))
        }

        return zip(progresses, baseMetrics).map { progress, colors in
            RingMetric(
                progress: progress,
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

    private func dynamicSingleLapGradient(fraction: Double) -> AngularGradient {
        let span = max(fraction, 0.001) * 360.0
        let safeStartAngle: CGFloat = -15.0
        let totalSpan = span + 30.0
        let zeroLocation = abs(safeStartAngle) / totalSpan
        let tipLocation = (span + abs(safeStartAngle)) / totalSpan

        return AngularGradient(
            gradient: Gradient(stops: [
                .init(color: gradientStartColor, location: 0.0),
                .init(color: gradientStartColor, location: zeroLocation),
                .init(color: gradientEndColor, location: tipLocation),
                .init(color: gradientEndColor, location: 1.0)
            ]),
            center: .center,
            startAngle: .degrees(safeStartAngle),
            endAngle: .degrees(span + 15)
        )
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(resolvedTrackColor, lineWidth: lineWidth)

            if progress > 0 {
                let remainder = progress.truncatingRemainder(dividingBy: 1.0)
                let overlap = (remainder == 0 && progress >= 1.0) ? 1.0 : remainder
                let hasFullLap = progress > 1.0
                let startTrim: CGFloat = 0.0001
                let safeOverlap = max(startTrim, overlap == 1.0 ? 0.999 : overlap)

                if hasFullLap {
                    Circle()
                        .trim(from: startTrim, to: 0.999)
                        .stroke(
                            dynamicSingleLapGradient(fraction: 1.0),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

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
                        .rotationEffect(.degrees(overlap * 360))

                    Circle()
                        .trim(from: startTrim, to: safeOverlap)
                        .stroke(
                            gradientEndColor,
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
                        )
                        .rotationEffect(.degrees(-90))

                    Circle()
                        .fill(gradientEndColor)
                        .frame(width: lineWidth, height: lineWidth)
                        .offset(y: -diameter / 2)
                        .rotationEffect(.degrees(overlap * 360))
                } else {
                    let safeProgress = max(startTrim, progress == 1.0 ? 0.999 : progress)
                    Circle()
                        .trim(from: startTrim, to: safeProgress)
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
