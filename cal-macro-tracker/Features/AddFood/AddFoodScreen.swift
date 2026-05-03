import SwiftData
import SwiftUI

struct AddFoodScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FoodItem.name) private var foods: [FoodItem]
    @Query private var recentLogEntries: [LogEntry]

    let loggingDay: CalendarDay?

    @AppStorage(AppStorageKeys.isFoodSuggestionsEnabled) private var isFoodSuggestionsEnabled = true
    @State private var selectedMode: AddFoodMode = .search
    @State private var searchText = ""
    @State var remoteSearch = AddFoodRemoteSearchSession()
    @State var remoteSearchTask: Task<Void, Never>?
    @State private var isScanActionBarCompact = false
    @State private var searchScrollTracking = AddFoodSearchScrollTracking()
    @State private var scanDestination: AddFoodScanDestination?

    let remotePageSize = 12
    let packagedFoodSearchClient = PackagedFoodSearchClient()

    init(initialMode: AddFoodMode = .search, loggingDay: CalendarDay? = nil) {
        self.loggingDay = loggingDay
        _selectedMode = State(initialValue: initialMode)
        _recentLogEntries = Query(Self.suggestionHistoryDescriptor())
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
                            suggestions: foodSuggestions,
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
        .onChange(of: selectedMode) { _, _ in
            resetSearchScrollTracking()
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
        .addFoodSearchable(
            isSearchMode: selectedMode == .search,
            text: $searchText,
            onSubmit: searchOnline
        )
        .navigationDestination(item: $scanDestination) { destination in
            scanScreen(for: destination)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if selectedMode == .search {
                scanActionBar
            }
        }
    }

    var trimmedSearchText: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isRemoteSearchAvailable: Bool {
        RemoteFoodSearchConfiguration.isPackagedFoodSearchAvailable
    }

    private var rankedFoods: [FoodItem] {
        FoodItemLocalSearch.rankedFoods(foods, matching: trimmedSearchText)
    }

    private var foodSuggestions: [FoodSuggestion] {
        guard selectedMode == .search, trimmedSearchText.isEmpty, isFoodSuggestionsEnabled else { return [] }
        return FoodSuggestionEngine.suggestions(from: recentLogEntries)
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
    private func scanScreen(for destination: AddFoodScanDestination) -> some View {
        switch destination {
        case .barcode:
            BarcodeScanScreen(onFoodLogged: closeSheet, loggingDay: loggingDay, entryMode: .immediateCamera)
        case .label:
            LabelScanScreen(onFoodLogged: closeSheet, loggingDay: loggingDay)
        }
    }

    private func updateScanActionBarDisplay(for offset: CGFloat) {
        let compactThreshold: CGFloat = 12
        let expandedThreshold: CGFloat = 2
        let upwardExpansionThreshold: CGFloat = 192
        let isScrollingDown = offset > searchScrollTracking.lastOffset

        if offset > searchScrollTracking.deepestOffset {
            searchScrollTracking.deepestOffset = offset
        }
        searchScrollTracking.lastOffset = offset

        if offset <= expandedThreshold {
            searchScrollTracking.deepestOffset = offset
            setScanActionBarCompact(false)
            return
        }

        if isScrollingDown, offset > compactThreshold {
            setScanActionBarCompact(true)
            return
        }

        if isScanActionBarCompact, searchScrollTracking.deepestOffset - offset >= upwardExpansionThreshold {
            searchScrollTracking.deepestOffset = offset
            setScanActionBarCompact(false)
        }
    }

    private func resetSearchScrollTracking() {
        searchScrollTracking.reset()
        setScanActionBarCompact(false)
    }

    private func setScanActionBarCompact(_ isCompact: Bool) {
        guard isCompact != isScanActionBarCompact else { return }

        withAnimation(.smooth(duration: 0.22)) {
            isScanActionBarCompact = isCompact
        }
    }

    private static func suggestionHistoryDescriptor(now: Date = .now) -> FetchDescriptor<LogEntry> {
        let calendar = Calendar.current
        let end = now
        let start = calendar.date(byAdding: .day, value: -14, to: end) ?? end
        return LogEntryQuery.descriptor(start: start, end: end)
    }

}
