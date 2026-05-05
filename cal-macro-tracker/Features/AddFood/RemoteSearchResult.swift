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
            return product.productName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Unnamed product"
        case let .usda(food):
            return food.name.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Unnamed product"
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
            return food.barcode?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        }
    }

    var reviewNotes: [String] {
        switch self {
        case .openFoodFacts:
            return ["Selected from online packaged food search."]
        case .usda:
            return ["Selected from USDA packaged food search."]
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

    func makeDraft() throws -> FoodDraft {
        switch self {
        case let .openFoodFacts(product):
            return try BarcodeLookupMapper.makeDraft(from: product, source: .searchLookup)
        case let .usda(food):
            return USDAFoodDraftMapper.makeDraft(from: food)
        }
    }
}

extension String {
    var nilIfEmpty: String? {
        let trimmedValue = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
