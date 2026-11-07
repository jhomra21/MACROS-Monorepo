import SwiftData
import SwiftUI

struct MealComponentFoodPickerScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let excludedFoodIDs: Set<UUID>
    let onSelect: (MealComponentDraft) -> Void

    @State private var searchText = ""
    @State private var foods: [LocalFoodSearchResult] = []
    @State private var selectedFoodIDs = Set<UUID>()
    @State private var isSearching = false
    @State private var remoteSearch = FoodSearchSession()
    @State private var selectedRemoteResult: RemoteSearchResult?

    var body: some View {
        List {
            Section("On Device") {
                if isSearching {
                    HStack {
                        ProgressView()
                        Text("Searching on-device foods…")
                            .foregroundStyle(.secondary)
                    }
                } else if foods.isEmpty {
                    Text(emptyMessage)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(foods) { food in
                        Button {
                            toggleFoodSelection(id: food.id)
                        } label: {
                            HStack(spacing: 12) {
                                LocalFoodSearchResultRow(result: food)

                                Spacer(minLength: 8)

                                if selectedFoodIDs.contains(food.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.blue)
                                        .accessibilityLabel("Selected")
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .savedFoodDeleteSwipeAction(foodID: food.savedFoodID)
                    }
                }
            }

            FoodSearchResultsSection(
                session: remoteSearch,
                query: searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            ) { result in
                selectedRemoteResult = result
            }
        }
        .savedFoodDeletion { id in
            foods.removeAll { $0.id == id }
            selectedFoodIDs.remove(id)
        }
        .navigationTitle("Choose Foods")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Add", systemImage: "checkmark") {
                    confirmSelectedFoods()
                }
                .disabled(selectedFoodIDs.isEmpty)
            }
        }
        .searchable(text: $searchText, prompt: "Search foods")
        .onSubmit(of: .search) {
            remoteSearch.submit(query: searchText)
        }
        .task(id: searchText) {
            await updateFoods()
        }
        .task(id: FoodSearchRequest(query: searchText, revision: remoteSearch.revision)) {
            await remoteSearch.load(query: searchText)
        }
        .navigationDestination(item: $selectedRemoteResult) { result in
            MealComponentRemoteSelectionScreen(result: result) { component in
                onSelect(component)
                dismiss()
            }
        }
    }

    private var emptyMessage: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "No saved foods available on device yet."
            : "No saved foods match this search."
    }

    private func updateFoods() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        isSearching = true

        let task = Task<[LocalFoodSearchResult], Never>(priority: .userInitiated) { @MainActor in
            do {
                let candidates: [FoodItem]
                if query.isEmpty {
                    candidates = try pickerRecentLocalFoods(in: modelContext)
                } else {
                    candidates = try pickerLocalFoodCandidates(in: modelContext, query: query)
                }

                return
                    candidates
                    .filter { excludedFoodIDs.contains($0.id) == false }
                    .map(LocalFoodSearchResult.init)
            } catch {
                return []
            }
        }

        let results = await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }

        guard Task.isCancelled == false else { return }
        foods = results
        isSearching = false
    }

    private func toggleFoodSelection(id: UUID) {
        if selectedFoodIDs.contains(id) {
            selectedFoodIDs.remove(id)
        } else {
            selectedFoodIDs.insert(id)
        }
    }

    private func confirmSelectedFoods() {
        for food in selectedFoods() {
            onSelect(MealComponentDraft(food: food))
        }
        dismiss()
    }

    private func selectedFoods() -> [FoodItem] {
        let ids = selectedFoodIDs
        guard ids.isEmpty == false else { return [] }

        let descriptor = FetchDescriptor<FoodItem>(
            predicate: #Predicate { food in
                ids.contains(food.id)
            },
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

}

private func pickerRecentLocalFoods(in context: ModelContext) throws -> [FoodItem] {
    var descriptor = FetchDescriptor<FoodItem>(
        sortBy: [
            SortDescriptor(\.updatedAt, order: .reverse),
            SortDescriptor(\.name)
        ]
    )
    descriptor.fetchLimit = 60
    return try context.fetch(descriptor)
}

func pickerLocalFoodCandidates(in context: ModelContext, query: String) throws -> [FoodItem] {
    Array(
        FoodItemLocalSearch.rankedFoods(
            try FoodItemLocalSearch.fetchedCandidates(in: context, matching: query),
            matching: query,
            priorities: CommonFoodSeedLoader.staplePriorities
        ).prefix(60)
    )
}
