import SwiftData
import SwiftUI

struct WeightEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [BodyProfile]
    @State private var amount = ""
    @State private var day = Date.now
    @State private var errorMessage: String?

    private var profile: BodyProfile? { BodyProfile.activeRecord(from: profiles) }
    private var unit: GoalUnitSystem { profile?.unitSystem ?? .metric }
    private var kilograms: Double? {
        guard case let .valid(value) = NumericText.state(for: amount), value > 0 else { return nil }
        return unit == .metric ? value : try? GoalCalculator.kg(fromPounds: value)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(unit == .metric ? "Weight (kg)" : "Weight (lb)", text: $amount)
                    .keyboardType(.decimalPad)
                    .accessibilityLabel(unit == .metric ? "Weight in kilograms" : "Weight in pounds")
                DatePicker("Date", selection: $day, in: ...Date.now, displayedComponents: .date)
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle("Log weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(kilograms == nil)
                }
            }
        }
        .presentationDetents([.height(270)])
    }

    private func save() {
        guard let kilograms else { return }
        do {
            try WeightRepository(modelContext: modelContext).upsertManual(weightKg: kilograms, day: day)
            dismiss()
        } catch {
            errorMessage = "Could not save this weight. Try again."
        }
    }
}
