import Foundation
import SwiftData

@MainActor
struct FoodItemRepository {
    let modelContext: ModelContext

    func fetchAll() throws -> [FoodItem] {
        var descriptor = FetchDescriptor<FoodItem>(sortBy: [SortDescriptor(\FoodItem.name)])
        descriptor.includePendingChanges = true
        return try modelContext.fetch(descriptor)
    }

    func fetchCustomFood(id: UUID) throws -> FoodItem? {
        try fetchCustomFood(id: id, in: modelContext)
    }

    @discardableResult
    func saveReusableCustomFood(from draft: FoodDraft, operation: String) throws -> FoodItem {
        let normalizedDraft = draft.normalized()
        if let validationError = normalizedDraft.validationErrorForSaving() {
            throw validationError
        }

        let foodID = try PersistenceReporter.persist(in: modelContext.container, operation: operation) { isolatedContext in
            try upsertReusableCustomFood(from: normalizedDraft, in: isolatedContext).persistentModelID
        }

        guard let savedFood = modelContext.model(for: foodID) as? FoodItem else {
            throw NSError(domain: "FoodItemRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to load saved custom food."])
        }

        return savedFood
    }

    func deleteCustomFood(_ food: FoodItem, operation: String) throws {
        let foodID = food.persistentModelID

        try PersistenceReporter.persist(in: modelContext.container, operation: operation) { isolatedContext in
            guard let isolatedFood = isolatedContext.model(for: foodID) as? FoodItem else {
                throw NSError(domain: "FoodItemRepository", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to load custom food for deletion."])
            }

            isolatedContext.delete(isolatedFood)
        }
    }

    @discardableResult
    func upsertReusableCustomFood(from draft: FoodDraft, in context: ModelContext) throws -> FoodItem {
        let normalizedDraft = draft.normalized()
        if let validationError = normalizedDraft.validationErrorForSaving() {
            throw validationError
        }

        let food: FoodItem

        if let existingID = normalizedDraft.foodItemID,
           let existingFood = try fetchCustomFood(id: existingID, in: context) {
            food = existingFood
            food.name = normalizedDraft.name
            food.brand = normalizedDraft.brandOrNil
            food.servingDescription = normalizedDraft.servingDescription
            food.gramsPerServing = normalizedDraft.gramsPerServing
            food.caloriesPerServing = normalizedDraft.caloriesPerServing
            food.proteinPerServing = normalizedDraft.proteinPerServing
            food.fatPerServing = normalizedDraft.fatPerServing
            food.carbsPerServing = normalizedDraft.carbsPerServing
        } else {
            food = normalizedDraft.makeCustomFoodItem()
            context.insert(food)
        }

        food.normalizeForPersistence()
        return food
    }

    private func fetchCustomFood(id: UUID, in context: ModelContext) throws -> FoodItem? {
        let customSource = FoodSource.custom.rawValue
        let descriptor = FetchDescriptor<FoodItem>(predicate: #Predicate { food in
            food.id == id && food.source == customSource
        })

        return try context.fetch(descriptor).first
    }
}
