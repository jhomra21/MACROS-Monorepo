import Foundation
import Observation

struct FoodSearchRequest: Hashable {
    let query: String
    let revision: Int
}

@MainActor
@Observable
final class FoodSearchSession {
    private(set) var query = ""
    private(set) var results: [RemoteSearchResult] = []
    private(set) var nextCursor: String?
    private(set) var isLoading = false
    private(set) var didFail = false
    private(set) var hasSearched = false
    private(set) var revision = 0

    private var generation = UUID()
    private var pendingQuery: String?
    private var pendingCursor: String?
    private var failedCursor: String?
    private let search: (String, String?) async throws -> FoodSearchPage

    init(
        search: @escaping (String, String?) async throws -> FoodSearchPage = { query, cursor in
            try await FoodSearchClient().searchFoods(query: query, cursor: cursor)
        }
    ) {
        self.search = search
    }

    func submit(query: String) {
        request(query: query, cursor: nil)
    }

    func retry() {
        request(query: query, cursor: failedCursor)
    }

    func loadMore() {
        guard !isLoading, let nextCursor else { return }
        request(query: query, cursor: nextCursor)
    }

    private func request(query: String, cursor: String?) {
        generation = UUID()
        pendingQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingCursor = cursor
        revision += 1
    }

    func load(query rawQuery: String, debounce: Bool = true) async {
        let normalizedQuery = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let immediate = pendingQuery == normalizedQuery
        let cursor = immediate ? pendingCursor : nil
        pendingQuery = nil
        pendingCursor = nil
        // Navigation can restart the view task without changing the search.
        if !immediate, query == normalizedQuery, hasSearched { return }
        let requestID = UUID()
        generation = requestID
        query = normalizedQuery
        failedCursor = cursor
        didFail = false
        if cursor == nil {
            results = []
            nextCursor = nil
            hasSearched = false
        }
        guard normalizedQuery.count >= FoodSearchClient.minimumQueryLength else {
            isLoading = false
            return
        }
        isLoading = true
        defer {
            if generation == requestID { isLoading = false }
        }
        do {
            if debounce && !immediate {
                try await Task.sleep(for: .milliseconds(700))
            }
            try Task.checkCancellation()
            let page = try await search(normalizedQuery, cursor)
            guard !Task.isCancelled, generation == requestID else { return }
            if cursor != nil {
                var seen = Set(results.map(\.id))
                results += page.results.filter { seen.insert($0.id).inserted }
            } else {
                results = page.results
            }
            nextCursor = page.nextCursor
            hasSearched = true
        } catch {
            guard !Task.isCancelled, generation == requestID else { return }
            didFail = true
        }
    }
}
