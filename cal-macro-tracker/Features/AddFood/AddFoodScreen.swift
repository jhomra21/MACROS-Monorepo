import SwiftData
import SwiftUI

struct AddFoodScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FoodItem.name) private var foods: [FoodItem]

    let loggingDay: CalendarDay?

    @State private var selectedMode: AddFoodMode = .search
    @State private var searchText = ""
    @State private var errorMessage: String?
    @State private var remoteSearch = RemoteSearchSession()
    @State private var remoteSearchTask: Task<Void, Never>?

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

        var viewState: RemoteSearchViewState {
            RemoteSearchViewState(
                results: results,
                errorMessage: errorMessage,
                isLoading: isLoading,
                hasState: hasState,
                hasMore: hasMore
            )
        }
    }

    private let remotePageSize = 12
    private let packagedFoodSearchClient = PackagedFoodSearchClient()

    init(initialMode: AddFoodMode = .search, loggingDay: CalendarDay? = nil) {
        self.loggingDay = loggingDay
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
                    AddFoodQuickActions(loggingDay: loggingDay, onFoodLogged: closeSheet)
                        .padding(.horizontal, 20)
                }
                Group {
                    switch selectedMode {
                    case .search:
                        SearchFoodListView(
                            loggingDay: loggingDay,
                            foods: rankedFoods,
                            totalFoodsCount: searchableFoods.count,
                            hasLoadedFoods: !foods.isEmpty,
                            remoteSearch: remoteSearch.viewState,
                            isRemoteSearchAvailable: isRemoteSearchAvailable,
                            searchText: trimmedSearchText,
                            onFoodLogged: closeSheet,
                            onSearchOnline: searchOnline,
                            onLoadMoreRemoteResults: loadMoreRemoteResults
                        )
                    case .manual:
                        ManualFoodEntryScreen(loggingDay: loggingDay, onFoodLogged: closeSheet)
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
            remoteSearchTask = nil
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
    private var isRemoteSearchAvailable: Bool {
        RemoteFoodSearchConfiguration.isPackagedFoodSearchAvailable
    }

    private var rankedFoods: [FoodItem] {
        FoodItemLocalSearch.rankedFoods(searchableFoods, matching: trimmedSearchText)
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
