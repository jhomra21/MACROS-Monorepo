import SwiftData
import SwiftUI

enum SearchFoodSpacing {
    static let targetVisualGap: CGFloat = 16
    static let suggestionGlassBleed: CGFloat = 4
    static let suggestionToHeader = targetVisualGap - suggestionGlassBleed
    static let headerLeading: CGFloat = 12
    static let headerRowTop: CGFloat = 8
    static let foodRowHorizontal: CGFloat = 16
    static let pillSpacing: CGFloat = 8
    static let pillHorizontalPadding: CGFloat = 14
    static let pillVerticalPadding: CGFloat = 8
}

struct RemoteSearchViewState {
    let results: [RemoteSearchResult]
    let provider: RemoteSearchProvider?
    let errorMessage: String?
    let isLoading: Bool
    let hasState: Bool
    let hasMore: Bool
}

struct LocalFoodSearchResult: Identifiable {
    let id: UUID
    let name: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double

    nonisolated init(food: FoodItem) {
        id = food.id
        name = food.name
        calories = food.caloriesPerServing
        protein = food.proteinPerServing
        carbs = food.carbsPerServing
        fat = food.fatPerServing
    }
}

struct SearchFoodListView: View {
    @Environment(\.modelContext) private var modelContext

    let loggingDay: CalendarDay?
    let suggestions: [FoodSuggestion]
    let remoteSearch: RemoteSearchViewState
    let isRemoteSearchAvailable: Bool
    let searchText: String
    let onFoodLogged: () -> Void
    let onSearchOnline: () -> Void
    let onSearchUSDA: () -> Void
    let onLoadMoreRemoteResults: () -> Void
    let onScrollOffsetChange: (CGFloat) -> Void

    @State private var localFoods: [LocalFoodSearchResult] = []
    @State private var isLocalSearchLoading = false
    @State private var selectedLocalFoodDraft: FoodDraft?
    @State private var selectedRemoteResult: RemoteSearchResult?

