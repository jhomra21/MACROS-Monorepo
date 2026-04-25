import Foundation

enum RequiredNutritionReviewNutrient: Hashable {
    case calories
    case protein
    case fat
    case carbs

    var displayName: String {
        switch self {
        case .calories:
            "Calories"
        case .protein:
            "Protein"
        case .fat:
            "Fat"
        case .carbs:
            "Carbs"
        }
    }
}
