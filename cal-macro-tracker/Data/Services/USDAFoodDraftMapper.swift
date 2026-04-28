import Foundation

enum USDAFoodDraftMapper {
    static func makeDraft(from food: USDAProxyFood) -> FoodDraft {
        FoodDraft(importedData: food.importedData)
    }
}
