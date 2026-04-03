import SwiftData
import SwiftUI

struct AddFoodScreen: View {
    @Environment(\.dismiss) private var dismiss

    let logDate: Date
    let foods: [FoodItem]

    @State private var selectedMode: AddFoodMode = .search
    @State private var searchText = ""
    @State private var errorMessage: String?

    init(logDate: Date, foods: [FoodItem]) {
        self.logDate = logDate
        self.foods = foods
    }

    private func closeSheet() {
        dismiss()
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Add Food", selection: $selectedMode) {
                ForEach(AddFoodMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.top, 12)

            VStack(alignment: .leading, spacing: 10) {
                if selectedMode == .search {
                    Text("\(foods.count) foods loaded from dashboard")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                }

                Group {
                    switch selectedMode {
                    case .search:
                        SearchFoodListView(logDate: logDate, foods: filteredFoods, hasLoadedFoods: !foods.isEmpty, onFoodLogged: closeSheet)
                    case .manual:
                        ManualFoodEntryScreen(logDate: logDate, onFoodLogged: closeSheet)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(.top, 16)
        }
        .navigationTitle("Add Food")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .appTopBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .searchable(text: $searchText, placement: .appNavigationDrawer, prompt: "Search common foods")
        .errorBanner(message: $errorMessage)
    }

    private var filteredFoods: [FoodItem] {
        let commonFoods = foods.filter { $0.sourceKind == .common || $0.sourceKind == .custom }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return commonFoods }
        return commonFoods.filter { $0.searchableText.contains(query) }
    }
}

private enum AddFoodMode: String, CaseIterable, Identifiable {
    case search
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .search: "Search"
        case .manual: "Manual"
        }
    }
}

private struct SearchFoodListView: View {
    let logDate: Date
    let foods: [FoodItem]
    let hasLoadedFoods: Bool
    let onFoodLogged: () -> Void

    var body: some View {
        if foods.isEmpty {
            ContentUnavailableView(
                hasLoadedFoods ? "No foods found" : "No foods loaded",
                systemImage: "magnifyingglass",
                description: Text(hasLoadedFoods ? "Try a broader search or use manual entry." : "Foods are not available yet. You can still log something with manual entry.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 80)
        } else {
            List(foods) { food in
                NavigationLink {
                    LogFoodScreen(
                        logDate: logDate,
                        initialDraft: FoodDraft(foodItem: food, saveAsCustomFood: false),
                        onFoodLogged: onFoodLogged
                    )
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(food.name)
                            .font(.headline)
                        Text("\(food.caloriesPerServing.roundedForDisplay) kcal • \(food.servingDescription)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
            .listStyle(.plain)
        }
    }
}

private struct ManualFoodEntryScreen: View {
    let logDate: Date
    let onFoodLogged: () -> Void

    @State private var draft = FoodDraft()
    @State private var numericText = FoodDraftNumericText(draft: FoodDraft())
    @FocusState private var focusedField: FoodDraftField?

    var body: some View {
        Form {
            FoodDraftFormSections(
                draft: $draft,
                numericText: $numericText,
                brandPrompt: "Brand (optional)",
                gramsPrompt: "Grams per serving (optional)",
                focusedField: $focusedField
            )

            Section {
                NavigationLink {
                    LogFoodScreen(logDate: logDate, initialDraft: numericText.finalizedDraft(from: draft) ?? draft, onFoodLogged: onFoodLogged)
                } label: {
                    Text("Continue")
                }
                .disabled(!canContinue)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .keyboardNavigationToolbar(focusedField: $focusedField, fields: FoodDraftField.formOrder)
    }

    private var canContinue: Bool {
        guard let finalizedDraft = numericText.finalizedDraft(from: draft) else { return false }
        return finalizedDraft.canSaveReusableFood
    }
}
