import Foundation

nonisolated enum WeightUnit: String, CaseIterable, Codable, Sendable {
    case kilograms
    case pounds

    static let preferenceKey = "weightUnit"

    var symbol: String { self == .kilograms ? "kg" : "lb" }
    var accessibilityName: String { self == .kilograms ? "kilograms" : "pounds" }

    func toDisplay(_ kilograms: Double) -> Double {
        self == .kilograms ? kilograms : kilograms / 0.45359237
    }

    func fromDisplay(_ value: Double) -> Double {
        self == .kilograms ? value : value * 0.45359237
    }

    static func initial(profileUnitSystem: GoalUnitSystem?, locale: Locale = .current) -> Self {
        if let profileUnitSystem {
            return profileUnitSystem == .imperial ? .pounds : .kilograms
        }
        return locale.measurementSystem == .us || locale.measurementSystem == .uk ? .pounds : .kilograms
    }

    @MainActor
    static func initializeIfNeeded(profileUnitSystem: GoalUnitSystem?, defaults: UserDefaults = .standard) {
        guard defaults.string(forKey: preferenceKey).flatMap(Self.init(rawValue:)) == nil else { return }
        defaults.set(initial(profileUnitSystem: profileUnitSystem).rawValue, forKey: preferenceKey)
    }
}
