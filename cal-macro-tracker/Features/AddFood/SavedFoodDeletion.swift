import SwiftData
import SwiftUI

extension View {
    /// Trailing swipe action that deletes a saved food. Pass `nil` for rows that are not saved foods, such as common foods.
    /// Requires an ancestor `savedFoodDeletion(onDeleted:onRestored:)`.
    func savedFoodDeleteSwipeAction(foodID: UUID?) -> some View {
        modifier(SavedFoodDeleteSwipeAction(foodID: foodID))
    }

    /// Deletes saved foods for descendant `savedFoodDeleteSwipeAction` rows and offers Undo for the latest delete.
    /// Logged entries keep their own nutrient snapshots, so only the reusable `FoodItem` is removed.
    func savedFoodDeletion(
        onDeleted: @escaping (UUID) -> Void = { _ in },
        onRestored: @escaping (UUID) -> Void = { _ in }
    ) -> some View {
        modifier(SavedFoodDeletionModifier(onDeleted: onDeleted, onRestored: onRestored))
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
            // Foods used by saved meals offer no action; their editor explains why.
            if let foodID, let deleteSavedFood, deleteSavedFood.mealFoodIDs.contains(foodID) == false {
                // Not `role: .destructive`: that role deletes the list item before the data changes, so a failed save,
                // or the last row turning into an empty-state row, crashes UICollectionView's batch update.
                Button("Delete", systemImage: "trash") {
                    deleteSavedFood.perform(foodID)
                }
                .tint(.red)
            }
        }
    }
}

/// Everything needed to put a deleted food back unchanged, captured before the delete.
private struct DeletedSavedFood {
    let food: BackupFood
    let searchableText: String
}

private struct SavedFoodDeletionModifier: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var mealComponents: [MealComponent]
    /// Only the latest delete can be undone; a new delete replaces the banner and makes the previous one final.
    @State private var deletedFood: DeletedSavedFood?
    @State private var errorTitle = ""
    @State private var errorMessage: String?
    let onDeleted: (UUID) -> Void
    let onRestored: (UUID) -> Void

    func body(content: Content) -> some View {
        content
            .environment(
                \.deleteSavedFood,
                DeleteSavedFoodAction(mealFoodIDs: Set(mealComponents.map(\.foodItemID)), perform: delete)
            )
            .safeAreaInset(edge: .bottom) {
                if let deletedFood {
                    SavedFoodUndoBanner(name: deletedFood.food.name) {
                        undo(deletedFood)
                    }
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .smooth, value: deletedFood?.food.id)
            .task(id: undoCountdownID) {
                // Undo is offered for a few seconds, like a system snackbar. SwiftUI cancels this task when a newer
                // delete, Undo, or an error alert changes the id, or the screen goes away; a cancelled sleep returns
                // before clearing, so a stale timer never hides a newer banner, and dismissing an alert restarts the
                // countdown. VoiceOver users keep the banner until they act or leave.
                guard undoCountdownID != nil, voiceOverEnabled == false,
                    (try? await Task.sleep(for: .seconds(5))) != nil
                else { return }
                deletedFood = nil
            }
            .errorBanner(message: $errorMessage, title: errorTitle)
    }

    private var undoCountdownID: UUID? {
        errorMessage == nil ? deletedFood?.food.id : nil
    }

    private func delete(_ foodID: UUID) {
        let repository = FoodItemRepository(modelContext: modelContext)
        do {
            if let food = try repository.fetchReusableFood(id: foodID) {
                let snapshot = DeletedSavedFood(food: BackupFood(food), searchableText: food.searchableText)
                try repository.deleteReusableFood(food, operation: "Delete saved food")
                deletedFood = snapshot
                AccessibilityNotification.Announcement("Deleted \(snapshot.food.name)").post()
            }
            onDeleted(foodID)
        } catch {
            errorTitle = "Can't Delete Food"
            errorMessage = error.localizedDescription
        }
    }

    private func undo(_ deleted: DeletedSavedFood) {
        let food = deleted.food.model
        food.searchableText = deleted.searchableText
        do {
            try FoodItemRepository(modelContext: modelContext).restoreReusableFood(food, operation: "Undo delete saved food")
            deletedFood = nil
            onRestored(deleted.food.id)
        } catch {
            errorTitle = "Can't Undo"
            errorMessage = error.localizedDescription
        }
    }
}

private struct SavedFoodUndoBanner: View {
    let name: String
    let undo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("Deleted \(name)")
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Undo", action: undo)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .appGlassRoundedRect(cornerRadius: 24, interactive: false)
        .accessibilityElement(children: .contain)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}
