import Foundation

struct RemoteSearchResult: Decodable, Identifiable, Hashable {
    let id: String
    let source: String
    let externalProductID: String
    let sourceName: String?
    let sourceURL: String?
    let name: String
    let brand: String?
    let barcode: String?
    let servingDescription: String
    let gramsPerServing: Double?
    let nutrition: Nutrition
    let requiredReviewNutrients: [RequiredNutritionReviewNutrient]

    struct Nutrition: Decodable, Hashable {
        let calories: Double?
        let protein: Double?
        let fat: Double?
        let carbs: Double?
        let saturatedFat: Double?
        let fiber: Double?
        let sugars: Double?
        let addedSugars: Double?
        let sodium: Double?
        let cholesterol: Double?
    }

    var cacheLookupExternalProductIDs: [String] {
        [externalProductID] + OpenFoodFactsIdentity.qualifiedExternalProductIDAliases(for: barcode)
    }

    var reviewNotes: [String] {
        requiredReviewNutrients.isEmpty ? [] : ["Check the values before logging."]
    }

    var nutritionPreview: PerServingNutritionValues? {
        guard requiredReviewNutrients.isEmpty else { return nil }
        return perServingNutrition
    }

    private var perServingNutrition: PerServingNutritionValues {
        PerServingNutritionValues(
            calories: nutrition.calories ?? 0,
            protein: nutrition.protein ?? 0,
            fat: nutrition.fat ?? 0,
            carbs: nutrition.carbs ?? 0,
            saturatedFat: nutrition.saturatedFat,
            fiber: nutrition.fiber,
            sugars: nutrition.sugars,
            addedSugars: nutrition.addedSugars,
            sodium: nutrition.sodium,
            cholesterol: nutrition.cholesterol
        )
    }

    func makeDraft() -> FoodDraft {
        FoodDraft(
            importedData: FoodDraftImportedData(
                name: name,
                brand: brand,
                source: .searchLookup,
                barcode: barcode,
                externalProductID: externalProductID,
                sourceName: sourceName ?? source,
                sourceURL: sourceURL,
                servingDescription: servingDescription,
                gramsPerServing: gramsPerServing,
                perServingNutrition: perServingNutrition
            )
        )
    }
}
