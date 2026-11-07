import SwiftData
import SwiftUI

extension View {
    /// Trailing swipe action that deletes a saved food. Pass `nil` for rows that are not saved foods, such as common foods.
    /// Requires an ancestor `savedFoodDeletion(onDeleted:)`.
    func savedFoodDeleteSwipeAction(foodID: UUID?) -> some View {
        modifier(SavedFoodDeleteSwipeAction(foodID: foodID))
    }

    /// Deletes saved foods for descendant `savedFoodDeleteSwipeAction` rows.
    /// Logged entries keep their own nutrient snapshots, so only the reusable `FoodItem` is removed.
    func savedFoodDeletion(onDeleted: @escaping (UUID) -> Void = { _ in }) -> some View {
        modifier(SavedFoodDeletionModifier(onDeleted: onDeleted))
    }
}

private struct DeleteSavedFoodAction {
    let mealFoodIDs: Set<UUID>
    let perform: (UUID) -> Void
}

extension EnvironmentValues {
    @Entry fileprivate var deleteSavedFood: DeleteSavedFoodAction?
}

private struct SavedFoodDeleteSwipeAction: ViewModifier {
    @Environment(\.deleteSavedFood) private var deleteSavedFood
    let foodID: UUID?

    func body(content: Content) -> some View {
        content.swipeActions(edge: .trailing) {
            // The destructive role removes the row at once, so only offer it when the delete cannot be refused.
            // Foods used by saved meals stay; their editor explains why.
            if let foodID, let deleteSavedFood, deleteSavedFood.mealFoodIDs.contains(foodID) == false {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    deleteSavedFood.perform(foodID)
                }
            }
        }
    }
}

private struct SavedFoodDeletionModifier: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @Query private var mealComponents: [MealComponent]
    @State private var errorMessage: String?
    let onDeleted: (UUID) -> Void

    func body(content: Content) -> some View {
        content
            .environment(
                \.deleteSavedFood,
                DeleteSavedFoodAction(mealFoodIDs: Set(mealComponents.map(\.foodItemID)), perform: delete)
            )
            .alert(
                "Can't Delete Food",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { isPresented in
                        if isPresented == false { errorMessage = nil }
                    }
                ),
                presenting: errorMessage
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { message in
                Text(message)
            }
    }

    private func delete(_ foodID: UUID) {
        let repository = FoodItemRepository(modelContext: modelContext)
        do {
            if let food = try repository.fetchReusableFood(id: foodID) {
                try repository.deleteReusableFood(food, operation: "Delete saved food")
            }
            onDeleted(foodID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
