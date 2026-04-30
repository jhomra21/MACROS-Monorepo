import SwiftUI

enum AddFoodScanDestination: Hashable, Identifiable {
    case barcode
    case label

    var id: Self { self }
}

struct AddFoodRemoteSearchSession {
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

final class AddFoodSearchScrollTracking {
    var lastOffset: CGFloat = 0
    var deepestOffset: CGFloat = 0

    func reset() {
        lastOffset = 0
        deepestOffset = 0
    }
}

extension View {
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
