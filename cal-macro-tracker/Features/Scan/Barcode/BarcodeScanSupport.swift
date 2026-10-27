import Foundation

struct BarcodeScanLogFoodDestination {
    let draft: FoodDraft
    let reviewNotes: [String]
}

struct BarcodeScanErrorRecovery {
    let message: String
    let destination: BarcodeScanLogFoodDestination

    init(error: Error, destination: BarcodeScanLogFoodDestination) {
        message = "\(error.localizedDescription) Please scan again."
        self.destination = destination
    }
}

enum BarcodeManualFallbackFactory {
    static func destination(for barcode: String) -> BarcodeScanLogFoodDestination {
        let normalizedBarcode = OpenFoodFactsIdentity.normalizedBarcode(barcode: barcode, externalProductID: nil, sourceURL: nil)

        return BarcodeScanLogFoodDestination(
            draft: FoodDraft(
                importedData: FoodDraftImportedData(
                    name: "",
                    source: .barcodeLookup,
                    barcode: normalizedBarcode,
                    sourceName: "Scanned barcode",
                    servingDescription: FoodDraft.defaultServingDescription,
                    perServingNutrition: .zero
                )
            ),
            reviewNotes: ["Barcode lookup failed. Complete the food details manually; the scanned barcode will still be saved."]
        )
    }
}

struct BarcodeLookupResolver {
    let foodRepository: FoodItemRepository
    let client: OpenFoodFactsClient

    func cachedDraft(for barcode: String) throws -> FoodDraft? {
        if let cachedFood = try foodRepository.fetchCachedBarcodeFood(barcode: barcode) {
            return FoodDraft(foodItem: cachedFood, saveAsCustomFood: true)
        }

        return nil
    }

    func resolveRemoteDraft(barcode: String) async throws -> FoodDraft {
        let product = try await fetchRemoteProduct(barcode: barcode)
        return try BarcodeLookupMapper.makeDraft(from: product, barcode: barcode)
    }

    private func fetchRemoteProduct(barcode: String) async throws -> OpenFoodFactsProduct {
        var lastError: Error?

        for _ in 0..<2 {
            do {
                return try await client.fetchProduct(barcode: barcode)
            } catch {
                lastError = error
                if shouldRetryRemoteLookup(after: error) == false {
                    break
                }
            }
        }

        throw lastError ?? OpenFoodFactsClientError.invalidResponse
    }

    private func shouldRetryRemoteLookup(after error: Error) -> Bool {
        if ScanCancellation.isCancellation(error) {
            return false
        }

        if let openFoodFactsError = error as? OpenFoodFactsClientError {
            return openFoodFactsError.isRetryable
        }

        return true
    }
}
