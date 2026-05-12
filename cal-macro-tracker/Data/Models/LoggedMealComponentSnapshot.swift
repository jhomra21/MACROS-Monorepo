import Foundation
import SwiftData

@Model
final class LoggedMealComponentSnapshot {
    var id: UUID
    var logEntryID: UUID
    var mealID: UUID
    var foodItemID: UUID
    var foodName: String
    var quantityMode: String
    var servingsAmount: Double?
    var gramsAmount: Double?
    var caloriesConsumed: Double
    var proteinConsumed: Double
    var fatConsumed: Double
    var carbsConsumed: Double
    var saturatedFatConsumed: Double?
    var fiberConsumed: Double?
    var sugarsConsumed: Double?
    var addedSugarsConsumed: Double?
    var sodiumConsumed: Double?
    var cholesterolConsumed: Double?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        logEntryID: UUID,
        mealID: UUID,
        foodItemID: UUID,
        foodName: String,
        quantityMode: QuantityMode,
        quantityAmount: Double,
        caloriesConsumed: Double,
        proteinConsumed: Double,
        fatConsumed: Double,
        carbsConsumed: Double,
        saturatedFatConsumed: Double? = nil,
        fiberConsumed: Double? = nil,
        sugarsConsumed: Double? = nil,
        addedSugarsConsumed: Double? = nil,
        sodiumConsumed: Double? = nil,
        cholesterolConsumed: Double? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.logEntryID = logEntryID
        self.mealID = mealID
        self.foodItemID = foodItemID
        self.foodName = foodName
        self.quantityMode = quantityMode.rawValue
        servingsAmount = quantityMode == .servings ? quantityAmount : nil
        gramsAmount = quantityMode == .grams ? quantityAmount : nil
        self.caloriesConsumed = caloriesConsumed
        self.proteinConsumed = proteinConsumed
        self.fatConsumed = fatConsumed
        self.carbsConsumed = carbsConsumed
        self.saturatedFatConsumed = saturatedFatConsumed
        self.fiberConsumed = fiberConsumed
        self.sugarsConsumed = sugarsConsumed
        self.addedSugarsConsumed = addedSugarsConsumed
        self.sodiumConsumed = sodiumConsumed
        self.cholesterolConsumed = cholesterolConsumed
        self.createdAt = createdAt
    }

    var quantityModeKind: QuantityMode {
        QuantityMode(rawValue: quantityMode) ?? .servings
    }

    var quantityAmount: Double {
        switch quantityModeKind {
        case .servings:
            servingsAmount ?? 0
        case .grams:
            gramsAmount ?? 0
        }
    }
}
