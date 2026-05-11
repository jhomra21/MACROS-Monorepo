import Foundation

enum RemoteSearchProvider: String, Hashable, Decodable {
    case openFoodFacts
    case usda

    var displayName: String {
        switch self {
        case .openFoodFacts:
            return "Open Food Facts"
        case .usda:
            return "USDA FoodData Central"
        }
    }
}

enum RemoteSearchResult: Identifiable, Hashable {
    case openFoodFacts(OpenFoodFactsProduct)
    case usda(USDAProxyFood)

    var id: String {
        switch self {
        case let .openFoodFacts(product):
            return "\(provider.rawValue):\(product.id)"
        case let .usda(food):
            return food.id
        }
    }

    var provider: RemoteSearchProvider {
        switch self {
        case .openFoodFacts:
            return .openFoodFacts
        case .usda:
            return .usda
        }
    }

    var name: String {
        switch self {
        case let .openFoodFacts(product):
            return TextNormalization.trimmedNonEmpty(product.productName) ?? "Unnamed product"
        case let .usda(food):
            return TextNormalization.trimmedNonEmpty(food.name) ?? "Unnamed product"
        }
    }

    var cacheLookupExternalProductIDs: [String] {
        switch self {
        case let .openFoodFacts(product):
            return product.cacheLookupExternalProductIDs
        case let .usda(food):
            return [food.id]
        }
    }

    var barcode: String? {
        switch self {
        case let .openFoodFacts(product):
            return product.normalizedBarcode
        case let .usda(food):
            return TextNormalization.trimmedNonEmpty(food.barcode)
        }
    }

    var reviewNotes: [String] {
        switch self {
        case let .openFoodFacts(product):
            if needsManualNutritionReview(product: product) {
                return ["Open Food Facts has this item but no nutrition values. Fill in the calories and macros before logging."]
            }
            return ["Selected from online packaged food search."]
        case .usda:
            return ["Selected from USDA packaged food search."]
        }
    }

    var requiredReviewNutrients: [RequiredNutritionReviewNutrient] {
        switch self {
        case let .openFoodFacts(product) where needsManualNutritionReview(product: product):
            return [.calories, .protein, .fat, .carbs]
        case .openFoodFacts, .usda:
            return []
        }
    }

    var nutritionPreview: PerServingNutritionValues? {
        switch self {
        case let .openFoodFacts(product):
            return BarcodeLookupMapper.perServingNutritionPreview(from: product)
        case let .usda(food):
            return food.importedData.perServingNutritionValues
        }
    }

    private func needsManualNutritionReview(product: OpenFoodFactsProduct) -> Bool {
        BarcodeLookupMapper.perServingNutritionPreview(from: product) == nil
    }

    func makeDraft() throws -> FoodDraft {
        switch self {
        case let .openFoodFacts(product):
            do {
                return try BarcodeLookupMapper.makeDraft(from: product, source: .searchLookup)
            } catch BarcodeLookupMapperError.missingNutrition {
                return BarcodeLookupMapper.makeManualReviewDraft(from: product, source: .searchLookup)
            }
        case let .usda(food):
            return USDAFoodDraftMapper.makeDraft(from: food)
        }
    }
}
