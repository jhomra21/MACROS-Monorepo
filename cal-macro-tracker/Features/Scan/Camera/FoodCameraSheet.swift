#if os(iOS)
import AVFoundation
import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import VisionKit

struct FoodCameraSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.isPresented) var isPresented
    @Environment(\.modelContext) var modelContext
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(SharingSyncService.self) var sharingSyncService

    let loggingDay: CalendarDay?
    let onFoodLogged: () -> Void

    @State var scannerController: FoodCameraScannerController?
    @State var pendingScannerStart = false
    @State var selectedPhoto: PhotosPickerItem?
    @State var importingPhoto = false
    @State var showingLibraryPicker = false
    @State var panelContent: FoodCameraResultPanel.Content = .hint(
        "Point at a barcode, or photograph the nutrition label."
    )
    @State var labelInitialDraft: FoodDraft?
    @State var flow = FoodCameraFlow()
    @State var processingTask: Task<Void, Never>?
    @State var useStillCamera = false
    @State var captureImageData: Data?
    @State var pendingImage: UIImage?
    @State var pendingImageHadNoBarcode = false
    @State var logDestination: FoodCameraLogDestination?
    @State var storedRecoveryDestination: BarcodeScanLogFoodDestination?
    @State var route: FoodCameraRoute?
    @State var feedbackToken = 0
    @State var permissionDenied = false
    @State var logError: String?

    let barcodeScanner = BarcodeImageScanner()
    let labelRecognizer = NutritionLabelTextRecognizer()
    @State var torch = FoodCameraTorch()
    @State var torchIsOn = false

    var result: FoodCameraResultPanel.Content { panelContent }

    var recoveryDestination: BarcodeScanLogFoodDestination? {
        get { storedRecoveryDestination }
        nonmutating set { send(.recoveryDestinationChanged(newValue)) }
    }

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
                    pendingImage = image
                    send(.imagePicked)
                    recoveryDestination = nil
                }) {
                    useStillCamera = false
                    send(.scanAgain)
                    recoveryDestination = nil
                }
                .ignoresSafeArea()
            }
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }
                guard flow.phase == .library, importingPhoto == false else { return }
                importingPhoto = true
                selectedPhoto = nil
                recoveryDestination = nil
                startProcessing {
                    defer { importingPhoto = false }
                    await ScanStillImageImport.loadSelectedPhoto(
                        item,
                        clearSelection: {},
                        processImage: { image in
                            pendingImage = image
                            send(.imagePicked)
                        },
                        onError: { showImportError($0) }
                    )
                }
            }
            .onChange(of: showingLibraryPicker) { _, isPresented in
                guard isPresented == false, selectedPhoto == nil, importingPhoto == false else { return }
                send(.libraryCancelled)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active, AVCaptureDevice.authorizationStatus(for: .video) == .denied {
                    permissionDenied = true
                    if flow.phase == .scanning {
                        send(
                            .contentChanged(
                                .error(
                                    "Camera access is off. Allow camera access in Settings, or choose a photo from your library."
                                )))
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
                    send(
                        .contentChanged(
                            .error(
                                "Camera access is off. Allow camera access in Settings, or choose a photo from your library."
                            )))
                }
            }
            .onAppear {
                if flow.phase != .dismissed { send(.sceneActive) }
            }
            .onDisappear { send(.navigationAway) }
            .sensoryFeedback(.success, trigger: feedbackToken)
            .photosPicker(isPresented: $showingLibraryPicker, selection: $selectedPhoto, matching: .images)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isResultExpanded)
        }
        .onChange(of: isPresented) { _, presented in
            if presented == false { send(.dismissed) }
        }
        .alert(
            "Couldn't log",
            isPresented: Binding(
                get: { logError != nil },
                set: { if $0 == false { logError = nil } }
            )
        ) {
            Button("OK") { logError = nil }
        } message: {
            Text(logError ?? "")
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
                switch result {
                case let .barcode(draft, _, logged):
                    send(.contentChanged(.barcode(draft, servings: flow.servings, logged: logged)))
                case let .label(draft, notes, missing, _, logged):
                    send(.contentChanged(.label(draft, notes: notes, missingNutrients: missing, servings: flow.servings, logged: logged)))
                default:
                    break
                }
            },
            onChangeName: { name in
                guard case let .label(draft, notes, missing, servings, logged) = result else { return }
                var editedDraft = draft
                editedDraft.name = name
                send(.contentChanged(.label(editedDraft, notes: notes, missingNutrients: missing, servings: servings, logged: logged)))
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
        ScrollView { panel }
            .frame(maxHeight: 440)
            .fixedSize(horizontal: false, vertical: true)
    }

    @discardableResult
    func send(_ event: FoodCameraFlow.Event) -> [FoodCameraFlow.Effect] {
        let effects = flow.reduce(event)
        for effect in effects {
            switch effect {
            case .startScanning:
                startScanner()
            case .stopScanning:
                pendingScannerStart = false
                scannerController?.stopScanning()
            case .torchOn:
                torch.set(on: true)
                torchIsOn = torch.isAvailable
            case .torchOff:
                torch.set(on: false)
                torchIsOn = false
            case .cancelWork:
                processingTask?.cancel()
                processingTask = nil
            case .content(let content):
                panelContent = content
            case .recoveryDestination(let destination):
                storedRecoveryDestination = destination
            case let .lookup(barcode):
                send(.contentChanged(.message("Looking up…")))
                startProcessing { await resolveBarcode(barcode) }
            case .scanImage:
                guard pendingImage != nil else { continue }
                send(.contentChanged(.message("Looking for a barcode…")))
                startProcessing { await processPendingImage() }
            case .capturePhoto:
                recoveryDestination = nil
                send(.contentChanged(.message("Reading label…")))
                startProcessing { await capturePhoto() }
            case .readLabel:
                guard pendingImage != nil else { continue }
                send(.contentChanged(.message("Reading label…")))
                startProcessing { await readPendingLabel() }
            case .log(let servings):
                logBarcode(servings: servings)
            }
        }
        return effects
    }

    private var preview: some View {
        ZStack(alignment: .topTrailing) {
            if canLiveScan {
                FoodCameraPreview(
                    onReady: { controller in
                        scannerController = controller
                        if pendingScannerStart { startScanner() }
                    },
                    onBarcode: { foundBarcode($0) }
                )
            } else {
                ContentUnavailableView(
                    "Camera unavailable",
                    systemImage: "camera",
                    description: Text("Choose a photo to scan a barcode or nutrition label.")
                )
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.regularMaterial)
            }
            if canLiveScan, flow.phase == .scanning, active, torch.isAvailable {
                Button {
                    send(.torchToggled)
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

    var active: Bool {
        canLiveScan && scenePhase == .active && flow.isInactive == false
            && flow.phase == .scanning
    }

    var busy: Bool {
        flow.phase == .lookingUp || flow.phase == .capturing || flow.phase == .readingLabel
            || flow.phase == .library || flow.isSaving
    }

    private var isResultExpanded: Bool {
        switch result {
        case .message, .hint:
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
