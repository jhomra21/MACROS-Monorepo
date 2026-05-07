import Foundation
import SwiftData

@MainActor
struct LogEntryRepository {
    struct EditedEntryResolution {
        let draft: FoodDraft
        let secondaryNutrientBackfillState: SecondaryNutrientBackfillState?
    }

    struct EntryValues {
        let foodItemID: UUID?
        let foodName: String
        let brand: String?
        let source: FoodSource
        let barcode: String?
        let externalProductID: String?
        let sourceName: String?
        let sourceURL: String?
        let servingDescription: String
        let gramsPerServing: Double?
        let perServingNutrition: PerServingNutritionValues
        let quantityMode: QuantityMode
        let servingsConsumed: Double?
        let gramsConsumed: Double?
        let consumedNutrients: LoggedFoodNutrients

        init(
            draft: FoodDraft,
            quantityMode: QuantityMode,
            quantityAmount: Double,
            consumedNutrients: LoggedFoodNutrients
        ) {
            self.foodItemID = draft.foodItemID
            self.foodName = draft.name
            self.brand = draft.brandOrNil
            self.source = draft.source
            self.barcode = draft.barcodeOrNil
            self.externalProductID = draft.externalProductIDOrNil
            self.sourceName = draft.sourceNameOrNil
            self.sourceURL = draft.sourceURLOrNil
            self.servingDescription = draft.servingDescription
            self.gramsPerServing = draft.gramsPerServing
            perServingNutrition = draft.perServingNutritionValues
            self.quantityMode = quantityMode
            self.servingsConsumed = quantityMode == .servings ? quantityAmount : nil
            self.gramsConsumed = quantityMode == .grams ? quantityAmount : nil
            self.consumedNutrients = consumedNutrients
        }
    }

    let modelContext: ModelContext
    let onDailyTotalsChanged: ((ModelContainer) -> Void)?

    init(modelContext: ModelContext, onDailyTotalsChanged: ((ModelContainer) -> Void)? = nil) {
        self.modelContext = modelContext
        self.onDailyTotalsChanged = onDailyTotalsChanged
    }
}
