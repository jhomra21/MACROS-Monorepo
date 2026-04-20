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
