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
    let previewImageData: Data?
    let onFoodLogged: () -> Void

    @State private var draft: FoodDraft
    @State private var quantityMode: QuantityMode
    @State private var servingsAmount: Double
    @State private var gramsAmount: Double
    @State private var numericText: FoodDraftNumericText
    @State private var errorMessage: String?
    @State private var logFeedbackToken = 0
    #if os(iOS)
    @State private var showingPreviewImage = false
    #endif
    @FocusState private var focusedField: FoodDraftField?

    init(
        initialDraft: FoodDraft,
        loggingDay: CalendarDay? = nil,
        reviewNotes: [String] = [],
        previewImageData: Data? = nil,
        onFoodLogged: @escaping () -> Void = {}
    ) {
        self.initialDraft = initialDraft
        self.loggingDay = loggingDay
        self.reviewNotes = reviewNotes
        self.previewImageData = previewImageData
        self.onFoodLogged = onFoodLogged
        _draft = State(initialValue: initialDraft)
        _quantityMode = State(initialValue: .servings)
        _servingsAmount = State(initialValue: 1)
        _gramsAmount = State(initialValue: initialDraft.gramsPerServing ?? 100)
        _numericText = State(initialValue: FoodDraftNumericText(draft: initialDraft))
    }

    private var activeAmount: Double {
        quantityMode == .servings ? servingsAmount : gramsAmount
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
    }

    private var hasPreviewImage: Bool {
        previewImageData != nil
    }

    private var shouldShowReviewSection: Bool {
        reviewNotes.isEmpty == false || hasPreviewImage || draft.sourceNameOrNil != nil || sourceURL != nil
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

    var body: some View {
        FoodDraftEditorForm(
            draft: $draft,
            numericText: $numericText,
            errorMessage: $errorMessage,
            brandPrompt: "Brand (optional)",
            gramsPrompt: "Grams per serving (optional)",
            nutritionPresentation: nutritionPresentation,
            focusedField: $focusedField,
            trailingKeyboardFields: []
        ) {
            if shouldShowReviewSection {
                Section(reviewSectionTitle) {
                    ForEach(reviewNotes, id: \.self) { note in
                        Text(note)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let sourceName = draft.sourceNameOrNil {
                        LabeledContent("Source") {
                            Text(sourceName)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let sourceURL {
                        Link(destination: sourceURL) {
                            Label("View Source", systemImage: "link")
                        }
                    }

                    if hasPreviewImage {
                        Button("Preview Captured Image") {
                            #if os(iOS)
                            showingPreviewImage = true
                            #endif
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

        dismissEditing()

        DispatchQueue.main.async {
            persistEntry(finalizedDraft)
        }
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

            DispatchQueue.main.async {
                onFoodLogged()
            }
        } catch {
            errorMessage = error.localizedDescription
            assertionFailure(error.localizedDescription)
        }
    }

    private func dismissEditing() {
        focusedField = nil
        #if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}
