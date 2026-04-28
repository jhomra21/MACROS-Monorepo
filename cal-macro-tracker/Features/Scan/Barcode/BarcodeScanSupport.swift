import Foundation

struct BarcodeScanLogFoodDestination {
    let draft: FoodDraft
    let reviewNotes: [String]
}

struct BarcodeScanErrorRecovery: Identifiable {
    let id = UUID()
    let message: String
    let captureSource: BarcodeCaptureSource
    let destination: BarcodeScanLogFoodDestination
}

enum BarcodeCaptureSource {
    case liveScanner
    case cameraPhoto
    case photoLibrary

    var retryActionTitle: String {
        switch self {
        case .liveScanner:
            "Scan Again"
        case .cameraPhoto:
            "Retake Photo"
        case .photoLibrary:
            "Choose Another Photo"
        }
    }

    var rescanPrompt: String {
        switch self {
        case .liveScanner, .cameraPhoto:
            "Please scan again."
        case .photoLibrary:
            "Please choose another barcode photo."
        }
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

enum BarcodeScanPresentationSupport {
    static func presentImmediateScannerIfNeeded(
        entryMode: BarcodeScanScreen.EntryMode,
        hasPresentedImmediateScanner: inout Bool,
        hasLogFoodDestination: Bool,
        canScanLive: Bool,
        canUseCamera: Bool,
        showingLiveScanner: inout Bool,
        showingCamera: inout Bool,
        showManualOptions: inout Bool,
        errorMessage: inout String?
    ) {
        guard entryMode == .immediateCamera, hasPresentedImmediateScanner == false, hasLogFoodDestination == false else { return }

        hasPresentedImmediateScanner = true

        if canScanLive {
            showingLiveScanner = true
        } else if canUseCamera {
            showingCamera = true
        } else {
            showManualOptions = true
            errorMessage = "Camera scanning is not available on this device right now."
        }
    }

    static func reopenCaptureSource(
        _ captureSource: BarcodeCaptureSource,
        showingLiveScanner: inout Bool,
        showingCamera: inout Bool,
        showManualOptions: inout Bool
    ) {
        switch captureSource {
        case .liveScanner:
            showingLiveScanner = true
        case .cameraPhoto:
            showingCamera = true
        case .photoLibrary:
            showManualOptions = true
        }
    }
}
