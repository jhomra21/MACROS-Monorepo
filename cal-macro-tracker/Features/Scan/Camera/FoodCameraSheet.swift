#if os(iOS)
import AVFoundation
import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import VisionKit

struct FoodCameraSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(SharingSyncService.self) private var sharingSyncService

    let loggingDay: CalendarDay?
    let onFoodLogged: () -> Void

    @State private var scanner: DataScannerViewController?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingLibraryPicker = false
    @State private var result: FoodCameraResultPanel.Content = .message("Point at a barcode, or photograph the nutrition label.")
    @State private var active = true
    @State private var busy = false
    @State private var isCapturingPhoto = false
    @State private var useStillCamera = false
    @State private var captureImageData: Data?
    @State private var servings = 1.0
    @State private var logDestination: FoodCameraLogDestination?
    @State private var recoveryDestination: BarcodeScanLogFoodDestination?
    @State private var route: FoodCameraRoute?
    @State private var feedbackToken = 0
    @State private var permissionDenied = false

    private let barcodeScanner = BarcodeImageScanner()
    private let labelRecognizer = NutritionLabelTextRecognizer()

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                resultPanel
                preview
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 28))

                HStack {
                    Button(action: dismiss.callAsFunction) {
                        Label("Close", systemImage: "xmark")
                            .labelStyle(.iconOnly)
                            .frame(width: 52, height: 52)
                    }
                    .accessibilityLabel("Close camera")
                    Spacer()
                    Button(action: captureLabel) {
                        Circle().fill(.white).frame(width: 68, height: 68)
                            .overlay(Circle().stroke(.black.opacity(0.12), lineWidth: 1))
                    }
                    .accessibilityLabel("Photograph nutrition label")
                    .disabled(busy)
                    Spacer()
                    Button {
                        active = false
                        busy = true
                        showingLibraryPicker = true
                    } label: {
                        Image(systemName: "photo.on.rectangle").frame(width: 52, height: 52)
                    }
                    .accessibilityLabel("Choose a photo")
                }
                .font(.title3.weight(.semibold))
                .buttonStyle(.glass)
            }
            .padding(16)
            .background(.black)
            .foregroundStyle(.white)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $logDestination) { destination in
                LogFoodScreen(
                    initialDraft: destination.draft,
                    loggingDay: loggingDay,
                    reviewNotes: destination.notes,
                    requiredReviewNutrients: destination.missingNutrients,
                    previewImageData: destination.imageData,
                    onFoodLogged: onFoodLogged
                )
            }
            .navigationDestination(item: $route) { destination in
                switch destination {
                case .manual:
                    AddFoodScreen(initialMode: .manual, loggingDay: loggingDay)
                case .search:
                    AddFoodScreen(loggingDay: loggingDay)
                }
            }
            .sheet(isPresented: $useStillCamera) {
                CameraImagePicker(onImagePicked: { image in
                    useStillCamera = false
                    Task { await processImage(image) }
                }) {
                    useStillCamera = false
                    active = true
                }
                .ignoresSafeArea()
            }
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }
                active = false
                busy = true
                Task {
                    await ScanStillImageImport.loadSelectedPhoto(
                        item,
                        clearSelection: { selectedPhoto = nil },
                        processImage: processImage,
                        onError: showError
                    )
                }
            }
            .onChange(of: showingLibraryPicker) { _, isPresented in
                guard isPresented == false, selectedPhoto == nil else { return }
                busy = false
                active = canLiveScan && scenePhase == .active
            }
            .onChange(of: scenePhase) { _, phase in
                guard busy == false else { return }
                if phase == .active, AVCaptureDevice.authorizationStatus(for: .video) == .denied {
                    permissionDenied = true
                    result = .error("Camera access is off. Allow camera access in Settings, or choose a photo from your library.")
                }
                active = phase == .active && canLiveScan
            }
            .onAppear {
                permissionDenied = AVCaptureDevice.authorizationStatus(for: .video) == .denied
                if permissionDenied {
                    active = false
                    result = .error("Camera access is off. Allow camera access in Settings, or choose a photo from your library.")
                } else if canLiveScan == false, UIImagePickerController.isSourceTypeAvailable(.camera) {
                    useStillCamera = true
                } else if canLiveScan == false {
                    active = false
                }
            }
            .onDisappear {
                active = false
            }
            .sensoryFeedback(.success, trigger: feedbackToken)
            .photosPicker(isPresented: $showingLibraryPicker, selection: $selectedPhoto, matching: .images)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isResultExpanded)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(30)
    }

    @ViewBuilder
    private var resultPanel: some View {
        let panel = FoodCameraResultPanel(
            content: result,
            onChangeServings: { servings = $0 },
            onLog: logBarcode,
            onDetails: showDetails,
            onReview: showLabelReview,
            onRetry: resumeScanning,
            onManual: showManualRecovery,
            onSearch: { route = .search },
            showSettings: permissionDenied,
            onSettings: openSettings
        )
        if dynamicTypeSize.isAccessibilitySize {
            ScrollView { panel }
                .frame(maxHeight: 300)
        } else {
            panel.fixedSize(horizontal: false, vertical: true)
        }
    }

    private var preview: some View {
        ZStack(alignment: .topTrailing) {
            if canLiveScan {
                FoodCameraPreview(
                    isActive: active && (busy == false || isCapturingPhoto),
                    onReady: { scanner = $0 },
                    onBarcode: foundBarcode,
                    onFailure: showError
                )
            } else {
                ContentUnavailableView(
                    "Camera unavailable",
                    systemImage: "camera",
                    description: Text("Choose a photo to scan a barcode or nutrition label.")
                )
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.regularMaterial)
            }
        }
    }

    private var canLiveScan: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    private var isResultExpanded: Bool {
        switch result {
        case .message:
            false
        case .barcode, .label, .error:
            true
        }
    }

    private var foodRepository: FoodItemRepository {
        FoodItemRepository(modelContext: modelContext)
    }

    private func foundBarcode(_ barcode: String) {
        guard busy == false else { return }
        busy = true
        active = false
        result = .message("Looking up…")
        feedbackToken += 1
        Task {
            defer { busy = false }
            do {
                let resolver = BarcodeLookupResolver(foodRepository: foodRepository, client: OpenFoodFactsClient())
                let draft: FoodDraft
                if let cachedDraft = try resolver.cachedDraft(for: barcode) {
                    draft = cachedDraft
                } else {
                    draft = try await resolver.resolveRemoteDraft(barcode: barcode)
                }
                servings = 1
                result = .barcode(draft, servings: servings, logged: false)
            } catch {
                let recovery = BarcodeScanErrorRecovery(
                    error: error,
                    destination: BarcodeManualFallbackFactory.destination(for: barcode)
                )
                recoveryDestination = recovery.destination
                result = .error(recovery.message)
            }
        }
    }

    private func processImage(_ image: UIImage) async {
        active = false
        busy = true
        result = .message("Looking for a barcode…")
        do {
            let barcode = try await barcodeScanner.scanBarcode(from: image)
            busy = false
            foundBarcode(barcode)
        } catch {
            await readLabel(image)
        }
    }

    private func captureLabel() {
        guard busy == false else { return }
        busy = true
        isCapturingPhoto = true
        result = .message("Reading label…")
        Task {
            do {
                guard let scanner, scanner.isScanning else {
                    isCapturingPhoto = false
                    let canCaptureStill =
                        UIImagePickerController.isSourceTypeAvailable(.camera)
                        && AVCaptureDevice.authorizationStatus(for: .video) != .denied
                    useStillCamera = canCaptureStill
                    if canCaptureStill == false {
                        result = .error("Camera capture is unavailable. Choose a photo from your library.")
                    }
                    busy = false
                    return
                }
                let image = try await scanner.capturePhoto()
                isCapturingPhoto = false
                active = false
                captureImageData = await ImageJPEGEncoder.jpegData(from: image, compressionQuality: 0.9)
                await readLabel(image)
            } catch {
                isCapturingPhoto = false
                active = false
                active = false
                busy = false
                result = .error("Couldn’t capture that photo. Try again or choose a photo from your library.")
            }
        }
    }

    private func readLabel(_ image: UIImage) async {
        result = .message("Reading label…")
        do {
            async let recognizedText = labelRecognizer.recognizeText(in: image)
            async let jpegData = ImageJPEGEncoder.jpegData(from: image, compressionQuality: 0.9)
            let parsed = NutritionLabelParser.parse(recognizedText: try await recognizedText)
            captureImageData = await jpegData
            busy = false
            result = .label(parsed.draft, notes: parsed.notes, missingNutrients: parsed.missingRequiredNutrients)
        } catch {
            busy = false
            result = .error("Couldn’t read a nutrition label from this image. Retake the photo or enter the food manually.")
        }
    }

    private func logBarcode() {
        guard case let .barcode(draft, amount, _) = result, busy == false else { return }
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
            feedbackToken += 1
            result = .barcode(draft, servings: amount, logged: true)
            active = canLiveScan && scenePhase == .active
        } catch {
            busy = false
            result = .error(error.localizedDescription)
        }
    }

    private func showDetails() {
        guard case let .barcode(draft, _, _) = result else { return }
        logDestination = FoodCameraLogDestination(draft: draft, notes: [], missingNutrients: [], imageData: nil)
    }

    private func showManualRecovery() {
        guard let recoveryDestination else {
            route = .manual
            return
        }
        logDestination = FoodCameraLogDestination(
            draft: recoveryDestination.draft,
            notes: recoveryDestination.reviewNotes,
            missingNutrients: [],
            imageData: nil
        )
    }

    private func showLabelReview() {
        guard case let .label(draft, notes, missing) = result else { return }
        logDestination = FoodCameraLogDestination(draft: draft, notes: notes, missingNutrients: missing, imageData: captureImageData)
    }

    private func resumeScanning() {
        busy = false
        isCapturingPhoto = false
        result = .message("Point at a barcode, or photograph the nutrition label.")
        active = canLiveScan && scenePhase == .active
    }

    private func showError(_ message: String) {
        busy = false
        active = false
        permissionDenied = AVCaptureDevice.authorizationStatus(for: .video) == .denied
        result = .error(message)
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private struct FoodCameraLogDestination: Identifiable, Hashable {
    let id = UUID()
    let draft: FoodDraft
    let notes: [String]
    let missingNutrients: [RequiredNutritionReviewNutrient]
    let imageData: Data?
}

private enum FoodCameraRoute: String, Identifiable, Hashable {
    case manual
    case search
    var id: String { rawValue }
}
#else
import SwiftUI

struct FoodCameraSheet: View {
    let loggingDay: CalendarDay?
    let onFoodLogged: () -> Void

    var body: some View {
        ContentUnavailableView("Camera unavailable", systemImage: "camera")
    }
}
#endif
