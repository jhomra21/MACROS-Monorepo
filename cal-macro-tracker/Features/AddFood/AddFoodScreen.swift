import SwiftData
import SwiftUI

struct AddFoodScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FoodItem.name) private var foods: [FoodItem]

    let loggingDay: CalendarDay?

    @State private var selectedMode: AddFoodMode = .search
    @State private var searchText = ""
    @State private var remoteSearch = RemoteSearchSession()
    @State private var remoteSearchTask: Task<Void, Never>?
    @State private var isScanActionBarCompact = false
    @State private var scanDestination: ScanDestination?

    private enum ScanDestination: Hashable, Identifiable {
        case barcode
        case label

        var id: Self { self }
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

        var viewState: RemoteSearchViewState {
            RemoteSearchViewState(
                results: results,
                provider: provider,
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
            VStack(alignment: .leading, spacing: 10) {
                Group {
                    switch selectedMode {
                    case .search:
                        SearchFoodListView(
                            loggingDay: loggingDay,
                            foods: rankedFoods,
                            totalFoodsCount: foods.count,
                            hasLoadedFoods: !foods.isEmpty,
                            remoteSearch: remoteSearch.viewState,
                            isRemoteSearchAvailable: isRemoteSearchAvailable,
                            searchText: trimmedSearchText,
                            onFoodLogged: closeSheet,
                            onSearchOnline: searchOnline,
                            onSearchUSDA: searchUSDA,
                            onLoadMoreRemoteResults: loadMoreRemoteResults,
                            onScrollOffsetChange: updateScanActionBarDisplay
                        )
                    case .manual:
                        ManualFoodEntryScreen(loggingDay: loggingDay, onFoodLogged: closeSheet)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
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
            ToolbarItem(placement: .appTopBarLeading) {
                if selectedMode == .search {
                    Button("Manual") {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedMode = .manual
                        }
                    }
                } else {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedMode = .search
                        }
                    } label: {
                        Text("Search")
                    }
                }
            }

            ToolbarItem(placement: .appTopBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .addFoodSearchable(isSearchMode: selectedMode == .search, text: $searchText, onSubmit: searchOnline)
        .navigationDestination(item: $scanDestination) { destination in
            scanScreen(for: destination)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if selectedMode == .search {
                scanActionBar
            }
        }
    }

    private var trimmedSearchText: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isRemoteSearchAvailable: Bool {
        RemoteFoodSearchConfiguration.isPackagedFoodSearchAvailable
    }

    private var rankedFoods: [FoodItem] {
        FoodItemLocalSearch.rankedFoods(foods, matching: trimmedSearchText)
    }

    private var scanActionBar: some View {
        BottomPinnedDualActionBar(
            leadingAction: BottomPinnedDualAction(
                title: "Scan Barcode",
                systemImage: "barcode.viewfinder"
            ) {
                scanDestination = .barcode
            },
            trailingAction: BottomPinnedDualAction(
                title: "Scan Label",
                systemImage: "camera.viewfinder"
            ) {
                scanDestination = .label
            },
            displayMode: isScanActionBarCompact ? .compactIcon : .expanded,
            topPadding: 0,
            bottomOffset: 6
        )
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func scanScreen(for destination: ScanDestination) -> some View {
        switch destination {
        case .barcode:
            BarcodeScanScreen(onFoodLogged: closeSheet, loggingDay: loggingDay, entryMode: .immediateCamera)
        case .label:
            LabelScanScreen(onFoodLogged: closeSheet, loggingDay: loggingDay)
        }
    }

    private func updateScanActionBarDisplay(for offset: CGFloat) {
        let compactThreshold: CGFloat = isScanActionBarCompact ? 2 : 12
        let shouldCompact = offset > compactThreshold
        guard shouldCompact != isScanActionBarCompact else { return }

        withAnimation(.smooth(duration: 0.22)) {
            isScanActionBarCompact = shouldCompact
        }
    }

    private func searchOnline() {
        startRemoteSearch(query: trimmedSearchText, page: 1, append: false, provider: .openFoodFacts)
    }

    private func searchUSDA() {
        startRemoteSearch(query: trimmedSearchText, page: 1, append: false, provider: .usda)
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
                provider: provider,
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
                fallbackOnEmpty: append == false && provider == nil,
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
                remoteSearch.provider = provider
                remoteSearch.hasMore = false
            }
            remoteSearch.isLoading = false
            remoteSearch.errorMessage = error.localizedDescription
            remoteSearchTask = nil
        }
    }
}

private extension View {
    @ViewBuilder
    func addFoodSearchable(
        isSearchMode: Bool,
        text: Binding<String>,
        onSubmit: @escaping () -> Void
    ) -> some View {
        if isSearchMode {
            self
                .searchable(text: text, placement: .appNavigationDrawer, prompt: "Search foods on device or online")
                .onSubmit(of: .search, onSubmit)
        } else {
            self
        }
    }
}
