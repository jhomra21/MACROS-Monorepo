import SwiftUI

struct SuggestionPillLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(.primary)
            .padding(.horizontal, SearchFoodSpacing.pillHorizontalPadding)
            .padding(.vertical, SearchFoodSpacing.pillVerticalPadding)
            .background(fallbackBackground)
            .contentShape(Capsule())
            .ifAvailableSuggestionGlassCapsule()
    }

    @ViewBuilder
    private var fallbackBackground: some View {
        if #unavailable(iOS 26, macOS 26) {
            PlatformColors.cardBackground
                .clipShape(Capsule())
        }
    }
}

private extension View {
    @ViewBuilder
    func ifAvailableSuggestionGlassCapsule() -> some View {
        if #available(iOS 26, macOS 26, *) {
            glassEffect(.regular.interactive(), in: .capsule)
        } else {
            self
        }
    }
}

struct LocalFoodRow: View {
    let food: FoodItem

    var body: some View {
        FoodNutritionRow(
            name: food.name,
            subtitle: nil,
            calories: food.caloriesPerServing,
            protein: food.proteinPerServing,
            carbs: food.carbsPerServing,
            fat: food.fatPerServing
        )
    }
}

struct RemoteFoodRow: View {
    let result: RemoteSearchResult

    var body: some View {
        if let nutrition = result.nutritionPreview {
            FoodNutritionRow(
                name: result.name,
                subtitle: nil,
                calories: nutrition.calories,
                protein: nutrition.protein,
                carbs: nutrition.carbs,
                fat: nutrition.fat
            )
        } else {
            Text(result.name)
                .font(.headline)
                .foregroundStyle(.primary)
                .padding(.vertical, 16)
        }
    }
}
