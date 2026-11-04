import SwiftUI

struct FoodSearchResultsSection: View {
    let session: FoodSearchSession
    let query: String
    let onSelect: (RemoteSearchResult) -> Void

    var body: some View {
        Section("Search Results") {
            if query.count < FoodSearchClient.minimumQueryLength {
                Text("Enter at least 3 characters.")
                    .foregroundStyle(.secondary)
            } else {
                if session.query == query {
                    ForEach(session.results) { result in
                        Button {
                            onSelect(result)
                        } label: {
                            RemoteFoodRow(result: result)
                        }
                        .buttonStyle(.plain)
                        .environment(\.defaultMinListRowHeight, 0)
                        .listRowInsets(
                            EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
                        )
                    }
                }
                if session.isLoading {
                    HStack {
                        ProgressView()
                        Text("Searching…")
                            .foregroundStyle(.secondary)
                    }
                } else if session.didFail {
                    Button("Try again", action: session.retry)
                } else if session.query == query && session.hasSearched && session.results.isEmpty {
                    Text("No results found.")
                        .foregroundStyle(.secondary)
                }
                if session.nextCursor != nil && !session.didFail {
                    Button("Load more", action: session.loadMore)
                        .disabled(session.isLoading)
                }
            }
        }
    }
}
