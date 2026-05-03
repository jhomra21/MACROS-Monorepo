import Foundation
import SwiftData

@Model
final class LogEntry {
    var id: UUID
    var foodItemID: UUID?
    var dateLogged: Date
    var foodName: String
    var brand: String?
    var source: String
    var barcode: String?
    var externalProductID: String?
    var sourceName: String?
    var sourceURL: String?
    var servingDescription: String
    var gramsPerServing: Double?
    var caloriesPerServing: Double
    var proteinPerServing: Double
    var fatPerServing: Double
    var carbsPerServing: Double
    var saturatedFatPerServing: Double?
    var fiberPerServing: Double?
    var sugarsPerServing: Double?
    var addedSugarsPerServing: Double?
    var sodiumPerServing: Double?
    var cholesterolPerServing: Double?
    var quantityMode: String
    var servingsConsumed: Double?
    var gramsConsumed: Double?
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
    var secondaryNutrientBackfillStateRaw: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        foodItemID: UUID? = nil,
        dateLogged: Date,
        foodName: String,
        brand: String? = nil,
        source: FoodSource,
        barcode: String? = nil,
        externalProductID: String? = nil,
        sourceName: String? = nil,
        sourceURL: String? = nil,
        servingDescription: String,
        gramsPerServing: Double? = nil,
        caloriesPerServing: Double,
        proteinPerServing: Double,
        fatPerServing: Double,
        carbsPerServing: Double,
        saturatedFatPerServing: Double? = nil,
        fiberPerServing: Double? = nil,
        sugarsPerServing: Double? = nil,
        addedSugarsPerServing: Double? = nil,
        sodiumPerServing: Double? = nil,
        cholesterolPerServing: Double? = nil,
        quantityMode: QuantityMode,
        servingsConsumed: Double? = nil,
        gramsConsumed: Double? = nil,
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
        secondaryNutrientBackfillState: SecondaryNutrientBackfillState? = .current,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.foodItemID = foodItemID
        self.dateLogged = dateLogged
        self.foodName = foodName
        self.brand = brand
        self.source = source.rawValue
        self.barcode = barcode
        self.externalProductID = externalProductID
        self.sourceName = sourceName
        self.sourceURL = sourceURL
        self.servingDescription = servingDescription
        self.gramsPerServing = gramsPerServing
        self.caloriesPerServing = caloriesPerServing
        self.proteinPerServing = proteinPerServing
        self.fatPerServing = fatPerServing
        self.carbsPerServing = carbsPerServing
        self.saturatedFatPerServing = saturatedFatPerServing
        self.fiberPerServing = fiberPerServing
        self.sugarsPerServing = sugarsPerServing
        self.addedSugarsPerServing = addedSugarsPerServing
        self.sodiumPerServing = sodiumPerServing
        self.cholesterolPerServing = cholesterolPerServing
        self.quantityMode = quantityMode.rawValue
        self.servingsConsumed = servingsConsumed
        self.gramsConsumed = gramsConsumed
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
        self.secondaryNutrientBackfillStateRaw = secondaryNutrientBackfillState?.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var sourceKind: FoodSource {
        FoodSource(rawValue: source) ?? .custom
    }

    var barcodeOrNil: String? {
        LogEntry.trimmedText(from: barcode)
    }

    var externalProductIDOrNil: String? {
        LogEntry.trimmedText(from: externalProductID)
    }

    var sourceNameOrNil: String? {
        LogEntry.trimmedText(from: sourceName)
    }

    var sourceURLOrNil: String? {
        LogEntry.trimmedText(from: sourceURL)
    }

    var isMissingAllSecondaryPerServingNutrients: Bool {
        saturatedFatPerServing == nil
            && fiberPerServing == nil
            && sugarsPerServing == nil
            && addedSugarsPerServing == nil
            && sodiumPerServing == nil
            && cholesterolPerServing == nil
    }

    var isMissingAllSecondaryConsumedNutrients: Bool {
        saturatedFatConsumed == nil
            && fiberConsumed == nil
            && sugarsConsumed == nil
            && addedSugarsConsumed == nil
            && sodiumConsumed == nil
            && cholesterolConsumed == nil
    }

    var secondaryNutrientBackfillState: SecondaryNutrientBackfillState? {
        get {
            guard let secondaryNutrientBackfillStateRaw else { return nil }
            return SecondaryNutrientBackfillState(rawValue: secondaryNutrientBackfillStateRaw)
        }
        set {
            secondaryNutrientBackfillStateRaw = newValue?.rawValue
        }
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

    private static func trimmedText(from value: String?) -> String? {
        TextNormalization.trimmedNonEmpty(value)
    }
}
