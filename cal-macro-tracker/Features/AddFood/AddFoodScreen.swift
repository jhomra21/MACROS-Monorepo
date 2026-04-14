import SwiftData
import SwiftUI

struct AddFoodScreen: View {
    @Environment(\.dismiss) private var dismiss

    let foods: [FoodItem]

    @State private var selectedMode: AddFoodMode = .search
    @State private var searchText = ""
    @State private var errorMessage: String?
    @State private var remoteSearch = RemoteSearchSession()
    @State private var remoteSearchTask: Task<Void, Never>?

    private struct SearchMatch {
        let food: FoodItem
        let rank: Int
    }

    private struct RemoteSearchSession {
        var query = ""
        var page = 0
        var provider: RemoteSearchProvider?
        var results: [RemoteSearchResult] = []
        var hasMore = false
        var isLoading = false
        var errorMessage: String?
        var requestID = UUID()

        var hasState: Bool {
            query.isEmpty == false || errorMessage != nil || isLoading
        }
    }

    private let remotePageSize = 12
    private let packagedFoodSearchClient = PackagedFoodSearchClient()

    init(foods: [FoodItem], initialMode: AddFoodMode = .search) {
        self.foods = foods
        _selectedMode = State(initialValue: initialMode)
    }

    private func closeSheet() { dismiss() }

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
                    AddFoodQuickActions(onFoodLogged: closeSheet)
                        .padding(.horizontal, 20)
                }
                Group {
                    switch selectedMode {
                    case .search:
                        SearchFoodListView(
                            foods: rankedFoods,
                            totalFoodsCount: searchableFoods.count,
                            hasLoadedFoods: !foods.isEmpty,
                            remoteResults: remoteSearch.results,
                            remoteErrorMessage: remoteSearch.errorMessage,
                            isLoadingRemoteResults: remoteSearch.isLoading,
                            hasRemoteSearchState: remoteSearch.hasState,
                            hasMoreRemoteResults: remoteSearch.hasMore,
                            isRemoteSearchAvailable: isRemoteSearchAvailable,
                            searchText: trimmedSearchText,
                            onFoodLogged: closeSheet,
                            onSearchOnline: searchOnline,
                            onLoadMoreRemoteResults: loadMoreRemoteResults
                        )
                    case .manual:
                        ManualFoodEntryScreen(onFoodLogged: closeSheet)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(.top, 16)
        }
        .navigationTitle("Add Food")
        .inlineNavigationTitle()
        .onChange(of: trimmedSearchText) { oldValue, newValue in
            guard oldValue != newValue, remoteSearch.query != newValue else { return }
            clearRemoteSearch()
        }
        .onDisappear {
            remoteSearchTask?.cancel()
        }
        .toolbar {
            ToolbarItem(placement: .appTopBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .searchable(text: $searchText, placement: .appNavigationDrawer, prompt: "Search foods on device or online")
        .onSubmit(of: .search) { searchOnline() }
        .errorBanner(message: $errorMessage)
    }

    private var searchableFoods: [FoodItem] {
        foods.filter {
            switch $0.sourceKind {
            case .common, .custom, .barcodeLookup, .labelScan, .searchLookup: true
            }
        }
    }

    private var trimmedSearchText: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var normalizedSearchText: String { trimmedSearchText.lowercased() }
    private var isRemoteSearchAvailable: Bool {
        RemoteFoodSearchConfiguration.isPackagedFoodSearchAvailable
    }

    private var rankedFoods: [FoodItem] {
        let query = normalizedSearchText
        guard query.isEmpty == false else { return searchableFoods }
        let queryTokens = Set(query.split(whereSeparator: { $0.isWhitespace }).map(String.init))
        let matches: [SearchMatch] = searchableFoods.reduce(into: []) { partialResult, food in
            guard let rank = localSearchRank(for: food, query: query, queryTokens: queryTokens) else { return }
            partialResult.append(SearchMatch(food: food, rank: rank))
        }
        return
            matches
            .sorted { lhs, rhs in
                if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
                return lhs.food.name.localizedCaseInsensitiveCompare(rhs.food.name) == .orderedAscending
            }
            .map(\.food)
    }

    private func localSearchRank(for food: FoodItem, query: String, queryTokens: Set<String>) -> Int? {
        let name = food.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let brand = food.brand?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if name == query || (brand.isEmpty == false && brand == query) { return 0 }
        if name.hasPrefix(query) || (brand.isEmpty == false && brand.hasPrefix(query)) { return 1 }
        guard food.searchableText.contains(query) else { return nil }
        guard queryTokens.isEmpty == false else { return 2 }
        let searchableTokens = Set(food.searchableText.split(whereSeparator: { $0.isWhitespace }).map(String.init))
        return queryTokens.isSubset(of: searchableTokens) ? 2 : 3
    }

    private func searchOnline() {
        startRemoteSearch(query: trimmedSearchText, page: 1, append: false, provider: nil)
    }

    private func loadMoreRemoteResults() {
        guard remoteSearch.isLoading == false,
            remoteSearch.hasMore,
            let provider = remoteSearch.provider
        else { return }
        startRemoteSearch(query: remoteSearch.query, page: remoteSearch.page + 1, append: true, provider: provider)
    }

    private func startRemoteSearch(query: String, page: Int, append: Bool, provider: RemoteSearchProvider?) {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedQuery.count >= PackagedFoodSearchClient.minimumQueryLength else {
            clearRemoteSearch()
            return
        }

        remoteSearchTask?.cancel()
        let requestID = UUID()

        if append {
            remoteSearch.isLoading = true
            remoteSearch.errorMessage = nil
            remoteSearch.requestID = requestID
        } else {
            remoteSearch = RemoteSearchSession(
                query: normalizedQuery,
                page: 0,
                provider: nil,
                results: [],
                hasMore: false,
                isLoading: true,
                errorMessage: nil,
                requestID: requestID
            )
        }

        remoteSearchTask = Task {
            await loadRemoteResults(
                requestID: requestID,
                query: normalizedQuery,
                page: page,
                append: append,
                provider: provider
            )
        }
    }

    private func clearRemoteSearch() {
        remoteSearchTask?.cancel()
        remoteSearchTask = nil
        remoteSearch = RemoteSearchSession()
    }

    @MainActor
    private func loadRemoteResults(
        requestID: UUID,
        query: String,
        page: Int,
        append: Bool,
        provider: RemoteSearchProvider?
    ) async {
        do {
            let response = try await packagedFoodSearchClient.searchFoods(
                query: query,
                page: page,
                pageSize: remotePageSize,
                fallbackOnEmpty: append == false,
                provider: provider
            )

            guard Task.isCancelled == false,
                remoteSearch.requestID == requestID,
                remoteSearch.query == query
            else { return }

            if append,
                (remoteSearch.provider != provider || response.provider != provider || response.page != page)
            {
                remoteSearch.errorMessage = PackagedFoodSearchClientError.invalidResponse.localizedDescription
                remoteSearch.isLoading = false
                remoteSearchTask = nil
                return
            }

            remoteSearch.query = response.query
            remoteSearch.page = response.page
            remoteSearch.provider = response.provider
            remoteSearch.results = append ? (remoteSearch.results + response.results) : response.results
            remoteSearch.hasMore = response.hasMore
            remoteSearch.isLoading = false
            remoteSearch.errorMessage = nil
            remoteSearchTask = nil
        } catch {
            guard Task.isCancelled == false,
                remoteSearch.requestID == requestID,
                remoteSearch.query == query
            else { return }

            if append == false {
                remoteSearch.results = []
                remoteSearch.page = 0
                remoteSearch.provider = nil
                remoteSearch.hasMore = false
            }
            remoteSearch.isLoading = false
            remoteSearch.errorMessage = error.localizedDescription
            remoteSearchTask = nil
        }
    }
}
