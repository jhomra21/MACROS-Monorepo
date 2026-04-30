import SwiftData
import SwiftUI
#if os(iOS)
import UIKit
#endif

struct LogFoodScreen: View {
    @Environment(\.modelContext) private var modelContext

    let initialDraft: FoodDraft
    let loggingDay: CalendarDay?
    let reviewNotes: [String]
    let requiredReviewNutrients: [RequiredNutritionReviewNutrient]
    let previewImageData: Data?
    let onFoodLogged: () -> Void

    @State private var draft: FoodDraft
    @State private var quantityMode: QuantityMode
    @State private var servingsAmount: Double
    @State private var gramsAmount: Double
    @State private var numericText: FoodDraftNumericText
    @State private var errorMessage: String?
    @State private var logFeedbackToken = 0
    @State private var confirmedZeroRequiredNutrients = Set<RequiredNutritionReviewNutrient>()
    #if os(iOS)
    @State private var showingPreviewImage = false
    #endif
    @FocusState private var focusedField: FoodDraftField?

    init(
        initialDraft: FoodDraft,
        loggingDay: CalendarDay? = nil,
        initialQuantityMode: QuantityMode = .servings,
        initialQuantityAmount: Double? = nil,
        reviewNotes: [String] = [],
        requiredReviewNutrients: [RequiredNutritionReviewNutrient] = [],
        previewImageData: Data? = nil,
        onFoodLogged: @escaping () -> Void = {}
    ) {
        self.initialDraft = initialDraft
        self.loggingDay = loggingDay
        self.reviewNotes = reviewNotes
        self.requiredReviewNutrients = requiredReviewNutrients
        self.previewImageData = previewImageData
        self.onFoodLogged = onFoodLogged
        _draft = State(initialValue: initialDraft)
        _quantityMode = State(initialValue: initialQuantityMode)
        _servingsAmount = State(initialValue: initialQuantityMode == .servings ? (initialQuantityAmount ?? 1) : 1)
        _gramsAmount = State(
            initialValue: initialQuantityMode == .grams
                ? (initialQuantityAmount ?? initialDraft.gramsPerServing ?? 100) : (initialDraft.gramsPerServing ?? 100))
        _numericText = State(initialValue: FoodDraftNumericText(draft: initialDraft))
    }

    private var activeAmount: Double {
        quantityMode == .servings ? servingsAmount : gramsAmount
    }

    private var reviewDraft: FoodDraft {
        numericText.editingDraft(from: draft)
    }

    private var previewDraft: FoodDraft {
        numericText.finalizedDraft(from: draft) ?? draft
    }

    private var nutritionPresentation: FoodDraftNutritionPresentation? {
        guard
            let multiplier = NutritionMath.quantityMultiplier(
                mode: quantityMode,
                amount: activeAmount,
                gramsPerServing: previewDraft.gramsPerServing
            )
        else {
            return nil
        }

        return FoodDraftNutritionPresentation(title: "Nutrition", multiplier: multiplier)
    }

    private var reusableFoodPersistenceMode: ReusableFoodPersistenceMode {
        FoodDraft.reusableFoodPersistenceMode(initialDraft: initialDraft, currentDraft: draft)
    }

    private var canSave: Bool {
        guard let finalizedDraft = numericText.finalizedDraft(from: draft) else { return false }
        return finalizedDraft.canLog(quantityMode: quantityMode, quantityAmount: activeAmount)
            && unresolvedRequiredReviewNutrients.isEmpty
    }

    private var hasPreviewImage: Bool {
        previewImageData != nil
    }

    private var reviewSectionTitle: String {
        switch initialDraft.source {
        case .labelScan:
            return "Label Scan"
        case .searchLookup:
            return "Online Packaged Food"
        case .common, .custom, .barcodeLookup:
            return "Review"
        }
    }

    private var sourceURL: URL? {
        guard let sourceURL = draft.sourceURLOrNil else { return nil }
        return URL(string: sourceURL)
    }

    private var combinedReviewNotes: [String] {
        let labelScanNote: [String]
        if requiredReviewNutrients.isEmpty {
            labelScanNote = []
        } else {
            labelScanNote = [NutritionLabelParser.reviewRequiredNutrientsMessage(requiredReviewNutrients)]
        }

        return labelScanNote + reviewNotes
    }

    private var unresolvedRequiredReviewNutrients: [RequiredNutritionReviewNutrient] {
        reviewDraft.missingLabelScanRequiredNutrients(
            from: requiredReviewNutrients,
            confirmedZeroNutrients: confirmedZeroRequiredNutrients
        )
    }

    private var shouldShowRequiredReviewSection: Bool {
        requiredReviewNutrients.isEmpty == false
    }

