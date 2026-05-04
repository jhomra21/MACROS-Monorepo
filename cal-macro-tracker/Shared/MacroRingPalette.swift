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
        #if os(iOS)
        let nativeColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard nativeColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        #elseif os(macOS)
        guard let nativeColor = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        let red = nativeColor.redComponent
        let green = nativeColor.greenComponent
        let blue = nativeColor.blueComponent
        #else
        return nil
        #endif

        return String(
            format: "#%02X%02X%02X",
            Int((red * 255).rounded()),
            Int((green * 255).rounded()),
            Int((blue * 255).rounded())
        )
    }
}
