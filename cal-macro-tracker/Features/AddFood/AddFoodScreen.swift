import SwiftData
import SwiftUI

struct AddFoodScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var recentLogEntries: [LogEntry]

    let loggingDay: CalendarDay?

    @AppStorage(AppStorageKeys.isFoodSuggestionsEnabled) private var isFoodSuggestionsEnabled = true
    @State private var selectedMode: AddFoodMode = .search
    @State private var searchText = ""
    @State var remoteSearch = AddFoodRemoteSearchSession()
    @State var remoteSearchTask: Task<Void, Never>?
    @State private var isScanActionBarCompact = false
    @State private var searchScrollTracking = AddFoodSearchScrollTracking()
    @State private var isFoodCameraPresented = false
    @Namespace private var cameraTransition
    private let cameraTransitionSourceID = "search-camera"

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
                            suggestions: foodSuggestions,
                            remoteSearch: remoteSearch.viewState,
                            isRemoteSearchAvailable: isRemoteSearchAvailable,
                            searchText: trimmedSearchText,
                            onFoodLogged: closeSheet,
                            onSearchOnline: searchOnline,
                            onSearchUSDA: searchUSDA,
                            onLoadMoreRemoteResults: loadMoreRemoteResults,
                            onScrollOffsetChange: updateScanActionBarDisplay
                        )
                        .searchable(
                            text: $searchText,
                            placement: .appNavigationDrawer,
                            prompt: "Search foods on device or online"
                        )
                        .onSubmit(of: .search, searchOnline)
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
            remoteSearch.isLoading = false
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .fullScreenCover(isPresented: $isFoodCameraPresented) {
            FoodCameraSheet(loggingDay: loggingDay, onFoodLogged: closeSheet)
                .navigationTransition(
                    .zoom(
                        sourceID: cameraTransitionSourceID,
                        in: cameraTransition
                    )
                )
                .presentationBackground(.clear)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            modePicker
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if selectedMode == .search {
                scanActionBar
            }
        }
    }

    private var modePicker: some View {
        Picker("Mode", selection: $selectedMode) {
            Text("Search").tag(AddFoodMode.search)
            Text("Manual").tag(AddFoodMode.manual)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    var trimmedSearchText: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isRemoteSearchAvailable: Bool {
        RemoteFoodSearchConfiguration.isPackagedFoodSearchAvailable
    }

    private var foodSuggestions: [FoodSuggestion] {
        guard selectedMode == .search, trimmedSearchText.isEmpty, isFoodSuggestionsEnabled else { return [] }
        return FoodSuggestionEngine.suggestions(from: recentLogEntries)
    }

    private var scanActionBar: some View {
        BottomPinnedActionBar(
            title: "Camera",
            systemImage: "camera.viewfinder",
            isDisabled: false,
            displayMode: isScanActionBarCompact ? .compactIcon : .expanded,
            topPadding: 0,
            bottomOffset: 6,
            transitionSourceID: cameraTransitionSourceID,
            transitionNamespace: cameraTransition,
            action: {
                isFoodCameraPresented = true
            }
        )
        .accessibilityLabel("Camera")
        .frame(maxWidth: .infinity)
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
