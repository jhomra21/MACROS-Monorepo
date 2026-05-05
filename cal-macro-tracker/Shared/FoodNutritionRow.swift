import SwiftUI

struct FoodNutritionRow: View {
    let name: String
    let subtitle: String?
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double

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
            }
        }
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var leftContent: some View {
        if let subtitle {
            VStack(alignment: .leading, spacing: 6) {
                nameText
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        } else {
            nameText
        }
    }

    private var nameText: some View {
        Text(name)
            .font(.headline)
            .foregroundStyle(.primary)
    }
}
