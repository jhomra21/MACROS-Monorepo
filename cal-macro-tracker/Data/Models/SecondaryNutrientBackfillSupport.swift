import Foundation

struct SecondaryNutrientRepairKey: Hashable {
    let source: FoodSource
    let name: String
    let brand: String?
    let servingDescription: String
    let gramsPerServing: Double?
    let caloriesPerServing: Double
    let proteinPerServing: Double
    let fatPerServing: Double
    let carbsPerServing: Double

    init(
        source: FoodSource,
        name: String,
        brand: String?,
        servingDescription: String,
        gramsPerServing: Double?,
        caloriesPerServing: Double,
        proteinPerServing: Double,
        fatPerServing: Double,
        carbsPerServing: Double
    ) {
        self.source = source
        self.name = Self.normalizedText(name)
        self.brand = Self.trimmedText(brand)
        self.servingDescription = Self.normalizedText(servingDescription)
        self.gramsPerServing = gramsPerServing
        self.caloriesPerServing = caloriesPerServing
        self.proteinPerServing = proteinPerServing
        self.fatPerServing = fatPerServing
        self.carbsPerServing = carbsPerServing
    }

    private static func normalizedText(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func trimmedText(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized?.isEmpty == false ? normalized : nil
    }
}

enum SecondaryNutrientRepairTarget: Hashable {
    case openFoodFactsBarcode(String)
    case usdaFood(Int)

    static func resolve(
        source: FoodSource,
        externalProductID: String?,
        barcode: String?,
        sourceURL: String?
    ) -> SecondaryNutrientRepairTarget? {
        switch source {
        case .barcodeLookup:
            guard
                let barcode = normalizedBarcode(
                    barcode: barcode,
                    externalProductID: externalProductID,
                    sourceURL: sourceURL
                )
            else { return nil }
            return .openFoodFactsBarcode(barcode)
        case .searchLookup:
            if let usdaFoodID = usdaFoodID(from: externalProductID) {
                return .usdaFood(usdaFoodID)
            }

            guard
                let barcode = normalizedBarcode(
                    barcode: barcode,
                    externalProductID: externalProductID,
                    sourceURL: sourceURL
                )
            else { return nil }
            return .openFoodFactsBarcode(barcode)
        case .common, .custom, .labelScan:
            return nil
        }
    }

    private static func normalizedBarcode(
        barcode: String?,
        externalProductID: String?,
        sourceURL: String?
    ) -> String? {
        OpenFoodFactsIdentity.normalizedBarcode(
            barcode: barcode,
            externalProductID: externalProductID,
            sourceURL: sourceURL
        )
    }

    private static func usdaFoodID(from externalProductID: String?) -> Int? {
        guard let externalProductID = externalProductID?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return nil
        }

        let normalizedExternalProductID = externalProductID.lowercased()
        let prefix = "usda:"
        guard normalizedExternalProductID.hasPrefix(prefix) else { return nil }
        return Int(normalizedExternalProductID.dropFirst(prefix.count))
    }
}

enum SecondaryNutrientBackfillPolicy {
    struct UpdateResolution {
        let draft: FoodDraft
        let state: SecondaryNutrientBackfillState
    }

    static func inferredState(for food: FoodItem) -> SecondaryNutrientBackfillState {
        state(
            isMissingAllSecondaryNutrients: food.isMissingAllSecondaryNutrients,
            source: food.sourceKind,
            hasRepairTarget: food.secondaryNutrientRepairTarget != nil
        )
    }

    static func inferredState(for entry: LogEntry) -> SecondaryNutrientBackfillState {
        state(
            isMissingAllSecondaryNutrients: entry.isMissingAllSecondaryPerServingNutrients
                && entry.isMissingAllSecondaryConsumedNutrients,
            source: entry.sourceKind,
            hasRepairTarget: entry.secondaryNutrientRepairTarget != nil || entry.foodItemID != nil
        )
    }

    static func resolvedStateForNewRecord(from draft: FoodDraft) -> SecondaryNutrientBackfillState {
        draft.secondaryNutrientBackfillState ?? .current
    }

    static func resolvedUpdatedState(
        initialState: SecondaryNutrientBackfillState,
        initialKey: SecondaryNutrientRepairKey,
        updatedKey: SecondaryNutrientRepairKey,
        hasSecondaryNutrientChanges: Bool
    ) -> SecondaryNutrientBackfillState {
        if hasSecondaryNutrientChanges {
            return .current
        }

        if updatedKey != initialKey, initialState != .current {
            return .notRepairable
        }

        return initialState
    }

    static func resolvedUpdate(
        initialDraft: FoodDraft,
        updatedDraft: FoodDraft,
        initialState: SecondaryNutrientBackfillState
    ) -> UpdateResolution {
        let hasSecondaryNutrientChanges = updatedDraft.hasSecondaryNutrientChanges(comparedTo: initialDraft)
        let updatedState = resolvedUpdatedState(
            initialState: initialState,
            initialKey: initialDraft.secondaryNutrientRepairKey,
            updatedKey: updatedDraft.secondaryNutrientRepairKey,
            hasSecondaryNutrientChanges: hasSecondaryNutrientChanges
        )

        guard
            hasSecondaryNutrientChanges == false,
            updatedDraft.secondaryNutrientRepairKey != initialDraft.secondaryNutrientRepairKey,
            initialState == .current,
            initialDraft.isMissingAllSecondaryNutrients == false
        else {
            return UpdateResolution(draft: updatedDraft, state: updatedState)
        }

        return UpdateResolution(draft: updatedDraft, state: .notRepairable)
    }

    private static func state(
        isMissingAllSecondaryNutrients: Bool,
        source: FoodSource,
        hasRepairTarget: Bool
    ) -> SecondaryNutrientBackfillState {
        guard isMissingAllSecondaryNutrients else { return .current }

        switch source {
        case .common:
            return .needsRepair
        case .barcodeLookup, .searchLookup:
            return hasRepairTarget ? .needsRepair : .current
        case .custom, .labelScan:
            return .current
        }
    }
}

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
