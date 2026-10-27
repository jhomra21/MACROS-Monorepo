import SwiftUI

struct FoodCameraResultPanel: View {
    enum Content {
        case message(String)
        case barcode(FoodDraft, servings: Double, logged: Bool)
        case label(FoodDraft, notes: [String], missingNutrients: [RequiredNutritionReviewNutrient])
        case error(String)
    }

    let content: Content
    let onChangeServings: (Double) -> Void
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
            case let .barcode(draft, servings, logged):
                barcodePanel(draft, servings: servings, logged: logged)
            case let .label(draft, notes, missingNutrients):
                labelPanel(draft, notes: notes, missingNutrients: missingNutrients)
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

    private func barcodePanel(_ draft: FoodDraft, servings: Double, logged: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(logged ? "Logged" : draft.name)
                .font(.headline)
            if logged {
                Text(draft.name).foregroundStyle(.secondary)
            } else {
                if draft.brand.isEmpty == false { Text(draft.brand).foregroundStyle(.secondary) }
                Text(draft.servingDescription).font(.subheadline)
                Text(nutritionLine(draft))
                    .font(.subheadline.weight(.medium))
                Stepper(value: Binding(get: { servings }, set: onChangeServings), in: 0.25...20, step: 0.25) {
                    Text("Servings: \(servings.formatted(.number.precision(.fractionLength(0...2))))")
                }
                ViewThatFits(in: .horizontal) {
                    HStack {
                        Button("Details", action: onDetails).buttonStyle(.bordered)
                        Button("Log", action: onLog).buttonStyle(.borderedProminent)
                    }
                    VStack {
                        Button("Details", action: onDetails).buttonStyle(.bordered)
                        Button("Log", action: onLog).buttonStyle(.borderedProminent)
                    }
                }
            }
            Button("Scan again", action: onRetry).font(.subheadline)
        }
    }

    private func labelPanel(
        _ draft: FoodDraft,
        notes: [String],
        missingNutrients: [RequiredNutritionReviewNutrient]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(draft.name.isEmpty ? "Label read" : draft.name).font(.headline)
            if draft.servingDescription != FoodDraft.defaultServingDescription {
                Text("Serving: \(draft.servingDescription)").font(.subheadline)
            }
            Text(nutritionLine(draft)).font(.subheadline.weight(.medium))
            ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                Text(note).font(.footnote).foregroundStyle(.secondary)
            }
            if missingNutrients.isEmpty == false {
                Text(NutritionLabelParser.reviewRequiredNutrientsMessage(missingNutrients))
                    .font(.footnote).foregroundStyle(.orange)
            }
            Button("Review and log", action: onReview).buttonStyle(.borderedProminent)
            Button("Retake", action: onRetry)
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
