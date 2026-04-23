import SwiftUI

struct FoodQuantitySection: View {
    @Binding var quantityMode: QuantityMode
    @Binding var servingsAmount: Double
    @Binding var gramsAmount: Double
    let canLogByGrams: Bool
    let gramsPerServing: Double?
    let gramLoggingMessage: String
    let showsGramLoggingMessageOnlyInGramsMode: Bool

    init(
        quantityMode: Binding<QuantityMode>,
        servingsAmount: Binding<Double>,
        gramsAmount: Binding<Double>,
        canLogByGrams: Bool,
        gramsPerServing: Double?,
        gramLoggingMessage: String = FoodDraftValidationError.gramsPerServingRequiredForGramLogging.errorDescription
            ?? "Add grams per serving to log by grams.",
        showsGramLoggingMessageOnlyInGramsMode: Bool = false
    ) {
        _quantityMode = quantityMode
        _servingsAmount = servingsAmount
        _gramsAmount = gramsAmount
        self.canLogByGrams = canLogByGrams
        self.gramsPerServing = gramsPerServing
        self.gramLoggingMessage = gramLoggingMessage
        self.showsGramLoggingMessageOnlyInGramsMode = showsGramLoggingMessageOnlyInGramsMode
    }

    var body: some View {
        Section("Quantity") {
            Picker("Mode", selection: $quantityMode) {
                Text("Servings").tag(QuantityMode.servings)
                Text("Grams").tag(QuantityMode.grams)
            }
            .pickerStyle(.segmented)

            quantityStepper

            if shouldShowGramLoggingMessage {
                Text(gramLoggingMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            normalizeQuantityModeIfNeeded()
        }
        .onChange(of: canLogByGrams) { _, canLogByGrams in
            guard !canLogByGrams else { return }
            normalizeQuantityModeIfNeeded()
        }
        .onChange(of: quantityMode) { previousMode, newMode in
            FoodQuantityState.convertAmounts(
                from: previousMode,
                to: newMode,
                servingsAmount: &servingsAmount,
                gramsAmount: &gramsAmount,
                gramsPerServing: gramsPerServing
            )
        }
        .onChange(of: servingsAmount) { _, _ in
            guard quantityMode == .servings else { return }
            FoodQuantityState.syncInactiveAmount(
                for: quantityMode,
                servingsAmount: &servingsAmount,
                gramsAmount: &gramsAmount,
                gramsPerServing: gramsPerServing
            )
        }
        .onChange(of: gramsAmount) { _, _ in
            guard quantityMode == .grams else { return }
            FoodQuantityState.syncInactiveAmount(
                for: quantityMode,
                servingsAmount: &servingsAmount,
                gramsAmount: &gramsAmount,
                gramsPerServing: gramsPerServing
            )
        }
        .onChange(of: gramsPerServing) { _, _ in
            FoodQuantityState.syncInactiveAmount(
                for: quantityMode,
                servingsAmount: &servingsAmount,
                gramsAmount: &gramsAmount,
                gramsPerServing: gramsPerServing
            )
        }
    }

    private func normalizeQuantityModeIfNeeded() {
        if !canLogByGrams && quantityMode == .grams {
            quantityMode = .servings
        }
    }

    private var shouldShowGramLoggingMessage: Bool {
        guard !canLogByGrams else { return false }
        return !showsGramLoggingMessageOnlyInGramsMode || quantityMode == .grams
    }

    @ViewBuilder
    private var quantityStepper: some View {
        switch quantityMode {
        case .servings:
            Stepper {
                LabeledContent("Servings") {
                    Text(servingsAmount.formattedQuantityAmount(maxFractionDigits: 2))
                        .monospacedDigit()
                }
            } onIncrement: {
                servingsAmount = servingsAmount < 0.25 ? 0.25 : servingsAmount + 0.25
            } onDecrement: {
                guard servingsAmount > 0.25 else { return }
                servingsAmount = max(0.25, servingsAmount - 0.25)
            }
        case .grams:
            Stepper {
                LabeledContent("Grams") {
                    Text("\(gramsAmount.formattedQuantityAmount(maxFractionDigits: 2)) g")
                        .monospacedDigit()
                }
            } onIncrement: {
                gramsAmount = gramsAmount < 1 ? 1 : gramsAmount + 5
            } onDecrement: {
                guard gramsAmount > 1 else { return }
                gramsAmount = max(1, gramsAmount - 5)
            }
        }
    }

}

private extension Double {
    func formattedQuantityAmount(maxFractionDigits: Int) -> String {
        formatted(
            FloatingPointFormatStyle<Double>.number
                .grouping(.never)
                .precision(.fractionLength(0...maxFractionDigits))
                .locale(.current)
        )
    }
}

enum FoodQuantityState {
    static func initialAmounts(for entry: LogEntry) -> (servings: Double, grams: Double) {
        (
            servings: initialServingsAmount(for: entry),
            grams: initialGramsAmount(for: entry)
        )
    }

    static func convertAmounts(
        from previousMode: QuantityMode,
        to newMode: QuantityMode,
        servingsAmount: inout Double,
        gramsAmount: inout Double,
        gramsPerServing: Double?
    ) {
        guard previousMode != newMode else { return }
        guard let gramsPerServing = validGramsPerServing(from: gramsPerServing) else { return }

        switch (previousMode, newMode) {
        case (.servings, .grams):
            gramsAmount = servingsAmount * gramsPerServing
        case (.grams, .servings):
            servingsAmount = gramsAmount / gramsPerServing
        case (.servings, .servings), (.grams, .grams):
            break
        }
    }

    static func syncInactiveAmount(
        for quantityMode: QuantityMode,
        servingsAmount: inout Double,
        gramsAmount: inout Double,
        gramsPerServing: Double?
    ) {
        guard let gramsPerServing = validGramsPerServing(from: gramsPerServing) else { return }

        switch quantityMode {
        case .servings:
            gramsAmount = servingsAmount * gramsPerServing
        case .grams:
            servingsAmount = gramsAmount / gramsPerServing
        }
    }

    private static func validGramsPerServing(from gramsPerServing: Double?) -> Double? {
        guard let gramsPerServing, gramsPerServing > 0 else { return nil }
        return gramsPerServing
    }

    private static func initialServingsAmount(for entry: LogEntry) -> Double {
        if entry.quantityModeKind == .servings {
            return positiveValue(entry.servingsConsumed) ?? 1
        }

        guard
            let gramsConsumed = entry.gramsConsumed,
            let gramsPerServing = validGramsPerServing(from: entry.gramsPerServing)
        else {
            return 1
        }

        return positiveValue(gramsConsumed / gramsPerServing) ?? 1
    }

    private static func initialGramsAmount(for entry: LogEntry) -> Double {
        if entry.quantityModeKind == .grams {
            return positiveValue(entry.gramsConsumed) ?? 1
        }

        guard
            let servingsConsumed = entry.servingsConsumed,
            let gramsPerServing = validGramsPerServing(from: entry.gramsPerServing)
        else {
            return positiveValue(entry.gramsPerServing) ?? 100
        }

        return positiveValue(servingsConsumed * gramsPerServing) ?? 100
    }

    private static func positiveValue(_ value: Double?) -> Double? {
        guard let value, value > 0 else { return nil }
        return value
    }
}
