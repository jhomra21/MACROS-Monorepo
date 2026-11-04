import SwiftData
import SwiftUI

struct WeightEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppStorageKeys.weightUnit) private var weightUnit = WeightUnit.initial(profileUnitSystem: nil)
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var focusedField: WeightField?
    @State private var amount = ""
    @State private var day = Date.now
    @State private var errorMessage: String?
    @State private var saveFeedbackToken = 0
    /// The exact weight behind a unit-switched value, so the rounded text does not drift on repeated switches.
    @State private var convertedEntry: (text: String, kilograms: Double)?

    private enum WeightField: Hashable {
        case amount
    }

    private var kilograms: Double? {
        if let convertedEntry, convertedEntry.text == amount { return convertedEntry.kilograms }
        guard case let .valid(value) = NumericText.state(for: amount), value > 0 else { return nil }
        return weightUnit.fromDisplay(value)
    }

    var body: some View {
        NavigationStack {
            Form {
                weightRowLayout {
                    AppNumericTextField(
                        "Weight",
                        text: $amount,
                        focusedField: $focusedField,
                        field: .amount
                    )
                    .accessibilityLabel("Weight in \(weightUnit.accessibilityName)")
                    Picker("Weight unit", selection: $weightUnit) {
                        ForEach(WeightUnit.allCases, id: \.self) { unit in
                            Text(unit.symbol).tag(unit)
                                .accessibilityLabel(unit.accessibilityName)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 120)
                }
                DatePicker("Date", selection: $day, in: ...Date.now, displayedComponents: .date)
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
            .sensoryFeedback(.success, trigger: saveFeedbackToken)
            .navigationTitle("Log Weight")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(kilograms == nil)
                }
            }
            .keyboardNavigationToolbar(focusedField: $focusedField, fields: [.amount])
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onChange(of: weightUnit) { oldUnit, newUnit in
            let exactKilograms: Double
            if let convertedEntry, convertedEntry.text == amount {
                exactKilograms = convertedEntry.kilograms
            } else if case let .valid(value) = NumericText.state(for: amount), value > 0 {
                exactKilograms = oldUnit.fromDisplay(value)
            } else {
                return
            }
            amount = NumericText.editingDisplay(for: (newUnit.toDisplay(exactKilograms) * 10).rounded() / 10)
            convertedEntry = (amount, exactKilograms)
        }
    }

    private var weightRowLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
    }

    private func save() {
        guard let kilograms else { return }
        do {
            try WeightRepository(modelContext: modelContext).upsertManual(weightKg: kilograms, day: day)
            saveFeedbackToken += 1
            dismiss()
        } catch {
            errorMessage = "Could not save this weight. Try again."
        }
    }
}
