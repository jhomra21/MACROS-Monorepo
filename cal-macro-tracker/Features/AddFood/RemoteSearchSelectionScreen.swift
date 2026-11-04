import SwiftData
import SwiftUI

struct RemoteSearchSelectionScreen: View {
    @Environment(\.modelContext) private var modelContext

    let result: RemoteSearchResult
    let loggingDay: CalendarDay?
    let onFoodLogged: () -> Void

    @State private var draft: FoodDraft?
    @State private var errorMessage: String?
    @State private var retryRevision = 0

    var body: some View {
        Group {
            if let draft {
                LogFoodScreen(
                    initialDraft: draft,
                    loggingDay: loggingDay,
                    reviewNotes: result.reviewNotes,
                    requiredReviewNutrients: result.requiredReviewNutrients,
                    showsSourceAttribution: false,
                    onFoodLogged: onFoodLogged
                )
            } else if errorMessage != nil {
                Button("Try again") {
                    errorMessage = nil
                    retryRevision += 1
                }
            } else {
                ProgressView("Preparing food…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Search Result")
        .inlineNavigationTitle()
        .task(id: retryRevision) {
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
            if let cachedFood = try result.cachedFood(using: foodRepository) {
                draft = FoodDraft(foodItem: cachedFood, saveAsCustomFood: true)
                return
            }

            draft = result.makeDraft()
        } catch {
            errorMessage = "Try again"
        }
    }
}
extension RemoteSearchResult {
    func cachedFood(using foodRepository: FoodItemRepository) throws -> FoodItem? {
        for externalProductID in cacheLookupExternalProductIDs {
            if let cachedFood = try foodRepository.fetchReusableFood(
                source: .searchLookup,
                externalProductID: externalProductID
            ) {
                return cachedFood
            }

            if let cachedFood = try foodRepository.fetchReusableFood(
                source: .barcodeLookup,
                externalProductID: externalProductID
            ) {
                return cachedFood
            }
        }

        guard let barcode else { return nil }
        return try foodRepository.fetchBarcodeLookupFood(barcode: barcode)
    }
}
