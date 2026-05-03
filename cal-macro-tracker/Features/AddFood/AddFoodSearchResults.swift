import SwiftData
import SwiftUI

private enum SearchFoodSpacing {
    static let targetVisualGap: CGFloat = 16
    static let suggestionGlassBleed: CGFloat = 4
    static let suggestionToHeader = targetVisualGap - suggestionGlassBleed
    static let headerLeading: CGFloat = 12
    static let headerRowLeading: CGFloat = 4
    static let headerRowBottom: CGFloat = -16
    static let suggestionTop: CGFloat = -7
    static let foodRowVertical: CGFloat = 8
    static let foodRowHorizontal: CGFloat = 16
    static let rowTitleSpacing: CGFloat = 6
    static let localFoodRowSpacing: CGFloat = 12
    static let calorieUnitSpacing: CGFloat = 2
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

struct SearchFoodListView: View {
    let loggingDay: CalendarDay?
    let foods: [FoodItem]
    let suggestions: [FoodSuggestion]
    let totalFoodsCount: Int
    let hasLoadedFoods: Bool
    let remoteSearch: RemoteSearchViewState
    let isRemoteSearchAvailable: Bool
    let searchText: String
    let onFoodLogged: () -> Void
    let onSearchOnline: () -> Void
    let onSearchUSDA: () -> Void
    let onLoadMoreRemoteResults: () -> Void
    let onScrollOffsetChange: (CGFloat) -> Void

    var body: some View {
        List {
            localResultsHeader
                .environment(\.defaultMinListRowHeight, 0)
                .listRowInsets(
                    EdgeInsets(
                        top: suggestions.isEmpty ? SearchFoodSpacing.targetVisualGap : SearchFoodSpacing.suggestionTop,
                        leading: SearchFoodSpacing.headerRowLeading,
                        bottom: SearchFoodSpacing.headerRowBottom,
                        trailing: 0
                    )
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            Section {
                if foods.isEmpty {
                    Text(localEmptyMessage)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(foods) { food in
                        localFoodLink(for: food)
                            .environment(\.defaultMinListRowHeight, 0)
                            .listRowInsets(foodRowInsets)
                    }
                }
            } footer: {
                Text("\(totalFoodsCount) foods available offline")
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
                        NavigationLink {
                            RemoteSearchSelectionScreen(
                                result: result,
                                loggingDay: loggingDay,
                                onFoodLogged: onFoodLogged
                            )
                        } label: {
                            RemoteFoodRow(result: result)
                        }
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
        .contentMargins(.top, 0, for: .scrollContent)
        .onScrollGeometryChange(for: CGFloat.self) { scrollGeometry in
            max(0, scrollGeometry.contentOffset.y)
        } action: { _, newOffset in
            onScrollOffsetChange(newOffset)
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
            top: SearchFoodSpacing.foodRowVertical,
            leading: SearchFoodSpacing.foodRowHorizontal,
            bottom: SearchFoodSpacing.foodRowVertical,
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

    private func localFoodLink(for food: FoodItem) -> some View {
        NavigationLink {
            LogFoodScreen(
                initialDraft: FoodDraft(foodItem: food, saveAsCustomFood: false),
                loggingDay: loggingDay,
                onFoodLogged: onFoodLogged
            )
        } label: {
            LocalFoodRow(food: food)
        }
    }

    private var localEmptyMessage: String {
        if hasLoadedFoods == false {
            return isRemoteSearchAvailable
                ? "Foods are not available yet. You can still search online or use manual entry."
                : "Foods are not available yet. You can still use manual entry."
        }

        if searchText.isEmpty {
            return "No on-device foods are available yet."
        }

        return "No on-device foods match this search yet."
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
}

private struct SuggestionPillLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(.primary)
            .padding(.horizontal, SearchFoodSpacing.pillHorizontalPadding)
            .padding(.vertical, SearchFoodSpacing.pillVerticalPadding)
            .background(fallbackBackground)
            .contentShape(Capsule())
            .ifAvailableSuggestionGlassCapsule()
    }

    @ViewBuilder
    private var fallbackBackground: some View {
        if #unavailable(iOS 26, macOS 26) {
            PlatformColors.cardBackground
                .clipShape(Capsule())
        }
    }
}

private extension View {
    @ViewBuilder
    func ifAvailableSuggestionGlassCapsule() -> some View {
        if #available(iOS 26, macOS 26, *) {
            glassEffect(.regular.interactive(), in: .capsule)
        } else {
            self
        }
    }
}

private struct LocalFoodRow: View {
    let food: FoodItem

    var body: some View {
        HStack(alignment: .center, spacing: SearchFoodSpacing.localFoodRowSpacing) {
            VStack(alignment: .leading, spacing: SearchFoodSpacing.rowTitleSpacing) {
                Text(food.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(food.servingDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(alignment: .firstTextBaseline, spacing: SearchFoodSpacing.calorieUnitSpacing) {
                Text(food.caloriesPerServing.roundedForDisplay)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("kcal")
                    .font(.footnote.weight(.regular))
                    .foregroundStyle(.tertiary)
            }
            .monospacedDigit()
        }
    }
}

private struct RemoteFoodRow: View {
    let result: RemoteSearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(result.name)
                .font(.headline)

            if let brand = result.brand {
                Text(brand)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(result.summary)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

private struct RemoteSearchSelectionScreen: View {
    @Environment(\.modelContext) private var modelContext

    let result: RemoteSearchResult
    let loggingDay: CalendarDay?
    let onFoodLogged: () -> Void

    @State private var draft: FoodDraft?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let draft {
                LogFoodScreen(
                    initialDraft: draft,
                    loggingDay: loggingDay,
                    reviewNotes: result.reviewNotes,
                    onFoodLogged: onFoodLogged
                )
            } else if let errorMessage {
                ContentUnavailableView(
                    "Unable to load food",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
                .padding()
            } else {
                ProgressView("Preparing food…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Search Result")
        .inlineNavigationTitle()
        .task {
            await loadDraftIfNeeded()
        }
    }

    private var foodRepository: FoodItemRepository {
        FoodItemRepository(modelContext: modelContext)
    }

    @MainActor
    private func loadDraftIfNeeded() async {
        guard draft == nil, errorMessage == nil else { return }

        do {
            for externalProductID in result.cacheLookupExternalProductIDs {
                if let cachedFood = try foodRepository.fetchReusableFood(source: .searchLookup, externalProductID: externalProductID) {
                    draft = FoodDraft(foodItem: cachedFood, saveAsCustomFood: true)
                    return
                }

                if let cachedFood = try foodRepository.fetchReusableFood(source: .barcodeLookup, externalProductID: externalProductID) {
                    draft = FoodDraft(foodItem: cachedFood, saveAsCustomFood: true)
                    return
                }
            }

            if let barcode = result.barcode,
                let cachedFood = try foodRepository.fetchBarcodeLookupFood(barcode: barcode)
            {
                draft = FoodDraft(foodItem: cachedFood, saveAsCustomFood: true)
                return
            }

            draft = try result.makeDraft()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
