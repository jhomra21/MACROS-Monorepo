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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let content: Content
    let goals: MacroGoalsSnapshot
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
                HStack(alignment: .center, spacing: 12) {
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
                Text(
                    "\(servingDescription(draft, servings: servings) ?? "\(servings.roundedForDisplay) servings") · \((draft.caloriesPerServing * servings).roundedForDisplay) kcal"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                foodNutritionRow(draft, servings: servings, isLabel: isLabel)
                    .accessibilityElement(children: isLabel ? .contain : .combine)
                    .padding(.bottom, 14)
                ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 8)
                }
                Divider()
                    .padding(.top, notes.isEmpty ? 0 : 6)
                    .padding(.bottom, 12)
                servingsRow(draft, servings: servings)
                    .padding(.bottom, 16)
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

    private func macroRing(_ draft: FoodDraft, servings: Double) -> some View {
        MacroRingSetView(
            totals: NutritionSnapshot(
                calories: draft.caloriesPerServing * servings,
                protein: draft.proteinPerServing * servings,
                fat: draft.fatPerServing * servings,
                carbs: draft.carbsPerServing * servings
            ),
            goals: goals,
            ringDiameter: 44,
            centerValueFontSize: nil,
            minimumLineWidth: 3.5,
            showsGoalSubtitle: false
        )
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func foodNutritionRow(_ draft: FoodDraft, servings: Double, isLabel: Bool) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                foodTitle(draft, isLabel: isLabel)
                if isLabel == false, draft.brand.isEmpty == false {
                    Text(draft.brand)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("\((draft.caloriesPerServing * servings).roundedForDisplay) kcal")
                    .font(.headline.weight(.semibold))
                Text(
                    "P \((draft.proteinPerServing * servings).roundedForDisplay) • C \((draft.carbsPerServing * servings).roundedForDisplay) • F \((draft.fatPerServing * servings).roundedForDisplay)"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        } else {
            HStack(alignment: .center, spacing: 12) {
                macroRing(draft, servings: servings)
                FoodNutritionRow(
                    subtitle: isLabel ? nil : draft.brand.isEmpty ? nil : draft.brand,
                    calories: draft.caloriesPerServing * servings,
                    protein: draft.proteinPerServing * servings,
                    carbs: draft.carbsPerServing * servings,
                    fat: draft.fatPerServing * servings,
                    verticalPadding: 0
                ) {
                    foodTitle(draft, isLabel: isLabel)
                }
            }
        }
    }

    @ViewBuilder
    private func foodTitle(_ draft: FoodDraft, isLabel: Bool) -> some View {
        if isLabel {
            TextField("Food name", text: Binding(get: { draft.name }, set: onChangeName))
                .font(.headline)
                .submitLabel(.done)
        } else {
            Text(draft.name)
                .font(.headline)
                .lineLimit(2)
        }
    }

    private func servingDescription(_ draft: FoodDraft, servings: Double) -> String? {
        let description =
            draft.servingDescription == FoodDraft.defaultServingDescription ? nil : draft.servingDescription
        let grams = draft.gramsPerServing
        let oneServing: String?
        switch (description, grams) {
        case let (description?, grams?):
            let gramsText = grams.roundedForDisplay
            let includesGrams =
                description.range(
                    of: "(?<![\\d.])\(NSRegularExpression.escapedPattern(for: gramsText))\\s*g\\b",
                    options: [.regularExpression, .caseInsensitive]
                ) != nil
            oneServing = includesGrams ? description : "\(description) (\(gramsText) g)"
        case let (nil, grams?):
            oneServing = "\(grams.roundedForDisplay) g"
        case let (description?, nil):
            oneServing = description
        case (nil, nil):
            oneServing = nil
        }
        guard let oneServing else { return nil }
        guard servings != 1 else { return oneServing }
        let each = "\(oneServing) each"
        guard let grams else { return each }
        return "\(each) · \((grams * servings).roundedForDisplay) g total"
    }

    private func servingsRow(_ draft: FoodDraft, servings: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Servings")
                Spacer()
                Text(servings.formatted(.number.precision(.fractionLength(0...2)))).monospacedDigit()
                Stepper("Servings", value: Binding(get: { servings }, set: onChangeServings), in: 0.25...20, step: 0.25)
                    .labelsHidden()
            }
            if let subtitle = servingDescription(draft, servings: servings) {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
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
