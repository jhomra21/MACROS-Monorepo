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
            caloriesPerServing: importedData.caloriesPerServing,
            proteinPerServing: importedData.proteinPerServing,
            fatPerServing: importedData.fatPerServing,
            carbsPerServing: importedData.carbsPerServing,
            saturatedFatPerServing: importedData.saturatedFatPerServing,
            fiberPerServing: importedData.fiberPerServing,
            sugarsPerServing: importedData.sugarsPerServing,
            addedSugarsPerServing: importedData.addedSugarsPerServing,
            sodiumPerServing: importedData.sodiumPerServing,
            cholesterolPerServing: importedData.cholesterolPerServing,
            secondaryNutrientBackfillState: importedData.secondaryNutrientBackfillState,
            aliases: aliases
        )
    }
}
