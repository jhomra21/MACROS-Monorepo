import Foundation
import SwiftData

struct MealComponentInput: Hashable {
    let foodItemID: UUID
    let quantityMode: QuantityMode
    let quantityAmount: Double
}

struct MealComponentSummary: Identifiable {
    let id: UUID
    let componentID: UUID
    let food: FoodItem
    let quantityMode: QuantityMode
    let quantityAmount: Double
    let nutrients: LoggedFoodNutrients

    init(component: MealComponent, food: FoodItem) {
        id = component.id
        componentID = component.id
        self.food = food
        quantityMode = component.quantityModeKind
        quantityAmount = component.quantityAmount
        nutrients = NutritionMath.consumedNutrients(
            for: food,
            mode: component.quantityModeKind,
            amount: component.quantityAmount
        )
    }
}

struct MealNutritionSummary {
    let components: [MealComponentSummary]
    let nutrients: LoggedFoodNutrients
}

@MainActor
struct MealRepository {
    let modelContext: ModelContext

    func fetchMeal(id: UUID) throws -> Meal? {
        var descriptor = FetchDescriptor<Meal>(
            predicate: #Predicate { meal in
                meal.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func components(for mealID: UUID, in context: ModelContext? = nil) throws -> [MealComponent] {
        let context = context ?? modelContext
        let descriptor = FetchDescriptor<MealComponent>(
            predicate: #Predicate { component in
                component.mealID == mealID
            }
        )
        return try context.fetch(descriptor)
    }

    func nutritionSummary(for meal: Meal) throws -> MealNutritionSummary {
        let components = try components(for: meal.id)
        let foodsByID = try foodsByID(for: components.map(\.foodItemID), in: modelContext)
        let summaries = componentSummaries(for: components, foodsByID: foodsByID)
        return MealNutritionSummary(
            components: summaries,
            nutrients: NutritionMath.summedNutrients(summaries.map(\.nutrients))
        )
    }

    func nutritionSummaries(for meals: [Meal], in context: ModelContext? = nil) throws -> [UUID: MealNutritionSummary] {
        let context = context ?? modelContext
        let mealIDs = Set(meals.map(\.id))
        guard mealIDs.isEmpty == false else { return [:] }

        let components = try components(for: mealIDs, in: context)
        let foodsByID = try foodsByID(for: components.map(\.foodItemID), in: context)
        let summariesByMealID = Dictionary(grouping: components, by: \.mealID).mapValues { mealComponents in
            componentSummaries(for: mealComponents, foodsByID: foodsByID)
        }

        return Dictionary(
            uniqueKeysWithValues: meals.map { meal in
                let summaries = summariesByMealID[meal.id] ?? []
                return (
                    meal.id,
                    MealNutritionSummary(
                        components: summaries,
                        nutrients: NutritionMath.summedNutrients(summaries.map(\.nutrients))
                    )
                )
            }
        )
    }

    @discardableResult
    func saveMeal(
        id: UUID? = nil,
        name: String,
        components: [MealComponentInput],
        operation: String
    ) throws -> Meal {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedName.isEmpty == false else {
            throw NSError(domain: "MealRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Meal name is required."])
        }

        guard components.isEmpty == false else {
            throw NSError(domain: "MealRepository", code: 2, userInfo: [NSLocalizedDescriptionKey: "Add at least one food to save a meal."])
        }

        guard Set(components.map(\.foodItemID)).count == components.count else {
            throw NSError(
                domain: "MealRepository",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "A meal can only include each food once."]
            )
        }

        let mealID = try PersistenceReporter.persist(in: modelContext.container, operation: operation) { isolatedContext in
            let foodsByID = try foodsByID(for: components.map(\.foodItemID), in: isolatedContext)
            try validateComponents(components, foodsByID: foodsByID)

            let meal: Meal
            if let existingMeal = try existingMeal(id: id, in: isolatedContext) {
                meal = existingMeal
            } else {
                meal = Meal(id: id ?? UUID(), name: normalizedName)
                isolatedContext.insert(meal)
            }

            let componentNames = components.map { foodsByID[$0.foodItemID]!.name }
            meal.name = normalizedName
            meal.normalizeForPersistence(componentNames: componentNames)

            for existingComponent in try self.components(for: meal.id, in: isolatedContext) {
                isolatedContext.delete(existingComponent)
            }

            for component in components {
                isolatedContext.insert(
                    MealComponent(
                        mealID: meal.id,
                        foodItemID: component.foodItemID,
                        quantityMode: component.quantityMode,
                        quantityAmount: component.quantityAmount
                    )
                )
            }

            return meal.id
        }

        guard let meal = try fetchMeal(id: mealID) else {
            throw NSError(domain: "MealRepository", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unable to load saved meal."])
        }
        return meal
    }

