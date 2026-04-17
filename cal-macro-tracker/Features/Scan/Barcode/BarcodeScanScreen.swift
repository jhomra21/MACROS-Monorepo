#if os(iOS)
import PhotosUI
import SwiftData
import SwiftUI
import VisionKit

struct BarcodeScanScreen: View {
    enum EntryMode {
        case options
        case immediateCamera
    }

    private enum BarcodeCaptureSource {
        case liveScanner
        case cameraPhoto
        case photoLibrary

        var rescanPrompt: String {
            switch self {
            case .liveScanner, .cameraPhoto:
                return "Please scan again."
            case .photoLibrary:
                return "Please choose another barcode photo."
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let onFoodLogged: () -> Void
    let entryMode: EntryMode

    init(onFoodLogged: @escaping () -> Void, entryMode: EntryMode = .options) {
        self.onFoodLogged = onFoodLogged
        self.entryMode = entryMode
    }

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var logFoodDraft: FoodDraft?
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showingLiveScanner = false
    @State private var showingCamera = false
    @State private var hasPresentedImmediateScanner = false
    @State private var showManualOptions = false
    @State private var pendingRecoveryCaptureSource: BarcodeCaptureSource?
    @State private var scanFeedbackToken = 0

    private let barcodeScanner = BarcodeImageScanner()
    private let client = OpenFoodFactsClient()

    var body: some View {
        Group {
            if shouldShowOptions {
                BarcodeScanOptionsList(
                    canScanLive: canScanLive,
                    canUseCamera: canUseCamera,
                    isLoading: isLoading,
                    selectedPhoto: $selectedPhoto,
                    onOpenLiveScanner: { showingLiveScanner = true },
                    onOpenCamera: { showingCamera = true }
                )
            } else {
                ProgressView(isLoading ? "Looking up product…" : "Opening camera…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .navigationTitle("Scan Barcode")
                    .inlineNavigationTitle()
            }
        }
        .onAppear {
            presentImmediateScannerIfNeeded()
        }
        .sheet(isPresented: $showingLiveScanner) {
            BarcodeLiveScannerSheet(
                onBarcodeScanned: { barcode in
                    showingLiveScanner = false
                    Task {
                        await resolveBarcode(barcode, captureSource: .liveScanner)
                    }
                },
                onCancel: {
                    showingLiveScanner = false
                    handleImmediateCancelIfNeeded()
                }
            )
            .interactiveDismissDisabled(entryMode == .immediateCamera)
        }
        .scanCameraCaptureSheet(
            isPresented: $showingCamera,
            isInteractiveDismissDisabled: entryMode == .immediateCamera,
            action: { image in
                await scanSelectedImage(image, captureSource: .cameraPhoto)
            },
            onCancel: {
                handleImmediateCancelIfNeeded()
            }
        )
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                await loadSelectedPhoto(item)
            }
        }
        .navigationDestination(isPresented: isShowingLogFood) {
            if let logFoodDraft {
                LogFoodScreen(initialDraft: logFoodDraft, onFoodLogged: onFoodLogged)
            }
        }
        .onChange(of: errorMessage) { oldValue, newValue in
            guard oldValue != nil, newValue == nil else { return }
            reopenScannerIfNeeded()
        }
        .sensoryFeedback(.success, trigger: scanFeedbackToken)
        .errorBanner(message: $errorMessage)
    }

    private var foodRepository: FoodItemRepository {
        FoodItemRepository(modelContext: modelContext)
    }

    private var canScanLive: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    private var canUseCamera: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    private var shouldShowOptions: Bool {
        entryMode == .options || showManualOptions
    }

    private var shouldAutoRecoverCaptureFlow: Bool {
        entryMode == .immediateCamera
    }

    private var isShowingLogFood: Binding<Bool> {
        Binding(
            get: { logFoodDraft != nil },
            set: { isPresented in
                if !isPresented {
                    logFoodDraft = nil
                }
            }
        )
    }

    private func presentImmediateScannerIfNeeded() {
        guard entryMode == .immediateCamera, hasPresentedImmediateScanner == false, logFoodDraft == nil else { return }

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

    private func handleImmediateCancelIfNeeded() {
        guard entryMode == .immediateCamera else { return }
        dismiss()
    }

    private func loadSelectedPhoto(_ item: PhotosPickerItem) async {
        await ScanStillImageImport.loadSelectedPhoto(
            item,
            clearSelection: { selectedPhoto = nil },
            processImage: { image in
                await scanSelectedImage(image, captureSource: .photoLibrary)
            },
            onError: { message in
                errorMessage = message
            }
        )
    }

    private func scanSelectedImage(_ image: UIImage, captureSource: BarcodeCaptureSource) async {
        do {
            isLoading = true
            let barcode = try await barcodeScanner.scanBarcode(from: image)
            await resolveBarcode(barcode, captureSource: captureSource)
        } catch {
            isLoading = false
            pendingRecoveryCaptureSource = shouldAutoRecoverCaptureFlow ? captureSource : nil
            errorMessage = error.localizedDescription
        }
    }

    private func resolveBarcode(_ barcode: String, captureSource: BarcodeCaptureSource) async {
        do {
            isLoading = true
            defer { isLoading = false }

            errorMessage = nil
            pendingRecoveryCaptureSource = nil

            if let cachedDraft = try cachedDraft(for: barcode) {
                presentLogFood(cachedDraft)
                return
            }

            presentLogFood(try await resolveRemoteDraft(barcode: barcode))
        } catch {
            pendingRecoveryCaptureSource = shouldAutoRecoverCaptureFlow ? captureSource : nil
            errorMessage = "\(error.localizedDescription) \(captureSource.rescanPrompt)"
        }
    }

    private func cachedDraft(for barcode: String) throws -> FoodDraft? {
        if let cachedFood = try foodRepository.fetchCachedBarcodeFood(barcode: barcode) {
            return FoodDraft(foodItem: cachedFood, saveAsCustomFood: true)
        }

        return nil
    }

    private func resolveRemoteDraft(barcode: String) async throws -> FoodDraft {
        let product = try await fetchRemoteProduct(barcode: barcode)
        return try BarcodeLookupMapper.makeDraft(from: product, barcode: barcode)
    }

    private func presentLogFood(_ draft: FoodDraft) {
        showManualOptions = true
        logFoodDraft = draft
        scanFeedbackToken += 1
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
        if let openFoodFactsError = error as? OpenFoodFactsClientError {
            return openFoodFactsError.isRetryable
        }

        return true
    }

    private func reopenScannerIfNeeded() {
        guard let pendingRecoveryCaptureSource else { return }
        self.pendingRecoveryCaptureSource = nil

        switch pendingRecoveryCaptureSource {
        case .liveScanner:
            showingLiveScanner = true
        case .cameraPhoto:
            showingCamera = true
        case .photoLibrary:
            showManualOptions = true
        }
    }
}
#else
import SwiftUI

struct BarcodeScanScreen: View {
    enum EntryMode {
        case options
        case immediateCamera
    }

    let onFoodLogged: () -> Void
    let entryMode: EntryMode

    init(onFoodLogged: @escaping () -> Void, entryMode: EntryMode = .options) {
        self.onFoodLogged = onFoodLogged
        self.entryMode = entryMode
    }

    var body: some View {
        ContentUnavailableView(
            "Barcode scan unavailable",
            systemImage: "barcode.viewfinder",
            description: Text("Barcode scanning is only available on iPhone builds.")
        )
        .navigationTitle("Scan Barcode")
    }
}
#endif
