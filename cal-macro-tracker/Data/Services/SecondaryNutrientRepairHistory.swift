import Foundation
import SwiftData

extension SecondaryNutrientRepairService {
    static func canManuallyRefreshSecondaryNutrients(
        for entry: LogEntry,
        currentDraft: FoodDraft,
        modelContext: ModelContext
    ) throws -> Bool {
        let initialDraft = FoodDraft(logEntry: entry, saveAsCustomFood: false)
        guard currentDraft.secondaryNutrientRepairKey == initialDraft.secondaryNutrientRepairKey else {
            return false
        }

        if currentDraft.secondaryNutrientRepairTarget != nil {
            return true
        }

        return try manualRefreshTarget(for: entry, modelContext: modelContext) != nil
    }

    static func canManuallyRefreshSecondaryNutrients(
        for currentDraft: FoodDraft,
        initialDraft: FoodDraft
    ) -> Bool {
        currentDraft.secondaryNutrientRepairKey == initialDraft.secondaryNutrientRepairKey
            && currentDraft.secondaryNutrientRepairTarget != nil
    }

    static func manuallyRefreshedDraft(
        for currentDraft: FoodDraft,
        initialDraft: FoodDraft
    ) async throws -> FoodDraft? {
        guard canManuallyRefreshSecondaryNutrients(for: currentDraft, initialDraft: initialDraft),
            let target = currentDraft.secondaryNutrientRepairTarget
        else {
            return nil
        }

        return try await manuallyRefreshedDraft(for: currentDraft, target: target)
    }

    static func manuallyRefreshedDraft(
        for entry: LogEntry,
        currentDraft: FoodDraft,
        modelContext: ModelContext
    ) async throws -> FoodDraft? {
        let initialDraft = FoodDraft(logEntry: entry, saveAsCustomFood: false)
        guard currentDraft.secondaryNutrientRepairKey == initialDraft.secondaryNutrientRepairKey else {
            return nil
        }

        let fallbackTarget = try manualRefreshTarget(for: entry, modelContext: modelContext)
        guard let target = currentDraft.secondaryNutrientRepairTarget ?? fallbackTarget else {
            return nil
        }

        return try await manuallyRefreshedDraft(for: currentDraft, target: target)
    }

    static func refreshedDraft(
        source: FoodSource,
        target: SecondaryNutrientRepairTarget
    ) async throws -> FoodDraft? {
        switch target {
        case let .openFoodFactsBarcode(barcode):
            let product = try await OpenFoodFactsClient().fetchProduct(barcode: barcode)
            return try BarcodeLookupMapper.makeDraft(from: product, source: source, barcode: barcode)
        case let .usdaFood(usdaFoodID):
            let food = try await USDAFoodDetailsClient().fetchFood(id: usdaFoodID)
            return USDAFoodDraftMapper.makeDraft(from: food)
        }
    }

    static func manuallyRefreshedDraft(
        for draft: FoodDraft,
        target: SecondaryNutrientRepairTarget
    ) async throws -> FoodDraft? {
        guard let sourceDraft = try await refreshedDraft(source: draft.source, target: target) else {
            return nil
        }

        guard sourceDraft.secondaryNutrientRepairKey == draft.secondaryNutrientRepairKey else {
            return nil
        }

        guard sourceDraft.hasAnySecondaryNutrient else {
            return nil
        }

        var refreshedDraft = draft.backfillingSourceIdentity(from: sourceDraft)
            .withSecondaryNutrients(from: sourceDraft)
        refreshedDraft.secondaryNutrientBackfillState = .current
        return refreshedDraft
    }

