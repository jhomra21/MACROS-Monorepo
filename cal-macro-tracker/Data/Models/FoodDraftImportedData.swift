import Foundation

struct FoodDraftImportedData: Hashable {
    var name: String
    var brand: String? = nil
    var source: FoodSource
    var secondaryNutrientBackfillState: SecondaryNutrientBackfillState? = .current
    var barcode: String? = nil
    var externalProductID: String? = nil
    var sourceName: String? = nil
    var sourceURL: String? = nil
    var servingDescription: String
    var gramsPerServing: Double? = nil
    var caloriesPerServing: Double
    var proteinPerServing: Double
    var fatPerServing: Double
    var carbsPerServing: Double
    var saturatedFatPerServing: Double? = nil
    var fiberPerServing: Double? = nil
    var sugarsPerServing: Double? = nil
    var addedSugarsPerServing: Double? = nil
    var sodiumPerServing: Double? = nil
    var cholesterolPerServing: Double? = nil
}

protocol FoodDraftImportedDataConvertible {
    var name: String { get }
    var brand: String? { get }
    var source: FoodSource { get }
    var secondaryNutrientBackfillState: SecondaryNutrientBackfillState? { get }
    var barcode: String? { get }
    var externalProductID: String? { get }
    var sourceName: String? { get }
    var sourceURL: String? { get }
    var servingDescription: String { get }
    var gramsPerServing: Double? { get }
    var caloriesPerServing: Double { get }
    var proteinPerServing: Double { get }
    var fatPerServing: Double { get }
    var carbsPerServing: Double { get }
    var saturatedFatPerServing: Double? { get }
    var fiberPerServing: Double? { get }
    var sugarsPerServing: Double? { get }
    var addedSugarsPerServing: Double? { get }
    var sodiumPerServing: Double? { get }
    var cholesterolPerServing: Double? { get }
}

extension FoodDraftImportedDataConvertible {
    var brand: String? { nil }
    var secondaryNutrientBackfillState: SecondaryNutrientBackfillState? { .current }
    var barcode: String? { nil }
    var externalProductID: String? { nil }
    var sourceName: String? { nil }
    var sourceURL: String? { nil }

    var importedData: FoodDraftImportedData {
        FoodDraftImportedData(convertible: self)
    }
}

extension FoodDraftImportedData {
    init(convertible: FoodDraftImportedDataConvertible) {
        self.init(
            name: convertible.name,
            brand: convertible.brand,
            source: convertible.source,
            secondaryNutrientBackfillState: convertible.secondaryNutrientBackfillState,
            barcode: convertible.barcode,
            externalProductID: convertible.externalProductID,
            sourceName: convertible.sourceName,
            sourceURL: convertible.sourceURL,
            servingDescription: convertible.servingDescription,
            gramsPerServing: convertible.gramsPerServing,
            caloriesPerServing: convertible.caloriesPerServing,
            proteinPerServing: convertible.proteinPerServing,
            fatPerServing: convertible.fatPerServing,
            carbsPerServing: convertible.carbsPerServing,
            saturatedFatPerServing: convertible.saturatedFatPerServing,
            fiberPerServing: convertible.fiberPerServing,
            sugarsPerServing: convertible.sugarsPerServing,
            addedSugarsPerServing: convertible.addedSugarsPerServing,
            sodiumPerServing: convertible.sodiumPerServing,
            cholesterolPerServing: convertible.cholesterolPerServing
        )
    }
}
