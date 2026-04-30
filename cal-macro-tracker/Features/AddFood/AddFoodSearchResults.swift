import SwiftData
import SwiftUI

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
            if suggestions.isEmpty == false {
                ScrollView(.horizontal, showsIndicators: false) {
                    suggestionPills
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                }
                .environment(\.defaultMinListRowHeight, 0)
                .listRowInsets(EdgeInsets(top: -8, leading: 16, bottom: 0, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            Text("On Device")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .environment(\.defaultMinListRowHeight, 0)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            Section {
                if foods.isEmpty {
                    Text(localEmptyMessage)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(foods) { food in
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
    private var suggestionPills: some View {
        HStack(spacing: 8) {
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
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.clear, in: Capsule())
            .contentShape(Capsule())
    }
}

private struct LocalFoodRow: View {
    let food: FoodItem

    var body: some View {
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
