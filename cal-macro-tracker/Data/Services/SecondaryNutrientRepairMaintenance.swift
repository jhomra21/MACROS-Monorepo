import Foundation
import SwiftData

extension SecondaryNutrientRepairService {
    static func requiresRepairPass(modelContext: ModelContext) throws -> Bool {
        let foods = try fetchAllFoods(modelContext: modelContext)
        if foods.contains(where: needsBackfillStateClassification) {
            return true
        }

        if foods.contains(where: { $0.secondaryNutrientBackfillState == .needsRepair }) {
            return true
        }

        let entries = try fetchAllLogEntries(modelContext: modelContext)
        if entries.contains(where: needsBackfillStateClassification) {
            return true
        }

        return entries.contains(where: { $0.secondaryNutrientBackfillState == .needsRepair })
    }

    static func repairIfNeeded(
        modelContext: ModelContext,
        commonFoodRecords: [CommonFoodSeedRecord]
    ) async throws {
        try classifyBackfillStatesIfNeeded(modelContext: modelContext)
        try normalizeUnrepairableStatesIfNeeded(modelContext: modelContext)
        try CommonFoodSeedLoader.repairIfNeeded(modelContext: modelContext, records: commonFoodRecords)
        try await repairExternalFoodsIfNeeded(modelContext: modelContext)
        try repairLogEntryFoodLinksIfNeeded(modelContext: modelContext)
        try await repairLogEntrySecondaryNutrientsIfNeeded(
            modelContext: modelContext,
            commonFoodRecords: commonFoodRecords
        )
    }

    static func fetchAllFoods(modelContext: ModelContext) throws -> [FoodItem] {
        try modelContext.fetch(FetchDescriptor<FoodItem>())
    }

    static func fetchAllLogEntries(modelContext: ModelContext) throws -> [LogEntry] {
        try modelContext.fetch(FetchDescriptor<LogEntry>())
    }

    static func classifyBackfillStatesIfNeeded(modelContext: ModelContext) throws {
        let foods = try fetchAllFoods(modelContext: modelContext)
        let entries = try fetchAllLogEntries(modelContext: modelContext)
        let foodsNeedingClassification = foods.filter(needsBackfillStateClassification)
        let entriesNeedingClassification = entries.filter(needsBackfillStateClassification)
        guard foodsNeedingClassification.isEmpty == false || entriesNeedingClassification.isEmpty == false else { return }

        let foodsByID = Dictionary(uniqueKeysWithValues: foods.map { ($0.id, $0) })
        let externalTargetsByKey = repairableExternalTargetsByKey(foodsByID: foodsByID)

        try PersistenceReporter.persist(modelContext: modelContext, operation: "Classify secondary nutrient backfill state") {
            for food in foodsNeedingClassification {
                food.secondaryNutrientBackfillState = SecondaryNutrientBackfillPolicy.inferredState(for: food)
            }

            for entry in entriesNeedingClassification {
                entry.secondaryNutrientBackfillState =
                    legacyLogEntryNeedsRepair(
                        entry: entry,
                        foodsByID: foodsByID,
                        externalTargetsByKey: externalTargetsByKey
                    )
                    ? .needsRepair
                    : .current
            }
        }
    }

    static func normalizeUnrepairableStatesIfNeeded(modelContext: ModelContext) throws {
        let foods = try fetchAllFoods(modelContext: modelContext)
        let foodsByID = Dictionary(uniqueKeysWithValues: foods.map { ($0.id, $0) })
        let externalTargetsByKey = repairableExternalTargetsByKey(foodsByID: foodsByID)
        let entries = try fetchAllLogEntries(modelContext: modelContext)

        let foodIDsToMarkNotRepairable =
            foods
            .filter { food in
                food.secondaryNutrientBackfillState == .needsRepair
                    && food.sourceKind != .common
                    && food.secondaryNutrientRepairTarget == nil
            }
            .map(\.persistentModelID)

        let entryIDsToMarkNotRepairable =
            entries
            .filter { entry in
                entry.secondaryNutrientBackfillState == .needsRepair
                    && entry.sourceKind != .common
                    && historicalRepairTarget(
                        for: entry,
                        foodsByID: foodsByID,
                        externalTargetsByKey: externalTargetsByKey
                    ) == nil
            }
            .map(\.persistentModelID)

        guard foodIDsToMarkNotRepairable.isEmpty == false || entryIDsToMarkNotRepairable.isEmpty == false else {
            return
        }

        try PersistenceReporter.persist(modelContext: modelContext, operation: "Normalize unrepairable secondary nutrient states") {
            for foodID in foodIDsToMarkNotRepairable {
                guard let food = modelContext.model(for: foodID) as? FoodItem else {
                    continue
                }

                food.secondaryNutrientBackfillState = .notRepairable
                food.updatedAt = .now
            }

            for entryID in entryIDsToMarkNotRepairable {
                guard let entry = modelContext.model(for: entryID) as? LogEntry else {
                    continue
                }

                entry.secondaryNutrientBackfillState = .notRepairable
                entry.updatedAt = .now
            }
        }
    }

    static func needsBackfillStateClassification(_ food: FoodItem) -> Bool {
        food.secondaryNutrientBackfillState == nil
    }

    static func needsBackfillStateClassification(_ entry: LogEntry) -> Bool {
        entry.secondaryNutrientBackfillState == nil
    }

    static func legacyLogEntryNeedsRepair(
        entry: LogEntry,
        foodsByID: [UUID: FoodItem],
        externalTargetsByKey: [SecondaryNutrientRepairKey: SecondaryNutrientRepairTarget]
    ) -> Bool {
        entry.isMissingAllSecondaryPerServingNutrients
            && entry.isMissingAllSecondaryConsumedNutrients
            && supportsHistoricalSecondaryNutrientRepair(
                entry: entry,
                foodsByID: foodsByID,
                externalTargetsByKey: externalTargetsByKey
            )
    }
}
