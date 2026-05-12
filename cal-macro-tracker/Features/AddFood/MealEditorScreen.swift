import SwiftData
import SwiftUI

struct MealEditorScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let meal: Meal?
    let loggingDay: CalendarDay?
    let onMealSaved: (Meal) -> Void
    let onMealDeleted: () -> Void
    let onMealLogged: () -> Void

    @State private var name: String
    @State private var components: [MealComponentDraft]
    @State private var errorMessage: String?
    @State private var savedMealRoute: SavedMealRoute?
    @State private var saveFeedbackToken = 0
    @FocusState private var isNameFocused: Bool

    init(
        meal: Meal? = nil,
        loggingDay: CalendarDay? = nil,
        initialComponents: [MealComponentDraft] = [],
        onMealSaved: @escaping (Meal) -> Void = { _ in },
        onMealDeleted: @escaping () -> Void = {},
        onMealLogged: @escaping () -> Void = {}
    ) {
        self.meal = meal
        self.loggingDay = loggingDay
        self.onMealSaved = onMealSaved
        self.onMealDeleted = onMealDeleted
        self.onMealLogged = onMealLogged
        _name = State(initialValue: meal?.name ?? "")
        _components = State(initialValue: initialComponents)
    }

    private var mealRepository: MealRepository {
        MealRepository(modelContext: modelContext)
    }

    private var sortedComponents: [MealComponentDraft] {
        components.sorted {
            $0.food.name.localizedCaseInsensitiveCompare($1.food.name) == .orderedAscending
        }
    }

    private var aggregateNutrients: LoggedFoodNutrients {
        NutritionMath.summedNutrients(components.map(\.nutrients))
    }

    private var canSave: Bool {
        TextNormalization.trimmedNonEmpty(name) != nil && components.isEmpty == false
    }

    private var saveTitle: String {
        meal == nil ? "Save Meal" : "Save Changes"
    }

    var body: some View {
        Form {
            Section("Meal") {
                TextField("Meal name", text: $name)
                    .focused($isNameFocused)

                if TextNormalization.trimmedNonEmpty(name) == nil, let suggestedName {
                    Button("Use \(suggestedName)") {
                        name = suggestedName
                    }
                }
            }

            Section("Nutrition") {
                FoodNutritionRow(
                    name: "Meal Total",
                    subtitle: "\(components.count) foods",
                    calories: aggregateNutrients.calories,
                    protein: aggregateNutrients.protein,
                    carbs: aggregateNutrients.carbs,
                    fat: aggregateNutrients.fat
                )
            }

            Section {
                if components.isEmpty {
                    ContentUnavailableView(
                        "No Foods Added",
                        systemImage: "fork.knife",
                        description: Text("Add foods to build this meal.")
                    )
                } else {
                    ForEach(sortedComponents) { component in
                        NavigationLink {
                            MealComponentQuantityScreen(component: component) { updatedComponent in
                                upsertComponent(updatedComponent)
                            }
                        } label: {
                            FoodNutritionRow(
                                name: component.food.name,
                                subtitle: component.quantitySummary,
                                calories: component.nutrients.calories,
                                protein: component.nutrients.protein,
                                carbs: component.nutrients.carbs,
                                fat: component.nutrients.fat
                            )
                        }
                    }
                    .onDelete(perform: deleteComponents)
                }

                NavigationLink {
                    MealComponentFoodPickerScreen(excludedFoodIDs: Set(components.map { $0.food.id })) { component in
                        upsertComponent(component)
                    }
                } label: {
                    Label("Add Food", systemImage: "plus")
                }
            } header: {
                Text("Foods")
            } footer: {
                Text("Each food can appear once. Tap a food to edit its quantity.")
            }
        }
        .navigationTitle(meal == nil ? "Create Meal" : "Edit Meal")
        .inlineNavigationTitle()
        .errorBanner(message: $errorMessage)
        .sensoryFeedback(.success, trigger: saveFeedbackToken)
        .safeAreaInset(edge: .bottom) {
            BottomPinnedActionBar(title: saveTitle, systemImage: nil, isDisabled: !canSave) {
                saveMeal()
            }
        }
        .toolbar {
            if let meal {
                ToolbarItem(placement: .destructiveAction) {
                    Button("Delete", role: .destructive) {
                        deleteMeal(meal)
                    }
                }
            }
        }
        .onAppear {
            loadExistingMealIfNeeded()
        }
        .navigationDestination(item: $savedMealRoute) { route in
            SavedMealLogDestination(mealID: route.id, loggingDay: loggingDay, onMealLogged: onMealLogged)
        }
    }

    private var suggestedName: String? {
        let names = sortedComponents.prefix(3).map { $0.food.name }
        guard names.isEmpty == false else { return nil }
        return names.joined(separator: ", ")
    }

    private func upsertComponent(_ component: MealComponentDraft) {
        if let index = components.firstIndex(where: { $0.food.id == component.food.id }) {
            components[index] = component
        } else {
            components.append(component)
        }
    }

    private func deleteComponents(at offsets: IndexSet) {
        let idsToDelete = offsets.map { sortedComponents[$0].food.id }
        components.removeAll { idsToDelete.contains($0.food.id) }
    }

    private func loadExistingMealIfNeeded() {
        guard components.isEmpty, let meal else { return }

        do {
            components = try mealRepository.nutritionSummary(for: meal).components.map { summary in
                MealComponentDraft(summary: summary)
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveMeal() {
        do {
            let savedMeal = try mealRepository.saveMeal(
                id: meal?.id,
                name: name,
                components: components.map(\.input),
                operation: meal == nil ? "Save meal" : "Update meal"
            )
            errorMessage = nil
            saveFeedbackToken += 1
            onMealSaved(savedMeal)
            if meal == nil {
                savedMealRoute = SavedMealRoute(id: savedMeal.id)
            } else {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
            assertionFailure(error.localizedDescription)
        }
    }

    private func deleteMeal(_ meal: Meal) {
        do {
            try mealRepository.deleteMeal(meal, operation: "Delete meal")
            onMealDeleted()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            assertionFailure(error.localizedDescription)
        }
    }
}

private struct SavedMealRoute: Identifiable, Hashable {
    let id: UUID
}

private struct SavedMealLogDestination: View {
    @Environment(\.modelContext) private var modelContext

    let mealID: UUID
    let loggingDay: CalendarDay?
    let onMealLogged: () -> Void

    var body: some View {
        if let meal = try? MealRepository(modelContext: modelContext).fetchMeal(id: mealID) {
            LogMealScreen(meal: meal, loggingDay: loggingDay, onMealLogged: onMealLogged)
        } else {
            ContentUnavailableView(
                "Meal unavailable",
                systemImage: "fork.knife.circle",
                description: Text("This meal is no longer available.")
            )
        }
    }
}

struct MealComponentDraft: Identifiable, Hashable {
    let id: UUID
    let food: FoodItem
    var quantityMode: QuantityMode
    var quantityAmount: Double

    init(food: FoodItem, quantityMode: QuantityMode = .servings, quantityAmount: Double = 1) {
        self.id = food.id
        self.food = food
        self.quantityMode = quantityMode
        self.quantityAmount = quantityAmount
    }

    init(summary: MealComponentSummary) {
        self.init(
            food: summary.food,
            quantityMode: summary.quantityMode,
            quantityAmount: summary.quantityAmount
        )
    }

    var nutrients: LoggedFoodNutrients {
        NutritionMath.consumedNutrients(for: food, mode: quantityMode, amount: quantityAmount)
    }

    var quantitySummary: String {
        quantityMode.formattedSummary(amount: quantityAmount)
    }

    var input: MealComponentInput {
        MealComponentInput(
            foodItemID: food.id,
            quantityMode: quantityMode,
            quantityAmount: quantityAmount
        )
    }

    static func == (lhs: MealComponentDraft, rhs: MealComponentDraft) -> Bool {
        lhs.id == rhs.id
            && lhs.quantityMode == rhs.quantityMode
            && lhs.quantityAmount == rhs.quantityAmount
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(quantityMode)
        hasher.combine(quantityAmount)
    }
}
