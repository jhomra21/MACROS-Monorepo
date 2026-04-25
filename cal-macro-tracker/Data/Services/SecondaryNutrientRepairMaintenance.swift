import Foundation
import SwiftData

extension SecondaryNutrientRepairService {
    static func requiresRepairPass(modelContext: ModelContext) throws -> Bool {
        if try modelContext.fetchCount(foodClassificationDescriptor()) > 0 {
            return true
        }

        if try modelContext.fetchCount(foodNeedsRepairDescriptor()) > 0 {
            return true
        }

        if try modelContext.fetchCount(entryClassificationDescriptor()) > 0 {
            return true
        }

        return try modelContext.fetchCount(entryNeedsRepairDescriptor()) > 0
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
        let foodsNeedingClassification = try modelContext.fetch(foodClassificationDescriptor())
        let entriesNeedingClassification = try modelContext.fetch(entryClassificationDescriptor())
        guard foodsNeedingClassification.isEmpty == false || entriesNeedingClassification.isEmpty == false else { return }

        let foodsByID: [UUID: FoodItem]
        let externalTargetsByKey: [SecondaryNutrientRepairKey: SecondaryNutrientRepairTarget]
        if entriesNeedingClassification.isEmpty {
            foodsByID = [:]
            externalTargetsByKey = [:]
        } else {
            let foods = try fetchAllFoods(modelContext: modelContext)
            foodsByID = Dictionary(uniqueKeysWithValues: foods.map { ($0.id, $0) })
            externalTargetsByKey = repairableExternalTargetsByKey(foodsByID: foodsByID)
        }

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
        let foods = try modelContext.fetch(foodNeedsRepairDescriptor())
        let entries = try modelContext.fetch(entryNeedsRepairDescriptor())
        guard foods.isEmpty == false || entries.isEmpty == false else {
            return
        }

        let allFoods = try fetchAllFoods(modelContext: modelContext)
        let foodsByID = Dictionary(uniqueKeysWithValues: allFoods.map { ($0.id, $0) })
        let externalTargetsByKey = repairableExternalTargetsByKey(foodsByID: foodsByID)

        let foodIDsToMarkNotRepairable =
            foods
            .filter { food in
                food.sourceKind != .common
                    && food.secondaryNutrientRepairTarget == nil
            }
            .map(\.persistentModelID)

        let entryIDsToMarkNotRepairable =
            entries
            .filter { entry in
                entry.sourceKind != .common
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

    private static func foodClassificationDescriptor() -> FetchDescriptor<FoodItem> {
        FetchDescriptor<FoodItem>(predicate: #Predicate { $0.secondaryNutrientBackfillStateRaw == nil })
    }

    private static func entryClassificationDescriptor() -> FetchDescriptor<LogEntry> {
        FetchDescriptor<LogEntry>(predicate: #Predicate { $0.secondaryNutrientBackfillStateRaw == nil })
    }

    private static func foodNeedsRepairDescriptor() -> FetchDescriptor<FoodItem> {
        let needsRepairRaw = SecondaryNutrientBackfillState.needsRepair.rawValue
        return FetchDescriptor<FoodItem>(predicate: #Predicate { $0.secondaryNutrientBackfillStateRaw == needsRepairRaw })
    }

    private static func entryNeedsRepairDescriptor() -> FetchDescriptor<LogEntry> {
        let needsRepairRaw = SecondaryNutrientBackfillState.needsRepair.rawValue
        return FetchDescriptor<LogEntry>(predicate: #Predicate { $0.secondaryNutrientBackfillStateRaw == needsRepairRaw })
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
