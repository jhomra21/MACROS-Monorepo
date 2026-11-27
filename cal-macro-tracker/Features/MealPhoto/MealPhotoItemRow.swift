import SwiftUI

/// One suggested food: what the photo showed, the MACROS food it maps to, and an editable amount.
struct MealPhotoItemRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Binding var item: MealPhotoItem
    var amountFocus: FocusState<UUID?>.Binding
    let onChangeFood: () -> Void

    private var title: String { item.suggestion?.name ?? item.food?.name ?? "Food" }
    private var unit: String { item.quantityMode == .grams ? "g" : "servings" }
    private var amountLabel: String { item.quantityMode == .grams ? "Grams" : "Servings" }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            if let note {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Button(action: onChangeFood) {
                HStack(spacing: 6) {
                    Text(item.food?.name ?? "Choose a food")
                        .multilineTextAlignment(.leading)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(item.food == nil ? Color.orange : Color.accentColor)
            .accessibilityLabel(item.food.map { "\(title) matched to \($0.name)" } ?? "\(title) has no match")
            .accessibilityHint("Change the matched food")
            amountField
            Text(nutritionText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private var amountField: some View {
        let layout =
            dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            TextField(amountLabel, value: $item.amount, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
                .focused(amountFocus, equals: item.id)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 110)
                .accessibilityLabel("\(title) \(amountLabel.lowercased())")
            Text(unit == "g" ? "g" : servingUnit)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }

    private var servingUnit: String {
        guard let serving = item.food?.servingDescription else { return unit }
        return "servings of \(serving)"
    }

    private var note: String? {
        guard let suggestion = item.suggestion else { return nil }
        if suggestion.grams == nil, let volume = suggestion.volumeMl {
            return "About \(volume.roundedForDisplay) ml. Enter how much you had."
        }
        if item.food != nil, item.quantityMode == .servings {
            return "No gram weight for this food. Choose servings."
        }
        return suggestion.preparation
    }

    private var nutritionText: String {
        guard item.isReadyToLog else { return "Enter an amount to log this food." }
        let nutrients = item.nutrients
        return "\(nutrients.calories.formatted(.number.precision(.fractionLength(0)))) kcal • "
            + MacroSummaryText.line(protein: nutrients.protein, carbs: nutrients.carbs, fat: nutrients.fat, separator: " • ", unit: "")
    }
}