    var body: some View {
        List {
            Section {
                localResultsHeader
                    .environment(\.defaultMinListRowHeight, 0)
                    .listRowInsets(
                        EdgeInsets(
                            top: SearchFoodSpacing.headerRowTop,
                            leading: 0,
                            bottom: 0,
                            trailing: 0
                        )
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                if isLocalSearchLoading {
                    HStack {
                        ProgressView()
                        Text("Searching on-device foods…")
                            .foregroundStyle(.secondary)
                    }
                } else if localFoods.isEmpty {
                    Text(localEmptyMessage)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(localFoods) { result in
                        localFoodLink(for: result)
                            .environment(\.defaultMinListRowHeight, 0)
                            .listRowInsets(foodRowInsets)
                    }
                }
            } footer: {
                Text(localResultsFooter)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }

            Section {
                if searchText.isEmpty {
                    Text("Enter a food name or brand, then submit search to query online packaged foods.")
                        .foregroundStyle(.secondary)
                } else if searchText.count < PackagedFoodSearchClient.minimumQueryLength {
                    Text("Enter at least 2 characters to search online packaged foods.")
                        .foregroundStyle(.secondary)
                } else if isRemoteSearchAvailable == false {
                    Text("Online packaged food search is not configured for this build.")
                        .foregroundStyle(.secondary)
                } else {
                    Button("Search Open Food Facts") {
                        onSearchOnline()
                    }

                    if remoteSearch.isLoading && remoteSearch.results.isEmpty {
                        HStack {
                            ProgressView()
                            Text("Searching online packaged foods…")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let remoteErrorMessage = remoteSearch.errorMessage {
                        Text(remoteErrorMessage)
                            .foregroundStyle(.secondary)
                    }

                    if remoteSearch.results.isEmpty
                        && remoteSearch.hasState
                        && remoteSearch.isLoading == false
                        && remoteSearch.errorMessage == nil
                    {
                        Text(emptyRemoteSearchMessage)
                            .foregroundStyle(.secondary)
                    }

                    if showsUSDASearchFallback {
                        Button("Search USDA instead") {
                            onSearchUSDA()
                        }
                    }

                    ForEach(remoteSearch.results) { result in
                        Button {
                            selectedRemoteResult = result
                        } label: {
                            RemoteFoodRow(result: result)
                        }
                        .buttonStyle(.plain)
                        .environment(\.defaultMinListRowHeight, 0)
                        .listRowInsets(foodRowInsets)
                    }

                    if remoteSearch.isLoading && remoteSearch.results.isEmpty == false {
                        HStack {
                            ProgressView()
                            Text("Loading more results…")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if remoteSearch.hasMore {
                        Button("Load More") {
                            onLoadMoreRemoteResults()
                        }
                        .disabled(remoteSearch.isLoading)
                    }
                }
            } header: {
                Text("Online Packaged Foods")
            }
        }
        .listStyle(.plain)
        .onScrollGeometryChange(for: CGFloat.self) { scrollGeometry in
            max(0, scrollGeometry.contentOffset.y)
        } action: { _, newOffset in
            onScrollOffsetChange(newOffset)
        }
        .task(id: searchText) {
            await updateLocalFoods(for: searchText)
        }
        .navigationDestination(item: $selectedLocalFoodDraft) { draft in
            LogFoodScreen(
                initialDraft: draft,
                loggingDay: loggingDay,
                onFoodLogged: onFoodLogged
            )
        }
        .navigationDestination(item: $selectedRemoteResult) { result in
            RemoteSearchSelectionScreen(
                result: result,
                loggingDay: loggingDay,
                onFoodLogged: onFoodLogged
            )
        }
    }

    @ViewBuilder
    private var localResultsHeader: some View {
        if suggestions.isEmpty {
            onDeviceHeader
                .padding(.leading, SearchFoodSpacing.headerLeading)
        } else {
            VStack(alignment: .leading, spacing: SearchFoodSpacing.suggestionToHeader) {
                ScrollView(.horizontal, showsIndicators: false) {
                    suggestionPills
                        .padding(.horizontal, SearchFoodSpacing.headerLeading)
                        .padding(.vertical, SearchFoodSpacing.suggestionGlassBleed)
                        .contentShape(Rectangle())
                }
                .scrollClipDisabled()

                onDeviceHeader
                    .padding(.leading, SearchFoodSpacing.headerLeading)
            }
        }
    }

    private var onDeviceHeader: some View {
        Text("On Device")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private var foodRowInsets: EdgeInsets {
        EdgeInsets(
            top: 0,
            leading: SearchFoodSpacing.foodRowHorizontal,
            bottom: 0,
            trailing: SearchFoodSpacing.foodRowHorizontal
        )
    }

    @ViewBuilder
    private var suggestionPills: some View {
        if #available(iOS 26, macOS 26, *) {
            GlassEffectContainer(spacing: SearchFoodSpacing.pillSpacing) {
                suggestionPillStack
            }
        } else {
            suggestionPillStack
        }
    }

    private var suggestionPillStack: some View {
        HStack(spacing: SearchFoodSpacing.pillSpacing) {
            ForEach(suggestions) { suggestion in
                suggestionLink(for: suggestion)
                    .buttonStyle(.plain)
            }
        }
    }

    private func suggestionLink(for suggestion: FoodSuggestion) -> some View {
        let initialAmounts = FoodQuantityState.initialAmounts(for: suggestion.sourceEntry)
        let initialQuantityAmount =
            suggestion.sourceEntry.quantityModeKind == .servings ? initialAmounts.servings : initialAmounts.grams

        return NavigationLink {
            LogFoodScreen(
                initialDraft: FoodDraft(logEntry: suggestion.sourceEntry, saveAsCustomFood: false),
                loggingDay: loggingDay,
                initialQuantityMode: suggestion.sourceEntry.quantityModeKind,
                initialQuantityAmount: initialQuantityAmount,
                onFoodLogged: onFoodLogged
            )
        } label: {
            SuggestionPillLabel(title: suggestion.foodName)
        }
    }

    private func localFoodLink(for result: LocalFoodSearchResult) -> some View {
        Button {
            selectedLocalFoodDraft = localFoodDraft(for: result.id)
        } label: {
            LocalFoodSearchResultRow(result: result)
        }
        .buttonStyle(.plain)
    }

    private var localEmptyMessage: String {
        if searchText.isEmpty {
            return "No saved foods available on device yet."
        }

        return "No on-device foods match this search yet."
    }

    private var localResultsFooter: String {
        if searchText.isEmpty {
            return localFoods.isEmpty ? "" : "\(localFoods.count) recent on-device foods shown"
        }

        if localFoods.isEmpty {
            return "No foods available offline"
        }

        return "\(localFoods.count) on-device matches shown"
    }

    private var showsUSDASearchFallback: Bool {
        remoteSearch.provider == .openFoodFacts
            && remoteSearch.isLoading == false
            && remoteSearch.results.isEmpty
            && remoteSearch.hasState
    }

    private var emptyRemoteSearchMessage: String {
        switch remoteSearch.provider {
        case .openFoodFacts:
            return "No Open Food Facts packaged foods matched this search."
        case .usda:
            return "No USDA packaged foods matched this search."
        case nil:
            return "No online packaged foods matched this search."
        }
    }

    private func updateLocalFoods(for query: String) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        isLocalSearchLoading = true
        let container = modelContext.container
        let searchTerm = localFetchSearchTerm(for: trimmedQuery)
        let searchTask = Task<[LocalFoodSearchResult], Never>.detached(priority: .userInitiated) {
            guard Task.isCancelled == false else { return [] }

            let context = ModelContext(container)
            let normalizedQuery = FoodItemSearchQuery(trimmedQuery).normalizedText
            let fieldPrefixQuery = " \(normalizedQuery)"

            do {
                guard trimmedQuery.isEmpty == false else {
                    return try recentLocalFoods(in: context).map(LocalFoodSearchResult.init)
                }

                let foods = try localFoodCandidates(
                    in: context,
                    normalizedQuery: normalizedQuery,
                    fieldPrefixQuery: fieldPrefixQuery,
                    searchTerm: searchTerm
                )
                guard Task.isCancelled == false else { return [] }
                return FoodItemLocalSearch.rankedFoods(foods, matching: trimmedQuery).prefix(60).map(LocalFoodSearchResult.init)
            } catch {
                return []
            }
        }

        let results = await withTaskCancellationHandler {
            await searchTask.value
        } onCancel: {
            searchTask.cancel()
        }

        guard !Task.isCancelled else { return }
        localFoods = results
        isLocalSearchLoading = false
    }

    private func localFoodDraft(for id: UUID) -> FoodDraft? {
        var descriptor = FetchDescriptor<FoodItem>(
            predicate: #Predicate { food in
                food.id == id
            }
        )
        descriptor.fetchLimit = 1

        guard let food = try? modelContext.fetch(descriptor).first else { return nil }
        return FoodDraft(foodItem: food, saveAsCustomFood: false)
    }

    private func localFetchSearchTerm(for query: String) -> String {
        let tokens = query.lowercased().split(whereSeparator: { $0.isWhitespace }).map(String.init)
        return tokens.first(where: { $0.allSatisfy(\.isNumber) }) ?? tokens.max(by: { $0.count < $1.count }) ?? query
    }
}

nonisolated private func recentLocalFoods(in context: ModelContext) throws -> [FoodItem] {
    var descriptor = FetchDescriptor<FoodItem>(
        sortBy: [
            SortDescriptor(\.updatedAt, order: .reverse),
            SortDescriptor(\.name)
        ]
    )
    descriptor.fetchLimit = 60
    return try context.fetch(descriptor)
}

nonisolated private func localFoodCandidates(
    in context: ModelContext,
    normalizedQuery: String,
    fieldPrefixQuery: String,
    searchTerm: String
) throws -> [FoodItem] {
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

    return candidates
}
