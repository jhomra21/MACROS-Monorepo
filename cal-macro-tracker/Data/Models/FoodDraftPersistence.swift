import Foundation

extension FoodDraft {
    func makeReusableFoodItem(sourceOverride: FoodSource? = nil) -> FoodItem {
        FoodItem(importedData: reusableFoodImportedData(sourceOverride: sourceOverride))
    }

    func withSecondaryNutrients(from other: FoodDraft) -> FoodDraft {
        var draft = self
        draft.saturatedFatPerServing = other.saturatedFatPerServing
        draft.fiberPerServing = other.fiberPerServing
        draft.sugarsPerServing = other.sugarsPerServing
        draft.addedSugarsPerServing = other.addedSugarsPerServing
        draft.sodiumPerServing = other.sodiumPerServing
        draft.cholesterolPerServing = other.cholesterolPerServing
        return draft
    }

    func backfillingSourceIdentity(from other: FoodDraft) -> FoodDraft {
        var draft = self

        guard draft.source == other.source else {
            return draft
        }

        if draft.barcodeOrNil == nil {
            draft.barcode = other.barcodeOrNil ?? ""
        }

        if draft.externalProductIDOrNil == nil {
            draft.externalProductID = other.externalProductIDOrNil ?? ""
        }

        if draft.sourceNameOrNil == nil {
            draft.sourceName = other.sourceNameOrNil ?? ""
        }

        if draft.sourceURLOrNil == nil {
            draft.sourceURL = other.sourceURLOrNil ?? ""
        }

        if let canonicalOpenFoodFactsExternalProductID = OpenFoodFactsIdentity.qualifiedExternalProductID(for: other.barcodeOrNil),
            other.externalProductIDOrNil == canonicalOpenFoodFactsExternalProductID
        {
            draft.externalProductID = canonicalOpenFoodFactsExternalProductID
        }

        if let canonicalOpenFoodFactsSourceURL = OpenFoodFactsIdentity.productURL(for: other.barcodeOrNil)?.absoluteString,
            other.sourceURLOrNil == canonicalOpenFoodFactsSourceURL
        {
            draft.sourceURL = canonicalOpenFoodFactsSourceURL
        }

        return draft
    }

    private func reusableFoodImportedData(sourceOverride: FoodSource? = nil) -> FoodDraftImportedData {
        let draft = normalized()

        return FoodDraftImportedData(
            name: draft.name,
            brand: draft.brandOrNil,
            source: sourceOverride ?? draft.source,
            secondaryNutrientBackfillState: draft.secondaryNutrientBackfillState,
            barcode: draft.barcodeOrNil,
            externalProductID: draft.externalProductIDOrNil,
            sourceName: draft.sourceNameOrNil,
            sourceURL: draft.sourceURLOrNil,
            servingDescription: draft.servingDescription,
            gramsPerServing: draft.gramsPerServing,
            perServingNutrition: draft.perServingNutritionValues
        )
    }
}
