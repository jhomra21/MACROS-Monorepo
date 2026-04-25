import Foundation
import SwiftData

@MainActor
enum AppBootstrap {
    struct Plan: Sendable {
        let shouldSeedCommonFoods: Bool
        let shouldNormalizeGoals: Bool
        let shouldRepairReusableFoodSearchIndexes: Bool
    }

    static func bootstrapIfNeeded(in container: ModelContainer) async throws {
        let planningContext = ModelContext(container)
        let plan = try makePlan(modelContext: planningContext)
        guard plan.shouldSeedCommonFoods || plan.shouldNormalizeGoals || plan.shouldRepairReusableFoodSearchIndexes else { return }

        let commonFoodRecords = try plan.shouldSeedCommonFoods ? await CommonFoodSeedLoader.commonFoodSeedRecords() : []
        let writeContext = ModelContext(container)

        if plan.shouldSeedCommonFoods {
            try CommonFoodSeedLoader.seedIfNeeded(modelContext: writeContext, records: commonFoodRecords)
        }

        if plan.shouldNormalizeGoals {
            try normalizeGoalsIfNeeded(modelContext: writeContext)
        }

        if plan.shouldRepairReusableFoodSearchIndexes {
            try repairReusableFoodSearchIndexesIfNeeded(modelContext: writeContext)
        }
    }

    static func repairSecondaryNutrientsIfNeeded(in container: ModelContainer) async throws {
        let planningContext = ModelContext(container)
        guard try SecondaryNutrientRepairService.requiresRepairPass(modelContext: planningContext) else { return }

        let commonFoodRecords = try await CommonFoodSeedLoader.commonFoodSeedRecords()
        let writeContext = ModelContext(container)
        try await SecondaryNutrientRepairService.repairIfNeeded(
            modelContext: writeContext,
            commonFoodRecords: commonFoodRecords
        )
    }

    // periphery:ignore - preview-only bootstrap used by in-memory SwiftUI previews
    static func bootstrapPreview(modelContext: ModelContext) throws {
        try CommonFoodSeedLoader.seedIfNeeded(modelContext: modelContext)
        try normalizeGoalsIfNeeded(modelContext: modelContext)
    }

    private static func makePlan(modelContext: ModelContext) throws -> Plan {
        Plan(
            shouldSeedCommonFoods: try shouldSeedCommonFoods(modelContext: modelContext),
            shouldNormalizeGoals: try shouldNormalizeGoals(modelContext: modelContext),
            shouldRepairReusableFoodSearchIndexes: try shouldRepairReusableFoodSearchIndexes(modelContext: modelContext)
        )
    }

    private static func shouldSeedCommonFoods(modelContext: ModelContext) throws -> Bool {
        let commonSource = FoodSource.common.rawValue
        let descriptor = FetchDescriptor<FoodItem>(predicate: #Predicate { $0.source == commonSource })
        return try modelContext.fetchCount(descriptor) == 0
    }

    private static func shouldNormalizeGoals(modelContext: ModelContext) throws -> Bool {
        try modelContext.fetchCount(FetchDescriptor<DailyGoals>()) != 1
    }

    private static func shouldRepairReusableFoodSearchIndexes(modelContext: ModelContext) throws -> Bool {
        try reusableFoodsNeedingSearchIndexRepair(modelContext: modelContext).isEmpty == false
    }

    private static func repairReusableFoodSearchIndexesIfNeeded(modelContext: ModelContext) throws {
        let foods = try reusableFoodsNeedingSearchIndexRepair(modelContext: modelContext)
        guard foods.isEmpty == false else { return }

        try PersistenceReporter.persist(modelContext: modelContext, operation: "Repair reusable food search indexes") {
            foods.forEach { food in
                food.updateSearchableText(updateTimestamp: false)
            }
        }
    }

    private static func reusableFoodsNeedingSearchIndexRepair(modelContext: ModelContext) throws -> [FoodItem] {
        let commonSource = FoodSource.common.rawValue
        let descriptor = FetchDescriptor<FoodItem>(predicate: #Predicate { $0.source != commonSource })
        return try modelContext.fetch(descriptor).filter(\.needsSearchableTextRepair)
    }
    private static func normalizeGoalsIfNeeded(modelContext: ModelContext) throws {
        guard try shouldNormalizeGoals(modelContext: modelContext) else { return }

        try PersistenceReporter.persist(modelContext: modelContext, operation: "Normalize daily goals") {
            try DailyGoalsRepository.normalizeGoalsRecordsIfNeeded(modelContext: modelContext)
        }
    }
}
