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

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let onFoodLogged: () -> Void
    let loggingDay: CalendarDay?
    let entryMode: EntryMode

    init(
        onFoodLogged: @escaping () -> Void,
        loggingDay: CalendarDay? = nil,
        entryMode: EntryMode = .options
    ) {
        self.onFoodLogged = onFoodLogged
        self.loggingDay = loggingDay
        self.entryMode = entryMode
    }

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var logFoodDestination: BarcodeScanLogFoodDestination?
    @State private var errorMessage: String?
    @State private var errorRecovery: BarcodeScanErrorRecovery?
    @State private var isLoading = false
    @State private var showingLiveScanner = false
    @State private var showingCamera = false
    @State private var hasPresentedImmediateScanner = false
    @State private var showManualOptions = false
    @State private var pendingRecoveryCaptureSource: BarcodeCaptureSource?
    @State private var scanFeedbackToken = 0
    @State private var workTask: Task<Void, Never>?

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
                    startWorkTask {
                        await resolveBarcode(barcode, captureSource: .liveScanner)
                    }
                },
                onStartFailed: { error in
                    showingLiveScanner = false
                    showManualOptions = true
                    errorMessage = "Live barcode scanning could not start. \(error.localizedDescription)"
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
                startWorkTask {
                    await scanSelectedImage(image, captureSource: .cameraPhoto)
                }
            },
            onCancel: {
                handleImmediateCancelIfNeeded()
            }
        )
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            startWorkTask {
                await loadSelectedPhoto(item)
            }
        }
        .onDisappear {
            workTask?.cancel()
            workTask = nil
        }
        .navigationDestination(isPresented: isShowingLogFood) {
            if let logFoodDestination {
                LogFoodScreen(
                    initialDraft: logFoodDestination.draft,
                    loggingDay: loggingDay,
                    reviewNotes: logFoodDestination.reviewNotes,
                    onFoodLogged: onFoodLogged
                )
            }
        }
        .confirmationDialog(
            "Barcode Lookup Failed",
            isPresented: isShowingErrorRecovery,
            titleVisibility: .visible
        ) {
            if let errorRecovery {
                Button("Create Manually") {
                    presentLogFood(errorRecovery.destination)
                }

                Button(errorRecovery.captureSource.retryActionTitle) {
                    reopenCaptureSource(errorRecovery.captureSource)
                }
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            if let errorRecovery {
                Text(errorRecovery.message)
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

    private var lookupResolver: BarcodeLookupResolver {
        BarcodeLookupResolver(foodRepository: foodRepository, client: client)
    }

    private var canScanLive: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    private var canUseCamera: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    private var shouldShowOptions: Bool { entryMode == .options || showManualOptions }

    private var isShowingLogFood: Binding<Bool> {
        Binding(get: { logFoodDestination != nil }, set: { if !$0 { logFoodDestination = nil } })
    }

    private var isShowingErrorRecovery: Binding<Bool> {
        Binding(get: { errorRecovery != nil }, set: { if !$0 { errorRecovery = nil } })
    }

    private func presentImmediateScannerIfNeeded() {
        BarcodeScanPresentationSupport.presentImmediateScannerIfNeeded(
            entryMode: entryMode,
            hasPresentedImmediateScanner: &hasPresentedImmediateScanner,
            hasLogFoodDestination: logFoodDestination != nil,
            canScanLive: canScanLive,
            canUseCamera: canUseCamera,
            showingLiveScanner: &showingLiveScanner,
            showingCamera: &showingCamera,
            showManualOptions: &showManualOptions,
            errorMessage: &errorMessage
        )
    }

    private func handleImmediateCancelIfNeeded() { guard entryMode == .immediateCamera else { return }; dismiss() }

    private func startWorkTask(_ operation: @escaping @Sendable () async -> Void) {
        workTask?.cancel()
        workTask = Task { await operation() }
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
            defer { isLoading = false }

            let barcode = try await barcodeScanner.scanBarcode(from: image)
            guard Task.isCancelled == false else { return }
            await resolveBarcode(barcode, captureSource: captureSource)
        } catch {
            guard ScanCancellation.isCancellation(error) == false else { return }
            pendingRecoveryCaptureSource = entryMode == .immediateCamera ? captureSource : nil
            errorMessage = error.localizedDescription
        }
    }

    private func resolveBarcode(_ barcode: String, captureSource: BarcodeCaptureSource) async {
        do {
            isLoading = true
            defer { isLoading = false }

            errorMessage = nil
            errorRecovery = nil
            pendingRecoveryCaptureSource = nil

            if let cachedDraft = try lookupResolver.cachedDraft(for: barcode) {
                presentLogFood(BarcodeScanLogFoodDestination(draft: cachedDraft, reviewNotes: []))
                return
            }

            presentLogFood(
                BarcodeScanLogFoodDestination(
                    draft: try await lookupResolver.resolveRemoteDraft(barcode: barcode),
                    reviewNotes: []
                )
            )
        } catch {
            guard ScanCancellation.isCancellation(error) == false else { return }
            showManualOptions = true
            pendingRecoveryCaptureSource = nil
            errorRecovery = BarcodeScanErrorRecovery(
                message: "\(error.localizedDescription) \(captureSource.rescanPrompt)",
                captureSource: captureSource,
                destination: BarcodeManualFallbackFactory.destination(for: barcode)
            )
        }
    }

    private func presentLogFood(_ destination: BarcodeScanLogFoodDestination) {
        guard Task.isCancelled == false else { return }

        showManualOptions = true
        logFoodDestination = destination
        scanFeedbackToken += 1
    }

    private func reopenScannerIfNeeded() {
        guard let pendingRecoveryCaptureSource else { return }
        self.pendingRecoveryCaptureSource = nil

        reopenCaptureSource(pendingRecoveryCaptureSource)
    }

    private func reopenCaptureSource(_ captureSource: BarcodeCaptureSource) {
        BarcodeScanPresentationSupport.reopenCaptureSource(
            captureSource,
            showingLiveScanner: &showingLiveScanner,
            showingCamera: &showingCamera,
            showManualOptions: &showManualOptions
        )
    }
}
#endif
