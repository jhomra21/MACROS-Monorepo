#if os(iOS)
import AVFoundation
import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import VisionKit

struct FoodCameraSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(SharingSyncService.self) var sharingSyncService

    let loggingDay: CalendarDay?
    let onFoodLogged: () -> Void

    @State var scanner: DataScannerViewController?
    @State var selectedPhoto: PhotosPickerItem?
    @State var showingLibraryPicker = false
    @State var result: FoodCameraResultPanel.Content = .message("Point at a barcode, or photograph the nutrition label.")
    @State var active = true
    @State var busy = false
    @State var flow = FoodCameraFlow()
    @State var processingTask: Task<Void, Never>?
    @State var libraryPausedIdleScan = false
    @State var isCapturingPhoto = false
    @State var useStillCamera = false
    @State var captureImageData: Data?
    @State var logDestination: FoodCameraLogDestination?
    @State var recoveryDestination: BarcodeScanLogFoodDestination?
    @State var route: FoodCameraRoute?
    @State var feedbackToken = 0
    @State var permissionDenied = false

    let barcodeScanner = BarcodeImageScanner()
    let labelRecognizer = NutritionLabelTextRecognizer()
    @State var torch = FoodCameraTorch()
    @State var torchIsOn = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                resultPanel
                preview
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 28))

                HStack {
                    Button {
                        send(.dismissed)
                        dismiss()
                    } label: {
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
                        guard busy == false else { return }
                        libraryPausedIdleScan = flow.phase == .scanning
                        send(.libraryOpened)
                        showingLibraryPicker = true
                    } label: {
                        Image(systemName: "photo.on.rectangle").frame(width: 52, height: 52)
                    }
                    .accessibilityLabel("Choose a photo")
                    .disabled(busy)
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
                    initialQuantityAmount: destination.quantityAmount,
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
                    if flow.phase == .scanning { send(.libraryOpened) }
                    send(.imagePicked)
                    recoveryDestination = nil
                    startProcessing { await processImage(image) }
                }) {
                    useStillCamera = false
                    send(.scanAgain)
                    recoveryDestination = nil
                    if libraryPausedIdleScan { active = canLiveScan && scenePhase == .active }
                }
                .ignoresSafeArea()
            }
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }
                guard busy == false, flow.phase == .library else { return }
                active = false
                busy = true
                recoveryDestination = nil
                send(.imagePicked)
                startProcessing {
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
                send(.libraryCancelled)
                libraryPausedIdleScan = false
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active, AVCaptureDevice.authorizationStatus(for: .video) == .denied {
                    permissionDenied = true
                    if flow.phase == .scanning {
                        result = .error("Camera access is off. Allow camera access in Settings, or choose a photo from your library.")
                    }
                }
                if phase == .active {
                    send(.sceneActive)
                } else {
                    send(.sceneInactive)
                }
            }
            .onAppear {
                permissionDenied = AVCaptureDevice.authorizationStatus(for: .video) == .denied
                if permissionDenied {
                    active = false
                    result = .error("Camera access is off. Allow camera access in Settings, or choose a photo from your library.")
                } else if canLiveScan == false {
                    active = false
                }
            }
            .onAppear {
                if flow.phase != .dismissed { send(.sceneActive) }
            }
            .onDisappear {
                let isNavigatingAway =
                    logDestination != nil || route != nil || showingLibraryPicker || useStillCamera
                send(isNavigatingAway ? .navigationAway : .dismissed)
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
            onChangeServings: { amount in
                send(.servingsChanged(amount))
                guard case let .barcode(draft, _, logged) = result else { return }
                result = .barcode(draft, servings: flow.servings, logged: logged)
            },
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

    @discardableResult
    func send(_ event: FoodCameraFlow.Event) -> [FoodCameraFlow.Effect] {
        let effects = flow.reduce(event)
        for effect in effects {
            switch effect {
            case .startScanning:
                active = canLiveScan && scenePhase == .active
            case .stopScanning:
                active = false
            case .torchOff:
                torch.set(on: false)
                torchIsOn = false
            case .cancelWork:
                processingTask?.cancel()
                processingTask = nil
            case .lookup, .scanImage, .capturePhoto, .readLabel, .log:
                break
            }
        }
        return effects
    }

    private var preview: some View {
        ZStack(alignment: .topTrailing) {
            if canLiveScan {
                FoodCameraPreview(
                    isActive: active && (busy == false || isCapturingPhoto),
                    onReady: { scanner = $0 },
                    onBarcode: { foundBarcode($0) },
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
            if canLiveScan, flow.phase == .scanning, active, torch.isAvailable {
                Button {
                    torchIsOn.toggle()
                    torch.set(on: torchIsOn)
                    if torch.isAvailable == false { torchIsOn = false }
                } label: {
                    Image(systemName: torchIsOn ? "flashlight.on.fill" : "flashlight.off.fill")
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(.glass)
                .accessibilityLabel(torchIsOn ? "Turn Off Flashlight" : "Turn On Flashlight")
                .accessibilityAddTraits(torchIsOn ? .isSelected : [])
                .padding(12)
            }
        }
    }

    var canLiveScan: Bool {
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

}

struct FoodCameraLogDestination: Identifiable, Hashable {
    let id = UUID()
    let draft: FoodDraft
    let notes: [String]
    let missingNutrients: [RequiredNutritionReviewNutrient]
    let imageData: Data?
    let quantityAmount: Double
}

enum FoodCameraRoute: String, Identifiable, Hashable {
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
