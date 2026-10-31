import SwiftUI

struct FoodNutritionRow<Title: View>: View {
    let title: Title
    let subtitle: String?
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    var verticalPadding: CGFloat = 16

    init(
        subtitle: String?,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        verticalPadding: CGFloat = 16,
        @ViewBuilder title: () -> Title
    ) {
        self.title = title()
        self.subtitle = subtitle
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.verticalPadding = verticalPadding
    }

    var body: some View {
        HStack(spacing: 14) {
            leftContent

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text("\(calories.roundedForDisplay) kcal")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                Text("P \(protein.roundedForDisplay) • C \(carbs.roundedForDisplay) • F \(fat.roundedForDisplay)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, verticalPadding)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var leftContent: some View {
        if let subtitle {
            VStack(alignment: .leading, spacing: 6) {
                titleText
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        } else {
            titleText
        }
    }

    private var titleText: some View {
        title
            .font(.headline)
            .foregroundStyle(.primary)
    }
}

extension FoodNutritionRow where Title == Text {
    init(
        name: String,
        subtitle: String?,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        verticalPadding: CGFloat = 16
    ) {
        self.init(
            subtitle: subtitle,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            verticalPadding: verticalPadding
        ) {
            Text(name)
        }
    }
}
