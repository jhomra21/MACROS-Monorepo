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
                foodPanel(draft, servings: servings, logged: logged)
            case let .label(draft, notes, missingNutrients, servings, logged):
                foodPanel(
                    draft,
                    servings: servings,
                    logged: logged,
                    notes: notes,
                    missingNutrients: missingNutrients
                )
            case let .error(message):
                errorPanel(message)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
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
        notes: [String]? = nil,
        missingNutrients: [RequiredNutritionReviewNutrient] = []
    ) -> some View {
        let isLabel = notes != nil
        return VStack(alignment: .leading, spacing: 12) {
            if isLabel == false {
                Text(logged ? "Logged" : draft.name).font(.headline)
            } else {
                if logged {
                    Text("Logged").font(.headline)
                    Text(draft.name).foregroundStyle(.secondary)
                } else {
                    TextField("Name", text: Binding(get: { draft.name }, set: onChangeName))
                        .font(.headline)
                        .submitLabel(.done)
                }
            }
            if logged {
                if isLabel == false { Text(draft.name).foregroundStyle(.secondary) }
            } else {
                if isLabel == false {
                    if draft.brand.isEmpty == false { Text(draft.brand).foregroundStyle(.secondary) }
                }
                if isLabel {
                    Text("Serving: \(draft.servingDescription)").font(.subheadline)
                } else {
                    Text(draft.servingDescription).font(.subheadline)
                }
                Text(nutritionLine(draft))
                    .font(.subheadline.weight(.medium))
                ForEach(Array((notes ?? []).enumerated()), id: \.offset) { _, note in
                    Text(note).font(.footnote).foregroundStyle(.secondary)
                }
                if missingNutrients.isEmpty == false {
                    Text(NutritionLabelParser.reviewRequiredNutrientsMessage(missingNutrients))
                        .font(.footnote).foregroundStyle(.orange)
                }
                Stepper(value: Binding(get: { servings }, set: onChangeServings), in: 0.25...20, step: 0.25) {
                    Text("Servings: \(servings.formatted(.number.precision(.fractionLength(0...2))))")
                }
                ViewThatFits(in: .horizontal) {
                    if isLabel == false {
                        HStack {
                            Button("Details", action: onDetails).buttonStyle(.bordered)
                            Button("Log", action: onLog).buttonStyle(.borderedProminent)
                        }
                        VStack {
                            Button("Details", action: onDetails).buttonStyle(.bordered)
                            Button("Log", action: onLog).buttonStyle(.borderedProminent)
                        }
                    } else {
                        labelActions(draft: draft, missingNutrients: missingNutrients, servings: servings)
                    }
                }
            }
            Button(isLabel ? "Retake" : "Scan again", action: onRetry).font(.subheadline)
        }
    }

    private func labelActions(
        draft: FoodDraft,
        missingNutrients: [RequiredNutritionReviewNutrient],
        servings: Double
    ) -> some View {
        Group {
            if missingNutrients.isEmpty {
                ViewThatFits(in: .horizontal) {
                    HStack {
                        Button("Edit details", action: onReview).buttonStyle(.bordered)
                        Button("Log", action: onLog).buttonStyle(.borderedProminent)
                            .disabled(
                                draft.loggingAction(initialDraft: draft, quantityMode: .servings, quantityAmount: servings).canLog == false)
                    }
                    VStack {
                        Button("Edit details", action: onReview).buttonStyle(.bordered)
                        Button("Log", action: onLog).buttonStyle(.borderedProminent)
                            .disabled(
                                draft.loggingAction(initialDraft: draft, quantityMode: .servings, quantityAmount: servings).canLog == false)
                    }
                }
            } else {
                Button("Edit details", action: onReview).buttonStyle(.borderedProminent)
            }
        }
    }

    private func errorPanel(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(message).font(.subheadline)
            Button("Scan again", action: onRetry).buttonStyle(.borderedProminent)
            Button("Search online", action: onSearch)
            Text("Or photograph the nutrition label instead.").font(.footnote).foregroundStyle(.secondary)
            Button("Enter manually", action: onManual)
            if showSettings {
                Button("Open Settings", action: onSettings)
            }
        }
    }

    private func nutritionLine(_ draft: FoodDraft) -> String {
        "\(draft.caloriesPerServing.formatted(.number.precision(.fractionLength(0...1)))) cal · "
            + "P \(draft.proteinPerServing.formatted(.number.precision(.fractionLength(0...1))))g · "
            + "C \(draft.carbsPerServing.formatted(.number.precision(.fractionLength(0...1))))g · "
            + "F \(draft.fatPerServing.formatted(.number.precision(.fractionLength(0...1))))g"
    }
}
