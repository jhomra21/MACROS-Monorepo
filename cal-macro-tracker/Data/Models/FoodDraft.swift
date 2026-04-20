import Foundation

struct FoodDraft: Identifiable, Hashable {
    static let defaultServingDescription = "1 serving"

    var id: UUID = UUID()
    var foodItemID: UUID?
    var name: String = ""
    var brand: String = ""
    var source: FoodSource = .custom
    var barcode: String = ""
    var externalProductID: String = ""
    var sourceName: String = ""
    var sourceURL: String = ""
    var servingDescription: String = FoodDraft.defaultServingDescription
    var gramsPerServing: Double?
    var caloriesPerServing: Double = 0
    var proteinPerServing: Double = 0
    var fatPerServing: Double = 0
    var carbsPerServing: Double = 0
    var saturatedFatPerServing: Double?
    var fiberPerServing: Double?
    var sugarsPerServing: Double?
    var addedSugarsPerServing: Double?
    var sodiumPerServing: Double?
    var cholesterolPerServing: Double?
    var secondaryNutrientBackfillState: SecondaryNutrientBackfillState? = .current
    var saveAsCustomFood: Bool = true

    init() {}

    init(foodItem: FoodItem, saveAsCustomFood: Bool = false) {
        self.init(
            importedData: FoodDraftImportedData(
                name: foodItem.name,
                brand: foodItem.brand,
                source: foodItem.sourceKind,
                secondaryNutrientBackfillState: foodItem.secondaryNutrientBackfillState
                    ?? SecondaryNutrientBackfillPolicy.inferredState(for: foodItem),
                barcode: foodItem.barcode,
                externalProductID: foodItem.externalProductID,
                sourceName: foodItem.sourceName,
                sourceURL: foodItem.sourceURL,
                servingDescription: foodItem.servingDescription,
                gramsPerServing: foodItem.gramsPerServing,
                caloriesPerServing: foodItem.caloriesPerServing,
                proteinPerServing: foodItem.proteinPerServing,
                fatPerServing: foodItem.fatPerServing,
                carbsPerServing: foodItem.carbsPerServing,
                saturatedFatPerServing: foodItem.saturatedFatPerServing,
                fiberPerServing: foodItem.fiberPerServing,
                sugarsPerServing: foodItem.sugarsPerServing,
                addedSugarsPerServing: foodItem.addedSugarsPerServing,
                sodiumPerServing: foodItem.sodiumPerServing,
                cholesterolPerServing: foodItem.cholesterolPerServing
            ),
            foodItemID: foodItem.id,
            saveAsCustomFood: saveAsCustomFood
        )
    }

    init(logEntry: LogEntry, saveAsCustomFood: Bool = false) {
        self.init(
            importedData: FoodDraftImportedData(
                name: logEntry.foodName,
                brand: logEntry.brand,
                source: logEntry.sourceKind,
                secondaryNutrientBackfillState: logEntry.secondaryNutrientBackfillState
                    ?? SecondaryNutrientBackfillPolicy.inferredState(for: logEntry),
                barcode: logEntry.barcodeOrNil,
                externalProductID: logEntry.externalProductIDOrNil,
                sourceName: logEntry.sourceNameOrNil,
                sourceURL: logEntry.sourceURLOrNil,
                servingDescription: logEntry.servingDescription,
                gramsPerServing: logEntry.gramsPerServing,
                caloriesPerServing: logEntry.caloriesPerServing,
                proteinPerServing: logEntry.proteinPerServing,
                fatPerServing: logEntry.fatPerServing,
                carbsPerServing: logEntry.carbsPerServing,
                saturatedFatPerServing: logEntry.saturatedFatPerServing,
                fiberPerServing: logEntry.fiberPerServing,
                sugarsPerServing: logEntry.sugarsPerServing,
                addedSugarsPerServing: logEntry.addedSugarsPerServing,
                sodiumPerServing: logEntry.sodiumPerServing,
                cholesterolPerServing: logEntry.cholesterolPerServing
            ),
            foodItemID: logEntry.foodItemID,
            saveAsCustomFood: saveAsCustomFood
        )
    }

    init(importedData: FoodDraftImportedData, saveAsCustomFood: Bool = true) {
        self.init(importedData: importedData, foodItemID: nil, saveAsCustomFood: saveAsCustomFood)
    }

    private init(importedData: FoodDraftImportedData, foodItemID: UUID?, saveAsCustomFood: Bool) {
        self.id = UUID()
        self.foodItemID = foodItemID
        self.name = importedData.name
        self.brand = importedData.brand ?? ""
        self.source = importedData.source
        self.secondaryNutrientBackfillState = importedData.secondaryNutrientBackfillState
        self.barcode = importedData.barcode ?? ""
        self.externalProductID = importedData.externalProductID ?? ""
        self.sourceName = importedData.sourceName ?? ""
        self.sourceURL = importedData.sourceURL ?? ""
        self.servingDescription = importedData.servingDescription
        self.gramsPerServing = importedData.gramsPerServing
        self.caloriesPerServing = importedData.caloriesPerServing
        self.proteinPerServing = importedData.proteinPerServing
        self.fatPerServing = importedData.fatPerServing
        self.carbsPerServing = importedData.carbsPerServing
        self.saturatedFatPerServing = importedData.saturatedFatPerServing
        self.fiberPerServing = importedData.fiberPerServing
        self.sugarsPerServing = importedData.sugarsPerServing
        self.addedSugarsPerServing = importedData.addedSugarsPerServing
        self.sodiumPerServing = importedData.sodiumPerServing
        self.cholesterolPerServing = importedData.cholesterolPerServing
        self.saveAsCustomFood = saveAsCustomFood
    }
}
