import Foundation

enum BarcodeLookupMapperError: LocalizedError {
    case missingNutrition

    var errorDescription: String? {
        switch self {
        case .missingNutrition:
            "The selected product does not include enough nutrition data to prefill a food entry."
        }
    }
}

struct BarcodeLookupMapper {
    private enum RequiredNutritionBasisKind {
        case serving
        case scaledServing
        case per100g
    }

    private struct RequiredNutritionBasis {
        let kind: RequiredNutritionBasisKind
        let servingDescription: String
        let gramsPerServing: Double?
        let calories: Double
        let protein: Double
        let fat: Double
        let carbs: Double
    }

    private struct NutritionBasis {
        let servingDescription: String
        let gramsPerServing: Double?
        let calories: Double
        let protein: Double
        let fat: Double
        let carbs: Double
        let saturatedFat: Double?
        let fiber: Double?
        let sugars: Double?
        let addedSugars: Double?
        let sodium: Double?
        let cholesterol: Double?
    }

    static func makeDraft(from product: OpenFoodFactsProduct, barcode: String) throws -> FoodDraft {
        try makeDraft(from: product, source: .barcodeLookup, barcode: barcode)
    }

    static func makeDraft(
        from product: OpenFoodFactsProduct,
        source: FoodSource,
        barcode: String? = nil
    ) throws -> FoodDraft {
        let name = product.productName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let nutritionBasis = try nutritionBasis(for: product)
        let resolvedBarcode =
            OpenFoodFactsIdentity.normalizedBarcode(
                barcode: barcode ?? product.code,
                externalProductID: product.externalProductID,
                sourceURL: product.url
            ) ?? ""
        return FoodDraft(
            importedData: FoodDraftImportedData(
                name: name,
                brand: product.brands?.trimmingCharacters(in: .whitespacesAndNewlines),
                source: source,
                barcode: resolvedBarcode,
                externalProductID: product.resolvedExternalProductID(preferredBarcode: resolvedBarcode),
                sourceName: "Open Food Facts",
                sourceURL: OpenFoodFactsIdentity.persistedProductURL(
                    barcode: resolvedBarcode,
                    sourceURL: product.url
                ),
                servingDescription: nutritionBasis.servingDescription,
                gramsPerServing: nutritionBasis.gramsPerServing,
                caloriesPerServing: nutritionBasis.calories,
                proteinPerServing: nutritionBasis.protein,
                fatPerServing: nutritionBasis.fat,
                carbsPerServing: nutritionBasis.carbs,
                saturatedFatPerServing: nutritionBasis.saturatedFat,
                fiberPerServing: nutritionBasis.fiber,
                sugarsPerServing: nutritionBasis.sugars,
                addedSugarsPerServing: nutritionBasis.addedSugars,
                sodiumPerServing: nutritionBasis.sodium,
                cholesterolPerServing: nutritionBasis.cholesterol
            )
        )
    }

    private static func nutritionBasis(for product: OpenFoodFactsProduct) throws -> NutritionBasis {
        guard let requiredNutritionBasis = requiredNutritionBasis(for: product) else {
            throw BarcodeLookupMapperError.missingNutrition
        }

        let nutriments = product.nutrition
        return NutritionBasis(
            servingDescription: requiredNutritionBasis.servingDescription,
            gramsPerServing: requiredNutritionBasis.gramsPerServing,
            calories: requiredNutritionBasis.calories,
            protein: requiredNutritionBasis.protein,
            fat: requiredNutritionBasis.fat,
            carbs: requiredNutritionBasis.carbs,
            saturatedFat: resolvedOptionalNutrient(
                for: requiredNutritionBasis,
                servingValue: nutriments.saturatedFatPerServing,
                per100gValue: nutriments.saturatedFatPer100g
            ),
            fiber: resolvedOptionalNutrient(
                for: requiredNutritionBasis,
                servingValue: nutriments.fiberPerServing,
                per100gValue: nutriments.fiberPer100g
            ),
            sugars: resolvedOptionalNutrient(
                for: requiredNutritionBasis,
                servingValue: nutriments.sugarsPerServing,
                per100gValue: nutriments.sugarsPer100g
            ),
            addedSugars: resolvedOptionalNutrient(
                for: requiredNutritionBasis,
                servingValue: nutriments.addedSugarsPerServing,
                per100gValue: nutriments.addedSugarsPer100g
            ),
            sodium: resolvedOptionalNutrient(
                for: requiredNutritionBasis,
                servingValue: sodiumPerServing(for: nutriments),
                per100gValue: sodiumPer100g(for: nutriments)
            ),
            cholesterol: resolvedOptionalNutrient(
                for: requiredNutritionBasis,
                servingValue: milligrams(fromGrams: nutriments.cholesterolPerServing),
                per100gValue: milligrams(fromGrams: nutriments.cholesterolPer100g)
            )
        )
    }

    private static func requiredNutritionBasis(for product: OpenFoodFactsProduct) -> RequiredNutritionBasis? {
        servingRequiredNutrition(for: product)
            ?? scaledServingRequiredNutritionFrom100g(for: product)
            ?? requiredNutritionPer100g(for: product)
    }

