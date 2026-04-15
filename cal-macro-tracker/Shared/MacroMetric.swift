import SwiftUI

enum MacroMetric: CaseIterable, Identifiable {
    case protein
    case carbs
    case fat

    var id: Self { self }

    var title: String {
        switch self {
        case .protein:
            "Protein"
        case .carbs:
            "Carbs"
        case .fat:
            "Fat"
        }
    }

    var shortTitle: String {
        switch self {
        case .protein:
            "P"
        case .carbs:
            "C"
        case .fat:
            "F"
        }
    }

    var accentColor: Color {
        switch self {
        case .protein:
            .blue
        case .carbs:
            .orange
        case .fat:
            .pink
        }
    }

    func value(from totals: NutritionSnapshot) -> Double {
        switch self {
        case .protein:
            totals.protein
        case .carbs:
            totals.carbs
        case .fat:
            totals.fat
        }
    }

    func goal(from goals: MacroGoalsSnapshot) -> Double {
        switch self {
        case .protein:
            goals.proteinGoalGrams
        case .carbs:
            goals.carbGoalGrams
        case .fat:
            goals.fatGoalGrams
        }
    }
}
