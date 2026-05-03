import SwiftData
import SwiftUI

extension AddFoodScreen {
    func searchOnline() {
        startRemoteSearch(query: trimmedSearchText, page: 1, append: false, provider: .openFoodFacts)
    }

    func searchUSDA() {
        startRemoteSearch(query: trimmedSearchText, page: 1, append: false, provider: .usda)
    }

    func loadMoreRemoteResults() {
        guard remoteSearch.isLoading == false,
            remoteSearch.hasMore,
            let provider = remoteSearch.provider
        else { return }
        startRemoteSearch(query: remoteSearch.query, page: remoteSearch.page + 1, append: true, provider: provider)
    }

    func clearRemoteSearch() {
        remoteSearchTask?.cancel()
        remoteSearchTask = nil
        remoteSearch = AddFoodRemoteSearchSession()
    }

    func startRemoteSearch(query: String, page: Int, append: Bool, provider: RemoteSearchProvider?) {
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
            remoteSearch = AddFoodRemoteSearchSession(
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

    @MainActor
    func loadRemoteResults(
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
