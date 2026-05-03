import Foundation

enum FoodSource: String, Codable, CaseIterable {
    case common
    case custom
    case barcodeLookup
    case labelScan
    case searchLookup
}

enum QuantityMode: String, Codable, CaseIterable {
    case servings
    case grams
}

enum SecondaryNutrientBackfillState: String, Codable {
    case current
    case needsRepair
    case notRepairable
}

enum TextNormalization {
    static func trimmedNonEmpty(_ value: String?) -> String? {
        guard let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmedValue.isEmpty else {
            return nil
        }

        return trimmedValue
    }

    static func normalizedSearchText(_ value: String?) -> String? {
        trimmedNonEmpty(value)?.lowercased()
    }
}