    private static func servingRequiredNutrition(for product: OpenFoodFactsProduct) -> RequiredNutritionBasis? {
        let nutriments = product.nutrition
        guard let calories = nutriments.caloriesPerServing,
            let protein = nutriments.proteinPerServing,
            let fat = nutriments.fatPerServing,
            let carbs = nutriments.carbsPerServing
        else {
            return nil
        }

        return RequiredNutritionBasis(
            kind: .serving,
            servingDescription: servingDescription(
                for: product,
                fallback: FoodDraft.defaultServingDescription
            ),
            gramsPerServing: gramsPerServing(for: product),
            calories: calories,
            protein: protein,
            fat: fat,
            carbs: carbs
        )
    }

    private static func scaledServingRequiredNutritionFrom100g(for product: OpenFoodFactsProduct) -> RequiredNutritionBasis? {
        let nutriments = product.nutrition
        guard let caloriesPer100g = nutriments.caloriesPer100g,
            let proteinPer100g = nutriments.proteinPer100g,
            let fatPer100g = nutriments.fatPer100g,
            let carbsPer100g = nutriments.carbsPer100g,
            let servingGrams = gramsPerServing(for: product)
        else {
            return nil
        }

        let multiplier = servingGrams / 100
        return RequiredNutritionBasis(
            kind: .scaledServing,
            servingDescription: servingDescription(
                for: product,
                fallback: "\(servingGrams.roundedForDisplay) g"
            ),
            gramsPerServing: servingGrams,
            calories: caloriesPer100g * multiplier,
            protein: proteinPer100g * multiplier,
            fat: fatPer100g * multiplier,
            carbs: carbsPer100g * multiplier
        )
    }

    private static func requiredNutritionPer100g(for product: OpenFoodFactsProduct) -> RequiredNutritionBasis? {
        let nutriments = product.nutrition
        guard let calories = nutriments.caloriesPer100g,
            let protein = nutriments.proteinPer100g,
            let fat = nutriments.fatPer100g,
            let carbs = nutriments.carbsPer100g
        else {
            return nil
        }

        return RequiredNutritionBasis(
            kind: .per100g,
            servingDescription: "100 g",
            gramsPerServing: 100,
            calories: calories,
            protein: protein,
            fat: fat,
            carbs: carbs
        )
    }

    private static func servingDescription(for product: OpenFoodFactsProduct, fallback: String) -> String {
        if let servingSize = product.servingSize?.trimmingCharacters(in: .whitespacesAndNewlines), !servingSize.isEmpty {
            return servingSize
        }

        if let servingQuantity = product.servingQuantity, let servingQuantityUnit = product.servingQuantityUnit,
            !servingQuantityUnit.isEmpty
        {
            return "\(servingQuantity.roundedForDisplay) \(servingQuantityUnit)"
        }

        return fallback
    }

    private static func gramsPerServing(for product: OpenFoodFactsProduct) -> Double? {
        guard let servingQuantity = product.servingQuantity,
            let servingQuantityUnit = product.servingQuantityUnit?.lowercased(),
            servingQuantityUnit == "g"
        else {
            return nil
        }

        return servingQuantity
    }

    private static func sodiumPerServing(for nutriments: OpenFoodFactsProduct.Nutriments) -> Double? {
        if let sodiumPerServing = nutriments.sodiumPerServing {
            return milligrams(fromGrams: sodiumPerServing)
        }

        guard let saltPerServing = nutriments.saltPerServing else { return nil }
        return milligrams(fromSaltGrams: saltPerServing)
    }

    private static func sodiumPer100g(for nutriments: OpenFoodFactsProduct.Nutriments) -> Double? {
        if let sodiumPer100g = nutriments.sodiumPer100g {
            return milligrams(fromGrams: sodiumPer100g)
        }

        guard let saltPer100g = nutriments.saltPer100g else { return nil }
        return milligrams(fromSaltGrams: saltPer100g)
    }

    private static func resolvedOptionalNutrient(
        for requiredNutritionBasis: RequiredNutritionBasis,
        servingValue: Double?,
        per100gValue: Double?
    ) -> Double? {
        switch requiredNutritionBasis.kind {
        case .serving:
            return servingValue ?? scaledValue(per100gValue, gramsPerServing: requiredNutritionBasis.gramsPerServing)
        case .scaledServing:
            return servingValue ?? scaledValue(per100gValue, gramsPerServing: requiredNutritionBasis.gramsPerServing)
        case .per100g:
            return per100gValue
        }
    }

    private static func milligrams(fromGrams grams: Double?) -> Double? {
        guard let grams else { return nil }
        return grams * 1_000
    }

    private static func milligrams(fromSaltGrams saltGrams: Double) -> Double {
        (saltGrams / 2.5) * 1_000
    }

    private static func scaledValue(_ value: Double?, gramsPerServing: Double?) -> Double? {
        guard let value, let gramsPerServing else { return nil }
        return value * (gramsPerServing / 100)
    }
}
