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
        HStack(alignment: .center, spacing: SearchFoodSpacing.localFoodRowSpacing) {
            Text(food.name)
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()

            HStack(alignment: .firstTextBaseline, spacing: SearchFoodSpacing.calorieUnitSpacing) {
                Text(food.caloriesPerServing.roundedForDisplay)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("kcal")
                    .font(.footnote.weight(.regular))
                    .foregroundStyle(.tertiary)
            }
            .monospacedDigit()
        }
    }
}

struct RemoteFoodRow: View {
    let result: RemoteSearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(result.name)
                .font(.headline)

            if let brand = result.brand {
                Text(brand)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(result.summary)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}
