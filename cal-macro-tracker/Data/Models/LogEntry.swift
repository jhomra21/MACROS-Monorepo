import Foundation
import SwiftData

@Model
final class LogEntry {
    var id: UUID
    var dateLogged: Date
    var foodName: String
    var brand: String?
    var source: String
    var servingDescription: String
    var gramsPerServing: Double?
    var caloriesPerServing: Double
    var proteinPerServing: Double
    var fatPerServing: Double
    var carbsPerServing: Double
    var quantityMode: String
    var servingsConsumed: Double?
    var gramsConsumed: Double?
    var caloriesConsumed: Double
    var proteinConsumed: Double
    var fatConsumed: Double
    var carbsConsumed: Double
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        dateLogged: Date,
        foodName: String,
        brand: String? = nil,
        source: FoodSource,
        servingDescription: String,
        gramsPerServing: Double? = nil,
        caloriesPerServing: Double,
        proteinPerServing: Double,
        fatPerServing: Double,
        carbsPerServing: Double,
        quantityMode: QuantityMode,
        servingsConsumed: Double? = nil,
        gramsConsumed: Double? = nil,
        caloriesConsumed: Double,
        proteinConsumed: Double,
        fatConsumed: Double,
        carbsConsumed: Double,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.dateLogged = dateLogged
        self.foodName = foodName
        self.brand = brand
        self.source = source.rawValue
        self.servingDescription = servingDescription
        self.gramsPerServing = gramsPerServing
        self.caloriesPerServing = caloriesPerServing
        self.proteinPerServing = proteinPerServing
        self.fatPerServing = fatPerServing
        self.carbsPerServing = carbsPerServing
        self.quantityMode = quantityMode.rawValue
        self.servingsConsumed = servingsConsumed
        self.gramsConsumed = gramsConsumed
        self.caloriesConsumed = caloriesConsumed
        self.proteinConsumed = proteinConsumed
        self.fatConsumed = fatConsumed
        self.carbsConsumed = carbsConsumed
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var sourceKind: FoodSource {
        FoodSource(rawValue: source) ?? .custom
    }

    var quantityModeKind: QuantityMode {
        QuantityMode(rawValue: quantityMode) ?? .servings
    }

    var quantitySummary: String {
        switch quantityModeKind {
        case .servings:
            return "\((servingsConsumed ?? 0).roundedForDisplay) servings"
        case .grams:
            return "\((gramsConsumed ?? 0).roundedForDisplay) g"
        }
    }
}
