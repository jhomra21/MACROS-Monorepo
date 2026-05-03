import SwiftData
import SwiftUI

struct RemoteSearchSelectionScreen: View {
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
            if let cachedFood = try cachedFood() {
                draft = FoodDraft(foodItem: cachedFood, saveAsCustomFood: true)
                return
            }

            draft = try result.makeDraft()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func cachedFood() throws -> FoodItem? {
        for externalProductID in result.cacheLookupExternalProductIDs {
            if let cachedFood = try foodRepository.fetchReusableFood(source: .searchLookup, externalProductID: externalProductID) {
                return cachedFood
            }

            if let cachedFood = try foodRepository.fetchReusableFood(source: .barcodeLookup, externalProductID: externalProductID) {
                return cachedFood
            }
        }

        guard let barcode = result.barcode else { return nil }
        return try foodRepository.fetchBarcodeLookupFood(barcode: barcode)
    }
}
