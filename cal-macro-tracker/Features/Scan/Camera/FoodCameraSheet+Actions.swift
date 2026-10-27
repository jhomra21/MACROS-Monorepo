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
        guard send(event).contains(.lookup(barcode: barcode)) else { return }
        torch.set(on: false)
        torchIsOn = false
        busy = true
        active = false
        result = .message("Looking up…")
        feedbackToken += 1
        startProcessing {
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
                busy = false
                result = .barcode(draft, servings: flow.servings, logged: false)
            } catch {
                guard ScanCancellation.isCancellation(error) == false, Task.isCancelled == false else { return }
                let recovery = BarcodeScanErrorRecovery(
                    error: error,
                    destination: BarcodeManualFallbackFactory.destination(for: barcode)
                )
                send(.lookupFailed(barcode))
                recoveryDestination = recovery.destination
                busy = false
                result = .error(recovery.message)
            }
        }
    }

    func processImage(_ image: UIImage) async {
        torch.set(on: false)
        torchIsOn = false
        active = false
        busy = true
        result = .message("Looking for a barcode…")
        do {
            let barcode = try await barcodeScanner.scanBarcode(from: image)
            try Task.checkCancellation()
            foundBarcode(barcode, fromImage: true)
        } catch {
            guard ScanCancellation.isCancellation(error) == false, Task.isCancelled == false else { return }
            await readLabel(image, barcodeWasNotFound: true)
        }
    }

    func captureLabel() {
        guard send(.shutterTapped).contains(.capturePhoto) else { return }
        torch.set(on: false)
        torchIsOn = false
        recoveryDestination = nil
        busy = true
        isCapturingPhoto = true
        result = .message("Reading label…")
        startProcessing {
            do {
                guard let scanner, scanner.isScanning else {
                    isCapturingPhoto = false
                    let canCaptureStill =
                        UIImagePickerController.isSourceTypeAvailable(.camera)
                        && AVCaptureDevice.authorizationStatus(for: .video) != .denied
                    send(.scanAgain)
                    useStillCamera = canCaptureStill
                    if canCaptureStill == false {
                        send(.captureFailed)
                        result = .error("Camera capture is unavailable. Choose a photo from your library.")
                    }
                    busy = false
                    return
                }
                let image = try await scanner.capturePhoto()
                try Task.checkCancellation()
                isCapturingPhoto = false
                active = false
                send(.photoCaptured)
                await readLabel(image)
            } catch {
                guard Task.isCancelled == false else { return }
                isCapturingPhoto = false
                active = false
                busy = false
                send(.captureFailed)
                result = .error("Couldn’t capture that photo. Try again or choose a photo from your library.")
            }
        }
    }

    func readLabel(_ image: UIImage, barcodeWasNotFound: Bool = false) async {
        result = .message("Reading label…")
        do {
            async let recognizedText = labelRecognizer.recognizeText(in: image)
            async let jpegData = ImageJPEGEncoder.jpegData(from: image, compressionQuality: 0.9)
            let parsed = NutritionLabelParser.parse(recognizedText: try await recognizedText)
            let encodedImage = await jpegData
            try Task.checkCancellation()
            captureImageData = encodedImage
            busy = false
            send(.ocrFinished)
            result = .label(parsed.draft, notes: parsed.notes, missingNutrients: parsed.missingRequiredNutrients)
        } catch {
            guard ScanCancellation.isCancellation(error) == false, Task.isCancelled == false else { return }
            busy = false
            send(.ocrFailed)
            result = .error(
                barcodeWasNotFound
                    ? "No packaged-food barcode or readable nutrition label was found. Scan again, search online, or photograph the nutrition label."
                    : "Couldn’t read a nutrition label from this image. Retake the photo or enter the food manually."
            )
        }
    }

    func logBarcode() {
        guard case let .barcode(draft, amount, _) = result, busy == false else { return }
        guard send(.logTapped).contains(.log(servings: amount)) else { return }
        let action = draft.loggingAction(initialDraft: draft, quantityMode: .servings, quantityAmount: amount)
        guard action.canLog else {
            result = .error(action.validationError?.localizedDescription ?? "Review the food details before logging.")
            return
        }
        busy = true
        do {
            try LogEntryRepository(
                modelContext: modelContext,
                onDailyTotalsChanged: sharingSyncService.syncAfterDailyTotalsChange
            ).logFood(action: action, loggedAt: loggingDay?.date(matchingTimeOf: .now) ?? .now, operation: "Log food")
            busy = false
            send(.logFinished)
            feedbackToken += 1
            result = .barcode(draft, servings: amount, logged: true)
            active = false
        } catch {
            busy = false
            send(.logFinished)
            result = .error(error.localizedDescription)
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
        let effects = send(.scanAgain)
        guard effects.contains(.startScanning) || flow.isInactive else { return }
        processingTask?.cancel()
        processingTask = nil
        busy = false
        isCapturingPhoto = false
        torch.set(on: false)
        torchIsOn = false
        recoveryDestination = nil
        result = .message("Point at a barcode, or photograph the nutrition label.")
        active = canLiveScan && scenePhase == .active
    }

    func showError(_ message: String) {
        guard Task.isCancelled == false else { return }
        send(flow.phase == .readingLabel ? .importFailed : .scannerFailed)
        torch.set(on: false)
        torchIsOn = false
        busy = false
        active = false
        permissionDenied = AVCaptureDevice.authorizationStatus(for: .video) == .denied
        result = .error(message)
    }

    func startProcessing(_ operation: @escaping @MainActor () async -> Void) {
        processingTask?.cancel()
        processingTask = Task { await operation() }
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
#endif
