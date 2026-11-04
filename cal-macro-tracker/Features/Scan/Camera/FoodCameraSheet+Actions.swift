#if os(iOS)
import AVFoundation
import SwiftData
import SwiftUI
import UIKit
import VisionKit

extension FoodCameraSheet {
    var foodRepository: FoodItemRepository {
        FoodItemRepository(modelContext: modelContext)
    }

    func foundBarcode(_ barcode: String, fromImage: Bool = false) {
        guard fromImage == false else {
            send(.barcodeFromImage(barcode))
            return
        }
        guard barcodeCaptureTask == nil else { return }
        // The frame must be captured before `.barcodeRecognized` stops scanning; on failure the card shows the dim only.
        frozenImage = nil
        barcodeCaptureTask = Task {
            var photo: UIImage?
            if let scanner = scannerController?.scanner, scanner.isScanning {
                photo = try? await scanner.capturePhoto()
            }
            guard Task.isCancelled == false else { return }
            barcodeCaptureTask = nil
            guard flow.phase == .scanning else { return }
            frozenImage = photo.map(Self.screenSizedStill)
            send(.barcodeRecognized(barcode))
        }
    }

    /// Keeps one screen-sized copy instead of the full-resolution capture.
    static func screenSizedStill(_ image: UIImage) -> UIImage {
        let longEdge: CGFloat = 1200
        let scale = min(1, longEdge / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func resolveBarcode(_ barcode: String) async {
        detectionFeedbackToken += 1
        do {
            let resolver = BarcodeLookupResolver(foodRepository: foodRepository, client: OpenFoodFactsClient())
            let draft: FoodDraft
            if let cachedDraft = try resolver.cachedDraft(for: barcode) {
                draft = cachedDraft
            } else {
                draft = try await resolver.resolveRemoteDraft(barcode: barcode)
            }
            try Task.checkCancellation()
            send(.lookupFinished)
            send(.contentChanged(.barcode(draft, servings: flow.servings, logged: false)))
        } catch {
            guard ScanCancellation.isCancellation(error) == false, Task.isCancelled == false else { return }
            let recovery = BarcodeScanErrorRecovery(
                error: error,
                destination: BarcodeManualFallbackFactory.destination(for: barcode)
            )
            send(.lookupFailed(barcode))
            send(.recoveryDestinationChanged(recovery.destination))
            send(.contentChanged(.error(recovery.message)))
        }
    }

    func captureLabel() {
        send(.shutterTapped)
    }

    func capturePhoto() async {
        do {
            guard let scanner = scannerController?.scanner, scanner.isScanning else {
                let canCaptureStill =
                    UIImagePickerController.isSourceTypeAvailable(.camera)
                    && AVCaptureDevice.authorizationStatus(for: .video) != .denied
                useStillCamera = canCaptureStill
                if canCaptureStill == false {
                    send(.captureFailed)
                    send(.contentChanged(.error("Camera capture is unavailable. Choose a photo from your library.")))
                }
                return
            }
            let image = try await scanner.capturePhoto()
            try Task.checkCancellation()
            pendingImage = image
            frozenImage = Self.screenSizedStill(image)
            send(.photoCaptured)
        } catch {
            guard Task.isCancelled == false else { return }
            send(.captureFailed)
            send(.contentChanged(.error("Couldn’t capture that photo. Try again or choose a photo from your library.")))
        }
    }

    func processPendingImage() async {
        guard let image = pendingImage else { return }
        frozenImage = Self.screenSizedStill(image)
        do {
            let barcode = try await barcodeScanner.scanBarcode(from: image)
            try Task.checkCancellation()
            foundBarcode(barcode, fromImage: true)
        } catch {
            guard ScanCancellation.isCancellation(error) == false, Task.isCancelled == false else { return }
            pendingImageHadNoBarcode = true
            send(.imageBarcodeMissing)
        }
    }

    func readPendingLabel() async {
        guard let image = pendingImage else { return }
        await readLabel(image, barcodeWasNotFound: pendingImageHadNoBarcode)
        pendingImage = nil
        pendingImageHadNoBarcode = false
    }

    func readLabel(_ image: UIImage, barcodeWasNotFound: Bool = false) async {
        do {
            async let recognizedText = labelRecognizer.recognizeText(in: image)
            async let jpegData = ImageJPEGEncoder.jpegData(from: image, compressionQuality: 0.9)
            let parsed = NutritionLabelParser.parse(recognizedText: try await recognizedText)
            let encodedImage = await jpegData
            try Task.checkCancellation()
            captureImageData = encodedImage
            labelInitialDraft = parsed.draft
            send(.ocrFinished)
            send(
                .contentChanged(
                    .label(
                        parsed.draft,
                        notes: parsed.notes,
                        missingNutrients: parsed.missingRequiredNutrients,
                        servings: 1,
                        logged: false
                    )))
        } catch {
            guard ScanCancellation.isCancellation(error) == false, Task.isCancelled == false else { return }
            send(.ocrFailed)
            send(
                .contentChanged(
                    .error(
                        barcodeWasNotFound
                            ? "No barcode or readable nutrition label was found. Scan again, search, or photograph the nutrition label."
                            : "Couldn’t read a nutrition label from this image. Retake the photo or enter the food manually."
                    )))
        }
    }

    func logBarcode() {
        if let editor = detailsEditor {
            guard editor.canSave, let multiplier = editor.loggingAction?.quantityMultiplier else { return }
            send(.servingsChanged(multiplier))
            send(.logTapped)
            return
        }
        guard let loggable = loggableResult else { return }
        let action = loggable.draft.loggingAction(
            initialDraft: loggable.initialDraft,
            quantityMode: .servings,
            quantityAmount: loggable.servings
        )
        guard action.canLog else {
            if case .label = result { return }
            send(.contentChanged(.error(action.validationError?.localizedDescription ?? "Review the food details before logging.")))
            return
        }
        send(.logTapped)
    }

    func logBarcode(servings amount: Double) {
        guard let loggable = loggableResult, flow.isSaving else { return }
        let action =
            detailsEditor?.loggingAction
            ?? loggable.draft.loggingAction(
                initialDraft: loggable.initialDraft,
                quantityMode: .servings,
                quantityAmount: amount
            )
        do {
            try LogEntryRepository(
                modelContext: modelContext,
                onDailyTotalsChanged: sharingSyncService.syncAfterDailyTotalsChange
            ).logFood(action: action, loggedAt: loggingDay?.date(matchingTimeOf: .now) ?? .now, operation: "Log food")
            send(.logFinished)
            feedbackToken += 1
            detailsEditor = nil
            detailsExpanded = false
            let loggedServings = action.quantityMultiplier ?? amount
            switch result {
            case .barcode:
                send(.contentChanged(.barcode(action.draft, servings: loggedServings, logged: true)))
            case let .label(_, notes, missing, _, _):
                send(.contentChanged(.label(action.draft, notes: notes, missingNutrients: missing, servings: loggedServings, logged: true)))
            default:
                break
            }
        } catch {
            send(.logFinished)
            logError = error.localizedDescription
        }
    }

    private var loggableResult: (draft: FoodDraft, initialDraft: FoodDraft, servings: Double)? {
        switch result {
        case let .barcode(draft, servings, _):
            (draft, draft, servings)
        case let .label(draft, _, _, servings, _):
            (draft, labelInitialDraft ?? draft, servings)
        default:
            nil
        }
    }

    func openDetails() {
        if detailsEditor != nil {
            detailsExpanded = true
            return
        }
        var editor: FoodLogEditorState
        switch result {
        case let .barcode(draft, amount, _):
            editor = FoodLogEditorState(initialDraft: draft, initialQuantityAmount: amount)
        case let .label(draft, notes, missing, amount, _):
            editor = FoodLogEditorState(
                initialDraft: draft, originalDraft: labelInitialDraft,
                initialQuantityAmount: amount, reviewNotes: notes,
                requiredReviewNutrients: missing, previewImageData: captureImageData
            )
        default:
            return
        }
        editor.numericText.retainsPresentedNutrientText = true
        detailsEditor = editor
        detailsExpanded = true
        suspendScannerForDetails()
    }

    private func suspendScannerForDetails() {
        scannerController?.stopScanning()
        pendingScannerStart = false
        scannerSuspendedForDetails = true
        scannerController = nil
    }

    func showManualRecovery() {
        guard let recoveryDestination else {
            route = .manual
            return
        }
        send(.recoveryDraftOpened)
        send(.contentChanged(.barcode(recoveryDestination.draft, servings: flow.servings, logged: false)))
        detailsEditor = FoodLogEditorState(
            initialDraft: recoveryDestination.draft, reviewNotes: recoveryDestination.reviewNotes
        )
        detailsEditor?.numericText.retainsPresentedNutrientText = true
        detailsExpanded = true
        suspendScannerForDetails()
    }

    func resumeScanning() {
        detailsEditor = nil
        detailsExpanded = false
        scannerSuspendedForDetails = false
        labelInitialDraft = nil
        captureImageData = nil
        send(.scanAgain)
        guard flow.phase == .scanning else { return }
        // The simulator has no live preview. Hardware keeps the still until startScanner succeeds.
        if !canLiveScan { frozenImage = nil }
        send(.recoveryDestinationChanged(nil))
        send(.contentChanged(.hint("Point at a barcode, or photograph the nutrition label.")))
    }

    func showError(_ message: String) {
        guard Task.isCancelled == false else { return }
        send(flow.phase == .readingLabel ? .importFailed : .scannerFailed)
        permissionDenied = AVCaptureDevice.authorizationStatus(for: .video) == .denied
        send(.contentChanged(.error(message)))
    }

    func showImportError(_ message: String) {
        guard Task.isCancelled == false else { return }
        send(.importFailed)
        send(.contentChanged(.error(message)))
    }

    func startProcessing(_ operation: @escaping @MainActor () async -> Void) {
        processingTask?.cancel()
        processingTask = Task { await operation() }
    }

    func startScanner() {
        guard let scannerController else {
            pendingScannerStart = true
            return
        }
        pendingScannerStart = false
        do {
            try scannerController.startScanning()
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { frozenImage = nil }
        } catch {
            showError(error.localizedDescription)
        }
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
#endif
