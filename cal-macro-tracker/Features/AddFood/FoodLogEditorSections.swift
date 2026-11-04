import SwiftUI
#if os(iOS)
import UIKit
#endif

struct FoodLogEditorSections: View {
    @Binding var editor: FoodLogEditorState
    let focusedField: FocusState<FoodDraftField?>.Binding
    var rowBackground: Color? = nil
    var leadingSections: AnyView? = nil
    var showsQuantity = true
    var scrollsToFocusedField = false
    var showsSourceAttribution = true
    #if os(iOS)
    @State private var showingPreviewImage = false
    #endif

    var body: some View {
        FoodDraftEditorForm(
            draft: $editor.draft,
            numericText: $editor.numericText,
            errorMessage: $editor.errorMessage,
            configuration: FoodDraftEditorConfiguration(
                brandPrompt: "Brand (optional)",
                gramsPrompt: "Grams per serving (optional)",
                nutritionPresentation: editor.nutritionPresentation
            ),
            focusedField: focusedField,
            rowBackground: rowBackground,
            leadingSections: leadingSections,
            scrollsToFocusedField: scrollsToFocusedField
        ) {
            FoodDraftSourceSection(
                title: editor.reviewSectionTitle,
                notes: editor.combinedReviewNotes,
                sourceName: showsSourceAttribution && editor.draft.source != .searchLookup ? editor.draft.sourceNameOrNil : nil,
                sourceURL: showsSourceAttribution && editor.draft.source != .searchLookup ? editor.sourceURL : nil,
                previewActionTitle: editor.hasPreviewImage ? "Preview Captured Image" : nil,
                onPreview: editor.hasPreviewImage
                    ? {
                        #if os(iOS)
                        showingPreviewImage = true
                        #endif
                    }
                    : nil
            )

            if editor.shouldShowRequiredReviewSection {
                Section("Required Review") {
                    Text("Some values couldn’t be read from the label. Enter them, or confirm they’re 0.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    ForEach(editor.requiredReviewNutrients, id: \.self) { nutrient in
                        if editor.reviewDraft.isRequiredNutrientPositive(nutrient) == false {
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

            if showsQuantity {
                FoodQuantitySection(
                    quantityMode: $editor.quantityMode,
                    servingsAmount: $editor.servingsAmount,
                    gramsAmount: $editor.gramsAmount,
                    canLogByGrams: editor.previewDraft.canLogByGrams,
                    gramsPerServing: editor.previewDraft.gramsPerServing,
                    gramLoggingMessage: "Add grams per serving to enable gram-based logging."
                )
            }
        } footerSections: {
            Section {
                Toggle("Save as reusable food", isOn: $editor.draft.saveAsCustomFood)
                switch editor.reusableFoodPersistenceMode {
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
        .onChange(of: editor.numericText) { _, _ in
            editor.pruneResolvedZeroConfirmations()
        }
        #if os(iOS)
        .sheet(isPresented: $showingPreviewImage) {
            if let previewImageData = editor.previewImageData, let previewImage = UIImage(data: previewImageData) {
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
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showingPreviewImage = false
                            }
                        }
                    }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        #endif
    }

    private func confirmationBinding(for nutrient: RequiredNutritionReviewNutrient) -> Binding<Bool> {
        Binding(
            get: { editor.confirmedZeroRequiredNutrients.contains(nutrient) },
            set: { isConfirmed in
                if isConfirmed {
                    editor.confirmedZeroRequiredNutrients.insert(nutrient)
                } else {
                    editor.confirmedZeroRequiredNutrients.remove(nutrient)
                }
            }
        )
    }

}
