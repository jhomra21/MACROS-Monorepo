import Foundation

@MainActor
struct FoodLogEditorState {
    let initialDraft: FoodDraft
    let reviewNotes: [String]
    let requiredReviewNutrients: [RequiredNutritionReviewNutrient]
    let previewImageData: Data?
    var draft: FoodDraft
    var quantityMode: QuantityMode
    var servingsAmount: Double
    var gramsAmount: Double
    var numericText: FoodDraftNumericText
    var errorMessage: String?
    var confirmedZeroRequiredNutrients = Set<RequiredNutritionReviewNutrient>()

    init(
        initialDraft: FoodDraft,
        initialQuantityMode: QuantityMode = .servings,
        initialQuantityAmount: Double? = nil,
        reviewNotes: [String] = [],
        requiredReviewNutrients: [RequiredNutritionReviewNutrient] = [],
        previewImageData: Data? = nil
    ) {
        self.initialDraft = initialDraft
        self.reviewNotes = reviewNotes
        self.requiredReviewNutrients = requiredReviewNutrients
        self.previewImageData = previewImageData
        draft = initialDraft
        quantityMode = initialQuantityMode
        servingsAmount = initialQuantityMode == .servings ? (initialQuantityAmount ?? 1) : 1
        gramsAmount =
            initialQuantityMode == .grams
            ? (initialQuantityAmount ?? initialDraft.gramsPerServing ?? 100) : (initialDraft.gramsPerServing ?? 100)
        numericText = FoodDraftNumericText(draft: initialDraft)
    }

    var activeAmount: Double {
        quantityMode == .servings ? servingsAmount : gramsAmount
    }

    var reviewDraft: FoodDraft {
        numericText.editingDraft(from: draft)
    }

    var previewDraft: FoodDraft {
        numericText.finalizedDraft(from: draft) ?? draft
    }

    var loggingAction: FoodDraftLoggingAction? {
        numericText.finalizedDraft(from: draft)?.loggingAction(
            initialDraft: initialDraft,
            quantityMode: quantityMode,
            quantityAmount: activeAmount
        )
    }

    var previewLoggingAction: FoodDraftLoggingAction {
        previewDraft.loggingAction(
            initialDraft: initialDraft,
            quantityMode: quantityMode,
            quantityAmount: activeAmount
        )
    }

    var nutritionPresentation: FoodDraftNutritionPresentation? {
        guard let multiplier = previewLoggingAction.quantityMultiplier else { return nil }

        return FoodDraftNutritionPresentation(title: "Nutrition", multiplier: multiplier)
    }

    var reusableFoodPersistenceMode: ReusableFoodPersistenceMode {
        loggingAction?.reusableFoodPersistenceMode
            ?? FoodDraft.reusableFoodPersistenceMode(initialDraft: initialDraft, currentDraft: draft)
    }

    var canSave: Bool {
        guard let loggingAction else { return false }
        return loggingAction.canLog
            && unresolvedRequiredReviewNutrients.isEmpty
    }

    var hasPreviewImage: Bool {
        previewImageData != nil
    }

    var reviewSectionTitle: String {
        switch initialDraft.source {
        case .labelScan:
            return "Label Scan"
        case .searchLookup:
            return "Online Packaged Food"
        case .common, .custom, .barcodeLookup:
            return "Review"
        }
    }

    var sourceURL: URL? {
        guard let sourceURL = draft.sourceURLOrNil else { return nil }
        return URL(string: sourceURL)
    }

    var combinedReviewNotes: [String] {
        let labelScanNote: [String]
        if requiredReviewNutrients.isEmpty {
            labelScanNote = []
        } else {
            labelScanNote = [NutritionLabelParser.reviewRequiredNutrientsMessage(requiredReviewNutrients)]
        }

        return labelScanNote + reviewNotes
    }

    var unresolvedRequiredReviewNutrients: [RequiredNutritionReviewNutrient] {
        reviewDraft.missingLabelScanRequiredNutrients(
            from: requiredReviewNutrients,
            confirmedZeroNutrients: confirmedZeroRequiredNutrients
        )
    }

    var shouldShowRequiredReviewSection: Bool {
        requiredReviewNutrients.isEmpty == false
    }

    mutating func pruneResolvedZeroConfirmations() {
        confirmedZeroRequiredNutrients = Set(
            confirmedZeroRequiredNutrients.filter {
                reviewDraft.isRequiredNutrientPositive($0) == false
            })
    }
}
