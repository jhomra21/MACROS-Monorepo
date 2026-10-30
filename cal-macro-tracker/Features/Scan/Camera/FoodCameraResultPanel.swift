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
    }

    let content: Content
    let onChangeServings: (Double) -> Void
    let onChangeName: (String) -> Void
    let onLog: () -> Void
    let onDetails: () -> Void
    let onReview: () -> Void
    let onRetry: () -> Void
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

    private func foodPanel(
        _ draft: FoodDraft,
        servings: Double,
        logged: Bool,
        isLabel: Bool,
        notes: [String] = [],
        missingNutrients: [RequiredNutritionReviewNutrient] = []
    ) -> some View {
        let canLog = draft.loggingAction(initialDraft: draft, quantityMode: .servings, quantityAmount: servings).canLog
        let detailsButton = Group {
            if isLabel {
                Button("Edit details", action: onReview)
            } else {
                Button("Details", action: onDetails)
            }
        }
        .buttonStyle(.glass)
        .frame(minHeight: 44)
        let logButton = Button("Log", action: onLog)
            .buttonStyle(.glassProminent)
            .frame(minHeight: 44)
            .disabled(isLabel && canLog == false)
        return VStack(alignment: .leading, spacing: 12) {
            if isLabel {
                if logged {
                    Text("Logged").font(.headline)
                    Text(draft.name).foregroundStyle(.secondary)
                } else {
                    TextField("Name", text: Binding(get: { draft.name }, set: onChangeName))
                        .font(.headline)
                        .submitLabel(.done)
                }
            } else {
                Text(logged ? "Logged" : draft.name).font(.headline)
                if logged { Text(draft.name).foregroundStyle(.secondary) }
            }
            if logged == false {
                if isLabel == false, draft.brand.isEmpty == false {
                    Text(draft.brand).foregroundStyle(.secondary)
                }
                if isLabel {
                    if draft.servingDescription != FoodDraft.defaultServingDescription {
                        Text("Serving: \(draft.servingDescription)").font(.subheadline)
                    }
                } else {
                    Text(draft.servingDescription).font(.subheadline)
                }
                Text(nutritionLine(draft))
                    .font(.subheadline.weight(.medium))
                ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                    Text(note).font(.footnote).foregroundStyle(.secondary)
                }
                if missingNutrients.isEmpty == false {
                    Label(
                        NutritionLabelParser.reviewRequiredNutrientsMessage(missingNutrients),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.footnote).foregroundStyle(.orange)
                }
                Stepper(value: Binding(get: { servings }, set: onChangeServings), in: 0.25...20, step: 0.25) {
                    Text("Servings: \(servings.formatted(.number.precision(.fractionLength(0...2))))")
                        .monospacedDigit()
                }
                ViewThatFits(in: .horizontal) {
                    if missingNutrients.isEmpty {
                        HStack {
                            detailsButton
                            logButton
                        }
                        VStack {
                            detailsButton
                            logButton
                        }
                    } else {
                        Button("Edit details", action: onReview)
                            .buttonStyle(.glassProminent)
                            .frame(minHeight: 44)
                    }
                }
            }
            Button(isLabel ? "Retake" : "Scan again", action: onRetry)
                .buttonStyle(.glass)
                .frame(minHeight: 44)
                .font(.subheadline)
        }
    }

    private func errorPanel(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(message).font(.subheadline)
            Button("Scan again", action: onRetry)
                .buttonStyle(.glassProminent)
                .frame(minHeight: 44)
            Button("Search online", action: onSearch)
                .buttonStyle(.glass)
                .frame(minHeight: 44)
            Text("Or photograph the nutrition label instead.").font(.footnote).foregroundStyle(.secondary)
            Button("Enter manually", action: onManual)
                .buttonStyle(.glass)
                .frame(minHeight: 44)
            if showSettings {
                Button("Open Settings", action: onSettings)
                    .buttonStyle(.glass)
                    .frame(minHeight: 44)
            }
        }
    }

    private func nutritionLine(_ draft: FoodDraft) -> String {
        "\(draft.caloriesPerServing.formatted(.number.precision(.fractionLength(0...1)))) kcal · "
            + "P \(draft.proteinPerServing.formatted(.number.precision(.fractionLength(0...1))))g · "
            + "C \(draft.carbsPerServing.formatted(.number.precision(.fractionLength(0...1))))g · "
            + "F \(draft.fatPerServing.formatted(.number.precision(.fractionLength(0...1))))g"
    }
}
