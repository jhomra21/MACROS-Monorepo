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
        let event: FoodCameraFlow.Event = fromImage ? .barcodeFromImage(barcode) : .barcodeRecognized(barcode)
        send(event)
    }

    func resolveBarcode(_ barcode: String) async {
        feedbackToken += 1
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
            send(.photoCaptured)
        } catch {
            guard Task.isCancelled == false else { return }
            send(.captureFailed)
            send(.contentChanged(.error("Couldn’t capture that photo. Try again or choose a photo from your library.")))
        }
    }

    func processPendingImage() async {
        guard let image = pendingImage else { return }
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
            send(.ocrFinished)
            send(.contentChanged(.label(parsed.draft, notes: parsed.notes, missingNutrients: parsed.missingRequiredNutrients)))
        } catch {
            guard ScanCancellation.isCancellation(error) == false, Task.isCancelled == false else { return }
            send(.ocrFailed)
            send(
                .contentChanged(
                    .error(
                        barcodeWasNotFound
                            ? "No packaged-food barcode or readable nutrition label was found. Scan again, search online, or photograph the nutrition label."
                            : "Couldn’t read a nutrition label from this image. Retake the photo or enter the food manually."
                    )))
        }
    }

    func logBarcode() {
        guard case let .barcode(draft, amount, _) = result else { return }
        let action = draft.loggingAction(initialDraft: draft, quantityMode: .servings, quantityAmount: amount)
        guard action.canLog else {
            send(.contentChanged(.error(action.validationError?.localizedDescription ?? "Review the food details before logging.")))
            return
        }
        send(.logTapped)
    }

    func logBarcode(servings amount: Double) {
        guard case let .barcode(draft, _, _) = result, flow.isSaving else { return }
        let action = draft.loggingAction(initialDraft: draft, quantityMode: .servings, quantityAmount: amount)
        do {
            try LogEntryRepository(
                modelContext: modelContext,
                onDailyTotalsChanged: sharingSyncService.syncAfterDailyTotalsChange
            ).logFood(action: action, loggedAt: loggingDay?.date(matchingTimeOf: .now) ?? .now, operation: "Log food")
            send(.logFinished)
            feedbackToken += 1
            send(.contentChanged(.barcode(draft, servings: amount, logged: true)))
        } catch {
            send(.logFinished)
            send(.contentChanged(.error(error.localizedDescription)))
        }
    }

    func showDetails() {
        guard case let .barcode(draft, amount, _) = result else { return }
        logDestination = FoodCameraLogDestination(draft: draft, notes: [], missingNutrients: [], imageData: nil, quantityAmount: amount)
    }

    func showManualRecovery() {
        guard let recoveryDestination else {
            route = .manual
            return
        }
        logDestination = FoodCameraLogDestination(
            draft: recoveryDestination.draft,
            notes: recoveryDestination.reviewNotes,
            missingNutrients: [],
            imageData: nil,
            quantityAmount: 1
        )
    }

    func showLabelReview() {
        guard case let .label(draft, notes, missing) = result else { return }
        logDestination = FoodCameraLogDestination(
            draft: draft, notes: notes, missingNutrients: missing, imageData: captureImageData, quantityAmount: 1)
    }

    func resumeScanning() {
        send(.scanAgain)
        guard flow.phase == .scanning else { return }
        send(.recoveryDestinationChanged(nil))
        send(.contentChanged(.message("Point at a barcode, or photograph the nutrition label.")))
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
