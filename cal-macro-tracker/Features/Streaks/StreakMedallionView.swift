import SwiftUI

/// A badge drawn in the app's ring style: one to three concentric rings in the macro ring colors around the day count.
/// Earned badges draw `progress` of each ring; locked badges draw tertiary rings and no color.
struct StreakMedallionView: View {
    let badge: StreakBadge
    let palette: MacroRingPalette
    var isEarned = true
    var progress: Double = 1
    var diameter: CGFloat = 72

    private var lineWidth: CGFloat { max(3, diameter * 0.08) }
    private var ringStep: CGFloat { lineWidth * 2 - max(0.3, diameter * 0.004) }
    private var innerDiameter: CGFloat { ringDiameter(at: badge.ringCount - 1) - lineWidth }
    private var fillsCenter: Bool { badge.days >= StreakBadge.sixMonths.days }
    private var hasLaurels: Bool { badge.days >= StreakBadge.oneYear.days }

    var body: some View {
        HStack(spacing: 0) {
            if hasLaurels {
                laurel("laurel.leading")
            }
            ZStack {
                if fillsCenter && isEarned {
                    Circle()
                        .fill(Color.primary.opacity(0.1))
                        .frame(width: innerDiameter, height: innerDiameter)
                }
                ForEach(0..<badge.ringCount, id: \.self) { index in
                    ring(at: index)
                }
                Text("\(badge.days)")
                    .font(.system(size: innerDiameter * 0.5, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(isEarned ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                    .frame(width: innerDiameter)
            }
            .frame(width: diameter, height: diameter)
            if hasLaurels {
                laurel("laurel.trailing")
            }
        }
        .frame(width: diameter + (hasLaurels ? diameter * 0.24 : 0), height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(badge.title), \(badge.days) days")
        .accessibilityValue(isEarned ? "Earned" : "Locked")
    }

    private func laurel(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: diameter * 0.21, weight: .medium))
            .foregroundStyle(isEarned ? AnyShapeStyle(.secondary) : AnyShapeStyle(.quaternary))
    }

    private func ringDiameter(at index: Int) -> CGFloat {
        max(lineWidth * 2, diameter - lineWidth - ringStep * CGFloat(index))
    }

    @ViewBuilder
    private func ring(at index: Int) -> some View {
        let size = ringDiameter(at: index)
        if isEarned {
            let color = palette.color(for: MacroMetric.allCases[index])
            ZStack {
                Circle().stroke(color.opacity(0.22), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(colors: [color, color.mixed(with: .white, amount: 0.28), color], center: .center),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: size, height: size)
        } else {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: lineWidth)
                .frame(width: size, height: size)
        }
    }
}

/// The ring colors the Today rings use: the user's custom colors with Pro, the standard ones otherwise.
struct StreakPaletteReader<Content: View>: View {
    @Environment(AppEntitlements.self) private var entitlements
    @AppStorage(AppStorageKeys.customProteinRingColor, store: .macroRingColors) private var proteinHex =
        MacroRingColorStorage.defaultProteinHex
    @AppStorage(AppStorageKeys.customCarbRingColor, store: .macroRingColors) private var carbHex =
        MacroRingColorStorage.defaultCarbHex
    @AppStorage(AppStorageKeys.customFatRingColor, store: .macroRingColors) private var fatHex =
        MacroRingColorStorage.defaultFatHex
    @ViewBuilder let content: (MacroRingPalette) -> Content

    var body: some View {
        content(palette)
    }

    private var palette: MacroRingPalette {
        guard entitlements.canUse(.customMacroRingColors) else { return .standard }
        return MacroRingColorStorage(proteinHex: proteinHex, carbHex: carbHex, fatHex: fatHex).customPalette ?? .standard
    }
}
