import Foundation
import SwiftUI

struct MacroRingPalette {
    let protein: Color
    let carbs: Color
    let fat: Color

    static let standard = MacroRingPalette(
        protein: Color(hex: MacroRingColorStorage.defaultProteinHex) ?? .blue,
        carbs: Color(hex: MacroRingColorStorage.defaultCarbHex) ?? .orange,
        fat: Color(hex: MacroRingColorStorage.defaultFatHex) ?? .pink
    )

    func color(for metric: MacroMetric) -> Color {
        switch metric {
        case .protein:
            protein
        case .carbs:
            carbs
        case .fat:
            fat
        }
    }
}

struct MacroRingColorStorage {
    static let proteinKey = "customProteinRingColor"
    static let carbKey = "customCarbRingColor"
    static let fatKey = "customFatRingColor"

    static let defaultProteinHex = "#2466E6"
    static let defaultCarbHex = "#EB8005"
    static let defaultFatHex = "#E62E70"

    var proteinHex: String
    var carbHex: String
    var fatHex: String

    var palette: MacroRingPalette {
        MacroRingPalette(
            protein: Color(hex: proteinHex) ?? MacroRingPalette.standard.protein,
            carbs: Color(hex: carbHex) ?? MacroRingPalette.standard.carbs,
            fat: Color(hex: fatHex) ?? MacroRingPalette.standard.fat
        )
    }

    var customPalette: MacroRingPalette? {
        guard proteinHex != Self.defaultProteinHex || carbHex != Self.defaultCarbHex || fatHex != Self.defaultFatHex else {
            return nil
        }

        return palette
    }

    static func defaultHex(for metric: MacroMetric) -> String {
        switch metric {
        case .protein:
            defaultProteinHex
        case .carbs:
            defaultCarbHex
        case .fat:
            defaultFatHex
        }
    }

    static func storedPalette(in defaults: UserDefaults = .macroRingColors) -> MacroRingPalette? {
        let proteinHex = defaults.string(forKey: proteinKey) ?? defaultProteinHex
        let carbHex = defaults.string(forKey: carbKey) ?? defaultCarbHex
        let fatHex = defaults.string(forKey: fatKey) ?? defaultFatHex
        return MacroRingColorStorage(
            proteinHex: proteinHex,
            carbHex: carbHex,
            fatHex: fatHex
        )
        .customPalette
    }

    static func migrateLegacyStandardDefaultsToAppGroup() {
        for key in [proteinKey, carbKey, fatKey] {
            migrateLegacyValue(forKey: key)
        }
    }

    private static func migrateLegacyValue(forKey key: String) {
        guard UserDefaults.macroRingColors.object(forKey: key) == nil else { return }
        guard let legacyValue = UserDefaults.standard.string(forKey: key) else { return }

        UserDefaults.macroRingColors.set(legacyValue, forKey: key)
    }
}

extension UserDefaults {
    static let macroRingColors = UserDefaults(suiteName: SharedAppConfiguration.appGroupIdentifier) ?? .standard
}

extension Color {
    init?(hex: String) {
        let normalizedHex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard normalizedHex.count == 6, let value = Int(normalizedHex, radix: 16) else { return nil }

        self.init(
            red: Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >> 8) & 0xFF) / 255.0,
            blue: Double(value & 0xFF) / 255.0
        )
    }

    var hexString: String? {
        guard let rgbComponents else { return nil }

        return String(
            format: "#%02X%02X%02X",
            Int((rgbComponents.red * 255).rounded()),
            Int((rgbComponents.green * 255).rounded()),
            Int((rgbComponents.blue * 255).rounded())
        )
    }

    func mixed(with color: Color, amount: Double) -> Color {
        guard let source = rgbComponents, let target = color.rgbComponents else { return self }
        let clampedAmount = min(max(amount, 0), 1)
        let retainedAmount = 1 - clampedAmount
        return Color(
            red: (source.red * retainedAmount) + (target.red * clampedAmount),
            green: (source.green * retainedAmount) + (target.green * clampedAmount),
            blue: (source.blue * retainedAmount) + (target.blue * clampedAmount)
        )
    }

    private var rgbComponents: (red: Double, green: Double, blue: Double)? {
        #if os(iOS)
        let nativeColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard nativeColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        return (Double(red), Double(green), Double(blue))
        #elseif os(macOS)
        guard let nativeColor = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        return (
            Double(nativeColor.redComponent),
            Double(nativeColor.greenComponent),
            Double(nativeColor.blueComponent)
        )
        #else
        return nil
        #endif
    }
}
