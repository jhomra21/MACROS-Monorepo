import Foundation

extension FoodItem {
    convenience init(importedData: FoodDraftImportedData, aliases: [String] = []) {
        self.init(
            name: importedData.name,
            brand: importedData.brand,
            source: importedData.source,
            barcode: importedData.barcode,
            externalProductID: importedData.externalProductID,
            sourceName: importedData.sourceName,
            sourceURL: importedData.sourceURL,
            servingDescription: importedData.servingDescription,
            gramsPerServing: importedData.gramsPerServing,
            caloriesPerServing: importedData.perServingNutritionValues.calories,
            proteinPerServing: importedData.perServingNutritionValues.protein,
            fatPerServing: importedData.perServingNutritionValues.fat,
            carbsPerServing: importedData.perServingNutritionValues.carbs,
            saturatedFatPerServing: importedData.perServingNutritionValues.saturatedFat,
            fiberPerServing: importedData.perServingNutritionValues.fiber,
            sugarsPerServing: importedData.perServingNutritionValues.sugars,
            addedSugarsPerServing: importedData.perServingNutritionValues.addedSugars,
            sodiumPerServing: importedData.perServingNutritionValues.sodium,
            cholesterolPerServing: importedData.perServingNutritionValues.cholesterol,
            secondaryNutrientBackfillState: importedData.secondaryNutrientBackfillState,
            aliases: aliases
        )
    }
}