    var body: some View {
        FoodDraftEditorForm(
            draft: $draft,
            numericText: $numericText,
            errorMessage: $errorMessage,
            configuration: FoodDraftEditorConfiguration(
                brandPrompt: "Brand (optional)",
                gramsPrompt: "Grams per serving (optional)",
                nutritionPresentation: nutritionPresentation
            ),
            focusedField: $focusedField
        ) {
            FoodDraftSourceSection(
                title: reviewSectionTitle,
                notes: combinedReviewNotes,
                sourceName: draft.sourceNameOrNil,
                sourceURL: sourceURL,
                previewActionTitle: hasPreviewImage ? "Preview Captured Image" : nil,
                onPreview: hasPreviewImage
                    ? {
                        #if os(iOS)
                        showingPreviewImage = true
                        #endif
                    }
                    : nil
            )

            if shouldShowRequiredReviewSection {
                Section("Required Review") {
                    Text(
                        "Missing OCR values must be updated to a value greater than 0, "
                            + "or explicitly confirmed as intentional 0 values before logging."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                    ForEach(requiredReviewNutrients, id: \.self) { nutrient in
                        if reviewDraft.isRequiredNutrientPositive(nutrient) == false {
                            Toggle(
                                "\(nutrient.displayName) is intentionally 0",
                                isOn: confirmationBinding(for: nutrient)
                            )
                        } else {
                            Label(
                                "\(nutrient.displayName) reviewed",
                                systemImage: "checkmark.circle.fill"
                            )
                            .foregroundStyle(.green)
                        }
                    }
                }
            }

            FoodQuantitySection(
                quantityMode: $quantityMode,
                servingsAmount: $servingsAmount,
                gramsAmount: $gramsAmount,
                canLogByGrams: previewDraft.canLogByGrams,
                gramsPerServing: previewDraft.gramsPerServing,
                gramLoggingMessage: "Add grams per serving to enable gram-based logging."
            )
        } footerSections: {
            Section {
                Toggle("Save as reusable food", isOn: $draft.saveAsCustomFood)
                switch reusableFoodPersistenceMode {
                case .autoCreateFromCommonEdits:
                    Text("Because you changed a common food, a reusable copy will be saved automatically.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                case .autoUpdateExistingExternalFood:
                    Text("Because you changed a saved external food, the reusable local copy will be updated automatically.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                case .none, .userRequested:
                    EmptyView()
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            BottomPinnedActionBar(title: "Log Food", systemImage: nil, isDisabled: !canSave) {
                saveEntry()
            }
        }
        .sensoryFeedback(.success, trigger: logFeedbackToken)
        .navigationTitle("Log Food")
        .inlineNavigationTitle()
        .onChange(of: numericText) { _, _ in
            pruneResolvedZeroConfirmations()
        }
        #if os(iOS)
        .sheet(isPresented: $showingPreviewImage) {
            if let previewImageData, let previewImage = UIImage(data: previewImageData) {
                NavigationStack {
                    ScrollView {
                        Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .background(Color.black.opacity(0.95))
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                showingPreviewImage = false
                            }
                        }
                    }
                }
            }
        }
        #endif
    }

    private var logEntryRepository: LogEntryRepository {
        LogEntryRepository(modelContext: modelContext)
    }

    private func saveEntry() {
        guard let finalizedDraft = numericText.finalizedDraft(from: draft) else {
            errorMessage = "Please fix invalid numeric values before logging food."
            return
        }

        dismissKeyboard($focusedField)
        persistEntry(finalizedDraft)
    }

    private func persistEntry(_ finalizedDraft: FoodDraft) {
        do {
            try logEntryRepository.logFood(
                draft: finalizedDraft,
                reusableFoodPersistenceMode: reusableFoodPersistenceMode,
                loggedAt: loggingDay?.date(matchingTimeOf: .now) ?? .now,
                quantityMode: quantityMode,
                quantityAmount: activeAmount,
                operation: "Log food"
            )
            errorMessage = nil
            logFeedbackToken += 1
            onFoodLogged()
        } catch {
            errorMessage = error.localizedDescription
            assertionFailure(error.localizedDescription)
        }
    }

    private func confirmationBinding(for nutrient: RequiredNutritionReviewNutrient) -> Binding<Bool> {
        Binding(
            get: { confirmedZeroRequiredNutrients.contains(nutrient) },
            set: { isConfirmed in
                if isConfirmed {
                    confirmedZeroRequiredNutrients.insert(nutrient)
                } else {
                    confirmedZeroRequiredNutrients.remove(nutrient)
                }
            }
        )
    }

    private func pruneResolvedZeroConfirmations() {
        confirmedZeroRequiredNutrients = Set(
            confirmedZeroRequiredNutrients.filter {
                reviewDraft.isRequiredNutrientPositive($0) == false
            })
    }
}