    func deleteMeal(_ meal: Meal, operation: String) throws {
        let mealModelID = meal.persistentModelID

        try PersistenceReporter.persist(in: modelContext.container, operation: operation) { isolatedContext in
            guard let isolatedMeal = isolatedContext.model(for: mealModelID) as? Meal else {
                throw NSError(domain: "MealRepository", code: 5, userInfo: [NSLocalizedDescriptionKey: "Unable to load meal for deletion."])
            }

            for component in try self.components(for: isolatedMeal.id, in: isolatedContext) {
                isolatedContext.delete(component)
            }
            isolatedContext.delete(isolatedMeal)
        }
    }

    func refreshSearchableTextForMealsReferencingFood(id foodID: UUID, in context: ModelContext) throws {
        let descriptor = FetchDescriptor<MealComponent>(
            predicate: #Predicate { component in
                component.foodItemID == foodID
            }
        )
        let mealIDs = Set(try context.fetch(descriptor).map(\.mealID))
        guard mealIDs.isEmpty == false else { return }

        let meals = try meals(for: mealIDs, in: context)
        let componentsByMealID = Dictionary(grouping: try components(for: mealIDs, in: context), by: \.mealID)
        let foodsByID = try foodsByID(for: componentsByMealID.values.flatMap { $0.map(\.foodItemID) }, in: context)

        for meal in meals {
            let components = componentsByMealID[meal.id] ?? []
            meal.updateSearchableText(componentNames: components.compactMap { foodsByID[$0.foodItemID]?.name })
        }
    }

    func mealCountReferencingFood(id foodID: UUID, in context: ModelContext) throws -> Int {
        let descriptor = FetchDescriptor<MealComponent>(
            predicate: #Predicate { component in
                component.foodItemID == foodID
            }
        )
        return Set(try context.fetch(descriptor).map(\.mealID)).count
    }

    private func existingMeal(id: UUID?, in context: ModelContext) throws -> Meal? {
        guard let id else { return nil }
        var descriptor = FetchDescriptor<Meal>(
            predicate: #Predicate { meal in
                meal.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func meals(for ids: Set<UUID>, in context: ModelContext) throws -> [Meal] {
        guard ids.isEmpty == false else { return [] }
        let descriptor = FetchDescriptor<Meal>(
            predicate: #Predicate { meal in
                ids.contains(meal.id)
            }
        )
        return try context.fetch(descriptor)
    }

    private func components(for mealIDs: Set<UUID>, in context: ModelContext) throws -> [MealComponent] {
        guard mealIDs.isEmpty == false else { return [] }
        let descriptor = FetchDescriptor<MealComponent>(
            predicate: #Predicate { component in
                mealIDs.contains(component.mealID)
            }
        )
        return try context.fetch(descriptor)
    }

    private func foodsByID(for ids: [UUID], in context: ModelContext) throws -> [UUID: FoodItem] {
        let ids = Set(ids)
        guard ids.isEmpty == false else { return [:] }

        let descriptor = FetchDescriptor<FoodItem>(
            predicate: #Predicate { food in
                ids.contains(food.id)
            }
        )
        return Dictionary(uniqueKeysWithValues: try context.fetch(descriptor).map { ($0.id, $0) })
    }

    private func validateComponents(_ components: [MealComponentInput], foodsByID: [UUID: FoodItem]) throws {
        for component in components {
            guard let food = foodsByID[component.foodItemID] else {
                throw NSError(
                    domain: "MealRepository",
                    code: 6,
                    userInfo: [NSLocalizedDescriptionKey: "Meal component food is missing."]
                )
            }

            guard component.quantityAmount.isFinite, component.quantityAmount > 0 else {
                throw NSError(
                    domain: "MealRepository",
                    code: 7,
                    userInfo: [NSLocalizedDescriptionKey: "Meal component quantity must be greater than 0."]
                )
            }

            if component.quantityMode == .grams {
                guard
                    let gramsPerServing = food.gramsPerServing,
                    gramsPerServing.isFinite,
                    gramsPerServing > 0
                else {
                    throw NSError(
                        domain: "MealRepository",
                        code: 8,
                        userInfo: [NSLocalizedDescriptionKey: "Add grams per serving to use grams for this meal component."]
                    )
                }
            }

            guard
                food.caloriesPerServing.isFinite,
                food.proteinPerServing.isFinite,
                food.fatPerServing.isFinite,
                food.carbsPerServing.isFinite
            else {
                throw NSError(
                    domain: "MealRepository",
                    code: 9,
                    userInfo: [NSLocalizedDescriptionKey: "Meal components require calories and primary macros."]
                )
            }
        }
    }

    private func componentSummaries(
        for components: [MealComponent],
        foodsByID: [UUID: FoodItem]
    ) -> [MealComponentSummary] {
        components.compactMap { component -> MealComponentSummary? in
            guard let food = foodsByID[component.foodItemID] else { return nil }
            return MealComponentSummary(component: component, food: food)
        }
        .sorted {
            $0.food.name.localizedCaseInsensitiveCompare($1.food.name) == .orderedAscending
        }
    }
}
