import SwiftUI

struct FoodCameraResultPanel: View {
    enum Content: Equatable {
        case message(String)
        case hint(String)
        case barcode(FoodDraft, servings: Double, logged: Bool)
        case label(
            FoodDraft,
            notes: [String],
            missingNutrients: [RequiredNutritionReviewNutrient],
            servings: Double,
            logged: Bool
        )
        case error(String)

        enum Kind: Hashable {
            case message, hint, barcode, barcodeLogged, label, labelLogged, error
        }

        var kind: Kind {
            switch self {
            case .message: .message
            case .hint: .hint
            case .barcode(_, _, let logged): logged ? .barcodeLogged : .barcode
            case .label(_, _, _, _, let logged): logged ? .labelLogged : .label
            case .error: .error
            }
        }
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let content: Content
    let onChangeServings: (Double) -> Void
    let onChangeName: (String) -> Void
    let onLog: () -> Void
    let onDetails: () -> Void
    let onReview: () -> Void
    let onManual: () -> Void
    let onSearch: () -> Void
    var showSettings: Bool = false
    var onSettings: () -> Void = {}

    var body: some View {
        Group {
            switch content {
            case let .message(message):
                status(message)
            case let .hint(message):
                HStack(spacing: 12) {
                    Image(systemName: "viewfinder").foregroundStyle(.secondary)
                    Text(message).font(.subheadline)
                }
            case let .barcode(draft, servings, logged):
                foodPanel(draft, servings: servings, logged: logged, isLabel: false)
            case let .label(draft, notes, missingNutrients, servings, logged):
                foodPanel(
                    draft,
                    servings: servings,
                    logged: logged,
                    isLabel: true,
                    notes: notes,
                    missingNutrients: missingNutrients
                )
            case let .error(message):
                errorPanel(message)
            }
        }
        .id(content.kind)
        .transition(reduceMotion ? AnyTransition.opacity : AnyTransition(.blurReplace))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    private func status(_ message: String) -> some View {
        HStack(spacing: 12) {
            ProgressView()
            Text(message).font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func wideButton(_ title: LocalizedStringKey, prominent: Bool = true, action: @escaping () -> Void)
        -> some View
    {
        let button = Button(action: action) {
            Text(title).frame(maxWidth: .infinity)
        }
        return Group {
            if prominent {
                button.buttonStyle(.glassProminent)
            } else {
                button.buttonStyle(.glass)
            }
        }
        .controlSize(.large)
        .buttonBorderShape(.capsule)
    }

    @ViewBuilder
    private func foodPanel(
        _ draft: FoodDraft,
        servings: Double,
        logged: Bool,
        isLabel: Bool,
        notes: [String] = [],
        missingNutrients: [RequiredNutritionReviewNutrient] = []
    ) -> some View {
        if logged {
            VStack(alignment: .leading, spacing: 4) {
                Label {
                    Text("Logged")
                } icon: {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
                .font(.headline)
                Text(draft.name).foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                header(draft, isLabel: isLabel)
                Text("\(draft.caloriesPerServing.formatted(.number.precision(.fractionLength(0...1)))) kcal")
                    .font(.title2.bold())
                    .monospacedDigit()
                macroCapsules(draft)
                ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                    Text(note).font(.footnote).foregroundStyle(.secondary)
                }
                servingsRow(servings)
                if missingNutrients.isEmpty == false {
                    Label(
                        NutritionLabelParser.reviewRequiredNutrientsMessage(missingNutrients),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.footnote).foregroundStyle(.orange)
                    wideButton("Edit details", action: onReview)
                } else {
                    actionRow(draft, servings: servings, isLabel: isLabel)
                }
            }
        }
    }

    private func header(_ draft: FoodDraft, isLabel: Bool) -> some View {
        let subtitle =
            isLabel
            ? (draft.servingDescription == FoodDraft.defaultServingDescription ? nil : draft.servingDescription)
            : [draft.brand, draft.servingDescription].filter { $0.isEmpty == false }.joined(separator: " · ")
        return VStack(alignment: .leading, spacing: 2) {
            if isLabel {
                TextField("Name", text: Binding(get: { draft.name }, set: onChangeName))
                    .font(.headline)
                    .submitLabel(.done)
            } else {
                Text(draft.name)
                    .font(.headline)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
            }
            if let subtitle {
                Text(subtitle).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func macroCapsules(_ draft: FoodDraft) -> some View {
        let capsules = HStack(spacing: 8) {
            ForEach(MacroMetric.allCases) { metric in
                let color = MacroRingPalette.standard.color(for: metric)
                Text("\(metric.shortTitle) \(grams(metric, in: draft).formatted(.number.precision(.fractionLength(0...1))))g")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .fixedSize()
                    .foregroundStyle(color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.18), in: Capsule())
            }
        }
        return ViewThatFits(in: .horizontal) {
            capsules
            VStack(alignment: .leading, spacing: 8) { capsules }
        }
    }

    private func grams(_ metric: MacroMetric, in draft: FoodDraft) -> Double {
        switch metric {
        case .protein: draft.proteinPerServing
        case .carbs: draft.carbsPerServing
        case .fat: draft.fatPerServing
        }
    }

    private func servingsRow(_ servings: Double) -> some View {
        HStack {
            Text("Servings")
            Spacer()
            Text(servings.formatted(.number.precision(.fractionLength(0...2)))).monospacedDigit()
            Stepper("Servings", value: Binding(get: { servings }, set: onChangeServings), in: 0.25...20, step: 0.25)
                .labelsHidden()
        }
    }

    private func actionRow(_ draft: FoodDraft, servings: Double, isLabel: Bool) -> some View {
        let canLog = draft.loggingAction(initialDraft: draft, quantityMode: .servings, quantityAmount: servings).canLog
        let details = Button(isLabel ? "Edit details" : "Details", action: isLabel ? onReview : onDetails)
            .buttonStyle(.glass)
        let log = Button(action: onLog) { Text("Log").frame(maxWidth: .infinity) }
            .buttonStyle(.glassProminent)
            .disabled(isLabel && canLog == false)
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                details.fixedSize(horizontal: true, vertical: false)
                log
            }
            VStack(spacing: 12) {
                log
                details.frame(maxWidth: .infinity)
            }
        }
        .controlSize(.large)
        .buttonBorderShape(.capsule)
    }

    private func errorPanel(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(message).font(.subheadline)
            if showSettings {
                wideButton("Open Settings", action: onSettings)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    wideButton("Search online", prominent: false, action: onSearch)
                    wideButton("Enter manually", prominent: false, action: onManual)
                }
                VStack(spacing: 12) {
                    wideButton("Search online", prominent: false, action: onSearch)
                    wideButton("Enter manually", prominent: false, action: onManual)
                }
            }
            Text("Or photograph the nutrition label instead.").font(.footnote).foregroundStyle(.secondary)
        }
    }
}
