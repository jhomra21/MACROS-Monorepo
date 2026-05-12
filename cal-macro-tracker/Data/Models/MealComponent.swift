import Foundation
import SwiftData

@Model
final class MealComponent {
    var id: UUID
    var mealID: UUID
    var foodItemID: UUID
    var quantityMode: String
    var servingsAmount: Double?
    var gramsAmount: Double?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        mealID: UUID,
        foodItemID: UUID,
        quantityMode: QuantityMode,
        quantityAmount: Double,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.mealID = mealID
        self.foodItemID = foodItemID
        self.quantityMode = quantityMode.rawValue
        switch quantityMode {
        case .servings:
            self.servingsAmount = quantityAmount
            self.gramsAmount = nil
        case .grams:
            self.servingsAmount = nil
            self.gramsAmount = quantityAmount
        }
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var quantityModeKind: QuantityMode {
        QuantityMode(rawValue: quantityMode) ?? .servings
    }

    var quantityAmount: Double {
        switch quantityModeKind {
        case .servings:
            return servingsAmount ?? 0
        case .grams:
            return gramsAmount ?? 0
        }
    }
}
