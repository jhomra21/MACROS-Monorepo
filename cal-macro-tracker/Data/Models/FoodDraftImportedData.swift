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

    init(
        name: String,
        brand: String? = nil,
        source: FoodSource,
        secondaryNutrientBackfillState: SecondaryNutrientBackfillState? = .current,
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
        cholesterolPerServing: Double? = nil
    ) {
        self.name = name
        self.brand = brand
        self.source = source
        self.secondaryNutrientBackfillState = secondaryNutrientBackfillState
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
    }

    init(
        name: String,
        brand: String? = nil,
        source: FoodSource,
        secondaryNutrientBackfillState: SecondaryNutrientBackfillState? = .current,
        barcode: String? = nil,
        externalProductID: String? = nil,
        sourceName: String? = nil,
        sourceURL: String? = nil,
        servingDescription: String,
        gramsPerServing: Double? = nil,
        perServingNutrition: PerServingNutritionValues
    ) {
        self.init(
            name: name,
            brand: brand,
            source: source,
            secondaryNutrientBackfillState: secondaryNutrientBackfillState,
            barcode: barcode,
            externalProductID: externalProductID,
            sourceName: sourceName,
            sourceURL: sourceURL,
            servingDescription: servingDescription,
            gramsPerServing: gramsPerServing,
            caloriesPerServing: perServingNutrition.calories,
            proteinPerServing: perServingNutrition.protein,
            fatPerServing: perServingNutrition.fat,
            carbsPerServing: perServingNutrition.carbs,
            saturatedFatPerServing: perServingNutrition.saturatedFat,
            fiberPerServing: perServingNutrition.fiber,
            sugarsPerServing: perServingNutrition.sugars,
            addedSugarsPerServing: perServingNutrition.addedSugars,
            sodiumPerServing: perServingNutrition.sodium,
            cholesterolPerServing: perServingNutrition.cholesterol
        )
    }
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
