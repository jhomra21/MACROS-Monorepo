import SwiftUI

struct MealComponentQuantityScreen: View {
    @Environment(\.dismiss) private var dismiss

    let component: MealComponentDraft
    let onSave: (MealComponentDraft) -> Void

    @State private var quantityMode: QuantityMode
    @State private var servingsAmount: Double
    @State private var gramsAmount: Double

    init(component: MealComponentDraft, onSave: @escaping (MealComponentDraft) -> Void) {
        self.component = component
        self.onSave = onSave
        var servingsAmount = component.quantityMode == .servings ? component.quantityAmount : 1
        var gramsAmount =
            component.quantityMode == .grams
            ? component.quantityAmount : max(component.food.gramsPerServing ?? 1, 1)
        FoodQuantityState.syncInactiveAmount(
            for: component.quantityMode,
            servingsAmount: &servingsAmount,
            gramsAmount: &gramsAmount,
            gramsPerServing: component.food.gramsPerServing
        )
        _quantityMode = State(initialValue: component.quantityMode)
        _servingsAmount = State(initialValue: servingsAmount)
        _gramsAmount = State(initialValue: gramsAmount)
    }

    private var selectedAmount: Double {
        quantityMode == .servings ? servingsAmount : gramsAmount
    }

    private var selectedNutrients: LoggedFoodNutrients {
        NutritionMath.consumedNutrients(
            for: component.food,
            mode: quantityMode,
            amount: selectedAmount
        )
    }

    private var canSave: Bool {
        selectedAmount.isFinite && selectedAmount > 0
    }

    var body: some View {
        Form {
            Section("Food") {
                FoodNutritionRow(
                    name: component.food.name,
                    subtitle: component.food.servingDescription,
                    calories: selectedNutrients.calories,
                    protein: selectedNutrients.protein,
                    carbs: selectedNutrients.carbs,
                    fat: selectedNutrients.fat
                )
            }

            FoodQuantitySection(
                quantityMode: $quantityMode,
                servingsAmount: $servingsAmount,
                gramsAmount: $gramsAmount,
                canLogByGrams: canLogByGrams,
                gramsPerServing: component.food.gramsPerServing
            )
        }
        .navigationTitle("Food Quantity")
        .inlineNavigationTitle()
        .safeAreaInset(edge: .bottom) {
            BottomPinnedActionBar(title: "Save Quantity", systemImage: nil, isDisabled: !canSave) {
                onSave(
                    MealComponentDraft(
                        food: component.food,
                        quantityMode: quantityMode,
                        quantityAmount: selectedAmount
                    )
                )
                dismiss()
            }
        }
    }

    private var canLogByGrams: Bool {
        guard let gramsPerServing = component.food.gramsPerServing else { return false }
        return gramsPerServing.isFinite && gramsPerServing > 0
    }
}
