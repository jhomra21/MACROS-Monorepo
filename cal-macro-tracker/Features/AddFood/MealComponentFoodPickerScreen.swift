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
    @State private var remoteSearch = AddFoodRemoteSearchSession()
    @State private var remoteSearchTask: Task<Void, Never>?
    @State private var selectedRemoteResult: RemoteSearchResult?

    private let remotePageSize = 12
    private let packagedFoodSearchClient = PackagedFoodSearchClient()

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
                    }
                }
            }

            Section("Online Packaged Foods") {
                if remoteSearch.isLoading {
                    HStack {
                        ProgressView()
                        Text("Searching online foods…")
                            .foregroundStyle(.secondary)
                    }
                } else if let errorMessage = remoteSearch.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                } else if remoteSearch.results.isEmpty {
                    Text(onlineEmptyMessage)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(remoteSearch.results) { result in
                        Button {
                            selectedRemoteResult = result
                        } label: {
                            RemoteFoodRow(result: result)
                        }
                        .buttonStyle(.plain)
                    }

                    if remoteSearch.hasMore {
                        Button("Load More") {
                            loadMoreRemoteResults()
                        }
                    }
                }
            }
        }
        .navigationTitle("Add Food")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .appTopBarTrailing) {
                Button {
                    confirmSelectedFoods()
                } label: {
                    PickerConfirmButtonLabel(isEnabled: selectedFoodIDs.isEmpty == false)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .tint(selectedFoodIDs.isEmpty ? .secondary : .accentColor)
                .disabled(selectedFoodIDs.isEmpty)
                .accessibilityLabel("Add selected foods")
            }
        }
        .searchable(text: $searchText, prompt: "Search saved foods")
        .onSubmit(of: .search, searchOnline)
        .task(id: searchText) {
            await updateFoods()
        }
        .onChange(of: searchText) { _, newValue in
            guard remoteSearch.query != newValue.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
            clearRemoteSearch()
        }
        .onDisappear {
            remoteSearchTask?.cancel()
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

    private var onlineEmptyMessage: String {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.count < PackagedFoodSearchClient.minimumQueryLength
            ? "Type at least \(PackagedFoodSearchClient.minimumQueryLength) characters, then press Search to add an online food."
            : "Press Search to find packaged foods online."
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

    private func searchOnline() {
        startRemoteSearch(query: searchText, page: 1, append: false)
    }

    private func loadMoreRemoteResults() {
        guard remoteSearch.isLoading == false, remoteSearch.hasMore else { return }
        startRemoteSearch(query: remoteSearch.query, page: remoteSearch.page + 1, append: true)
    }

    private func clearRemoteSearch() {
        remoteSearchTask?.cancel()
        remoteSearchTask = nil
        remoteSearch = AddFoodRemoteSearchSession()
    }

    private func startRemoteSearch(query: String, page: Int, append: Bool) {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedQuery.count >= PackagedFoodSearchClient.minimumQueryLength else {
            clearRemoteSearch()
            return
        }

        remoteSearchTask?.cancel()
        let requestID = UUID()
        remoteSearch = AddFoodRemoteSearchSession(
            query: normalizedQuery,
            page: append ? remoteSearch.page : 0,
            results: append ? remoteSearch.results : [],
            hasMore: append && remoteSearch.hasMore,
            isLoading: true,
            requestID: requestID
        )

        remoteSearchTask = Task {
            await loadRemoteResults(requestID: requestID, query: normalizedQuery, page: page, append: append)
        }
    }

    @MainActor
    private func loadRemoteResults(requestID: UUID, query: String, page: Int, append: Bool) async {
        do {
            let response = try await packagedFoodSearchClient.searchFoods(
                query: query,
                page: page,
                pageSize: remotePageSize
            )

            guard Task.isCancelled == false, remoteSearch.requestID == requestID else { return }
            remoteSearch.query = response.query
            remoteSearch.page = response.page
            remoteSearch.provider = response.provider
            remoteSearch.results = append ? (remoteSearch.results + response.results) : response.results
            remoteSearch.hasMore = response.hasMore
            remoteSearch.isLoading = false
            remoteSearch.errorMessage = nil
            remoteSearchTask = nil
        } catch {
            guard Task.isCancelled == false, remoteSearch.requestID == requestID else { return }
            remoteSearch.isLoading = false
            remoteSearch.errorMessage = error.localizedDescription
            remoteSearchTask = nil
        }
    }
}

private struct PickerConfirmButtonLabel: View {
    let isEnabled: Bool

    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(.white)
            .opacity(isEnabled ? 1 : 0.55)
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

private func pickerLocalFoodCandidates(in context: ModelContext, query: String) throws -> [FoodItem] {
    let normalizedQuery = FoodItemSearchQuery(query).normalizedText
    let fieldPrefixQuery = " \(normalizedQuery)"
    let tokens = query.lowercased().split(whereSeparator: { $0.isWhitespace }).map(String.init)
    let searchTerm = tokens.first(where: { $0.allSatisfy(\.isNumber) }) ?? tokens.max(by: { $0.count < $1.count }) ?? query

    var candidates: [FoodItem] = []
    var seen = Set<UUID>()

    func append(_ foods: [FoodItem]) {
        for food in foods where seen.insert(food.id).inserted {
            candidates.append(food)
        }
    }

    var prefixDescriptor = FetchDescriptor<FoodItem>(
        predicate: #Predicate { food in
            food.searchableText.starts(with: normalizedQuery)
                || food.searchableText.localizedStandardContains(fieldPrefixQuery)
        },
        sortBy: [SortDescriptor(\.name)]
    )
    prefixDescriptor.fetchLimit = 60
    append(try context.fetch(prefixDescriptor))

    var fallbackDescriptor = FetchDescriptor<FoodItem>(
        predicate: #Predicate { food in
            food.searchableText.localizedStandardContains(searchTerm)
        },
        sortBy: [SortDescriptor(\.name)]
    )
    fallbackDescriptor.fetchLimit = 250
    append(try context.fetch(fallbackDescriptor))

    return Array(FoodItemLocalSearch.rankedFoods(candidates, matching: query).prefix(60))
}
