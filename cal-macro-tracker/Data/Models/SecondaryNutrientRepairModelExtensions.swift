import Foundation

extension FoodDraft {
    var isMissingAllSecondaryNutrients: Bool {
        saturatedFatPerServing == nil
            && fiberPerServing == nil
            && sugarsPerServing == nil
            && addedSugarsPerServing == nil
            && sodiumPerServing == nil
            && cholesterolPerServing == nil
    }

    var hasAnySecondaryNutrient: Bool {
        isMissingAllSecondaryNutrients == false
    }

    var shouldOfferManualSecondaryNutrientRefresh: Bool {
        switch source {
        case .barcodeLookup, .searchLookup:
            return isMissingAllSecondaryNutrients && secondaryNutrientBackfillState != .notRepairable
        case .common, .custom, .labelScan:
            return false
        }
    }

    var secondaryNutrientRepairKey: SecondaryNutrientRepairKey {
        SecondaryNutrientRepairKey(
            source: source,
            name: name,
            brand: brandOrNil,
            servingDescription: servingDescription,
            gramsPerServing: gramsPerServing,
            caloriesPerServing: caloriesPerServing,
            proteinPerServing: proteinPerServing,
            fatPerServing: fatPerServing,
            carbsPerServing: carbsPerServing
        )
    }

    var secondaryNutrientRepairTarget: SecondaryNutrientRepairTarget? {
        SecondaryNutrientRepairTarget.resolve(
            source: source,
            externalProductID: externalProductIDOrNil,
            barcode: barcodeOrNil,
            sourceURL: sourceURLOrNil
        )
    }
}

extension FoodItem {
    var secondaryNutrientRepairKey: SecondaryNutrientRepairKey {
        SecondaryNutrientRepairKey(
            source: sourceKind,
            name: name,
            brand: brand,
            servingDescription: servingDescription,
            gramsPerServing: gramsPerServing,
            caloriesPerServing: caloriesPerServing,
            proteinPerServing: proteinPerServing,
            fatPerServing: fatPerServing,
            carbsPerServing: carbsPerServing
        )
    }

    var secondaryNutrientRepairTarget: SecondaryNutrientRepairTarget? {
        SecondaryNutrientRepairTarget.resolve(
            source: sourceKind,
            externalProductID: externalProductID,
            barcode: barcode,
            sourceURL: sourceURL
        )
    }
}

extension LogEntry {
    var secondaryNutrientRepairKey: SecondaryNutrientRepairKey {
        SecondaryNutrientRepairKey(
            source: sourceKind,
            name: foodName,
            brand: brand,
            servingDescription: servingDescription,
            gramsPerServing: gramsPerServing,
            caloriesPerServing: caloriesPerServing,
            proteinPerServing: proteinPerServing,
            fatPerServing: fatPerServing,
            carbsPerServing: carbsPerServing
        )
    }

    var secondaryNutrientRepairTarget: SecondaryNutrientRepairTarget? {
        SecondaryNutrientRepairTarget.resolve(
            source: sourceKind,
            externalProductID: externalProductIDOrNil,
            barcode: barcodeOrNil,
            sourceURL: sourceURLOrNil
        )
    }
}