    static func historicalRepairDraftResolution(
        for entry: LogEntry,
        foodsByID: [UUID: FoodItem],
        externalTargetsByKey: [SecondaryNutrientRepairKey: SecondaryNutrientRepairTarget],
        commonDraftsByKey: [SecondaryNutrientRepairKey: FoodDraft],
        externalDraftsByTarget: inout [SecondaryNutrientRepairTarget: FoodDraft?]
    ) async throws -> HistoricalEntryRepairDraftResolution {
        switch entry.sourceKind {
        case .common:
            guard let draft = commonDraftsByKey[entry.secondaryNutrientRepairKey] else {
                return .notRepairable
            }

            return .draft(draft)
        case .barcodeLookup, .searchLookup:
            guard
                let target = historicalRepairTarget(
                    for: entry,
                    foodsByID: foodsByID,
                    externalTargetsByKey: externalTargetsByKey
                )
            else {
                return .notRepairable
            }

            let sourceDraft: FoodDraft?
            if let cachedDraft = externalDraftsByTarget[target] {
                sourceDraft = cachedDraft
            } else {
                let fetchedDraft = try await refreshedDraft(source: entry.sourceKind, target: target)
                externalDraftsByTarget[target] = fetchedDraft
                sourceDraft = fetchedDraft
            }

            guard
                let sourceDraft,
                sourceDraft.secondaryNutrientRepairKey == entry.secondaryNutrientRepairKey,
                sourceDraft.hasAnySecondaryNutrient
            else {
                return .notRepairable
            }

            return .draft(sourceDraft)
        case .custom, .labelScan:
            return .notRepairable
        }
    }

    static func commonRepairDraftsByKey(
        records: [CommonFoodSeedRecord]
    ) -> [SecondaryNutrientRepairKey: FoodDraft] {
        var matches: [SecondaryNutrientRepairKey: FoodDraft] = [:]
        var ambiguousKeys = Set<SecondaryNutrientRepairKey>()

        for record in records {
            let draft = CommonFoodSeedLoader.makeFoodDraft(from: record)
            let key = draft.secondaryNutrientRepairKey
            if matches[key] != nil {
                ambiguousKeys.insert(key)
            } else {
                matches[key] = draft
            }
        }

        ambiguousKeys.forEach { matches.removeValue(forKey: $0) }
        return matches
    }

    static func supportsHistoricalSecondaryNutrientRepair(
        entry: LogEntry,
        foodsByID: [UUID: FoodItem],
        externalTargetsByKey: [SecondaryNutrientRepairKey: SecondaryNutrientRepairTarget]
    ) -> Bool {
        switch entry.sourceKind {
        case .common:
            return true
        case .barcodeLookup, .searchLookup:
            return historicalRepairTarget(
                for: entry,
                foodsByID: foodsByID,
                externalTargetsByKey: externalTargetsByKey
            ) != nil
        case .custom, .labelScan:
            return false
        }
    }

    static func historicalRepairTarget(
        for entry: LogEntry,
        foodsByID: [UUID: FoodItem],
        externalTargetsByKey: [SecondaryNutrientRepairKey: SecondaryNutrientRepairTarget]
    ) -> SecondaryNutrientRepairTarget? {
        if let target = entry.secondaryNutrientRepairTarget {
            return target
        }

        if let foodItemID = entry.foodItemID,
            let food = foodsByID[foodItemID],
            food.sourceKind != .common,
            food.secondaryNutrientRepairKey == entry.secondaryNutrientRepairKey
        {
            return food.secondaryNutrientRepairTarget
        }

        return externalTargetsByKey[entry.secondaryNutrientRepairKey]
    }

    static func manualRefreshTarget(
        for entry: LogEntry,
        modelContext: ModelContext
    ) throws -> SecondaryNutrientRepairTarget? {
        let foodsByID = try Dictionary(
            uniqueKeysWithValues: fetchAllFoods(modelContext: modelContext).map { ($0.id, $0) }
        )
        let externalTargetsByKey = repairableExternalTargetsByKey(foodsByID: foodsByID)
        return historicalRepairTarget(
            for: entry,
            foodsByID: foodsByID,
            externalTargetsByKey: externalTargetsByKey
        )
    }

    static func repairableExternalTargetsByKey(
        foodsByID: [UUID: FoodItem]
    ) -> [SecondaryNutrientRepairKey: SecondaryNutrientRepairTarget] {
        var matches: [SecondaryNutrientRepairKey: SecondaryNutrientRepairTarget] = [:]
        var ambiguousKeys = Set<SecondaryNutrientRepairKey>()

        for food in foodsByID.values {
            guard let target = food.secondaryNutrientRepairTarget else {
                continue
            }

            let key = food.secondaryNutrientRepairKey
            if matches[key] != nil {
                ambiguousKeys.insert(key)
            } else {
                matches[key] = target
            }
        }

        ambiguousKeys.forEach { matches.removeValue(forKey: $0) }
        return matches
    }
}
