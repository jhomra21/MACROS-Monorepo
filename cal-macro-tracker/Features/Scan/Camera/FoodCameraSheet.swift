#if os(iOS)
import AVFoundation
import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import VisionKit

struct FoodCameraSheet: View {
    static let zoomTransitionID = "food-camera"

    @Environment(\.dismiss) var dismiss
    @Environment(\.isPresented) var isPresented
    @Environment(\.modelContext) var modelContext
    @Environment(\.scenePhase) var scenePhase
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
    @State private var isCameraOptionsExpanded = false

    var result: FoodCameraResultPanel.Content { panelContent }

    var recoveryDestination: BarcodeScanLogFoodDestination? {
        get { storedRecoveryDestination }
        nonmutating set { send(.recoveryDestinationChanged(newValue)) }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    resultPanel
                    cameraViewport(bottomSafeAreaInset: geometry.safeAreaInsets.bottom)
                }
                .containerBackground(.clear, for: .navigation)
                .toolbar(.hidden, for: .navigationBar)
            }
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
            .onChange(of: logDestination) { _, destination in
                if destination != nil { isCameraOptionsExpanded = false }
            }
            .onChange(of: route) { _, destination in
                if destination != nil { isCameraOptionsExpanded = false }
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
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: isCameraOptionsExpanded)
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
    }

    @ViewBuilder
    private var resultPanel: some View {
        let panel = FoodCameraResultPanel(
            content: displayedResult,
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
        if isResultExpanded {
            ScrollView {
                panel
            }
            .frame(maxHeight: 320)
            .foregroundStyle(.primary)
            .padding(.top, 12)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 8)
            .layoutPriority(2)
        } else {
            panel
                .foregroundStyle(.primary)
                .padding(.top, 12)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal, 8)
        }
    }

    private var displayedResult: FoodCameraResultPanel.Content {
        if canLiveScan == false, case .hint = result {
            return .hint("Camera unavailable. Choose a photo to scan a barcode or nutrition label.")
        }
        return result
    }

    private func cameraViewport(bottomSafeAreaInset: CGFloat) -> some View {
        ZStack {
            preview
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack {
                Spacer()
                cameraControls(bottomSafeAreaInset: bottomSafeAreaInset)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120, maxHeight: .infinity)
        .layoutPriority(0)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .padding(8)
        .ignoresSafeArea(edges: .bottom)
    }

    private func cameraControls(bottomSafeAreaInset: CGFloat) -> some View {
        VStack(alignment: .trailing, spacing: 8) {
            if isCameraOptionsExpanded {
                VStack(spacing: 8) {
                    cameraOptionButton(
                        systemImage: "photo",
                        label: "Choose a Photo",
                        disabled: busy
                    ) {
                        guard busy == false else { return }
                        isCameraOptionsExpanded = false
                        send(.libraryOpened)
                        showingLibraryPicker = true
                    }

                    cameraOptionButton(
                        systemImage: torchIsOn ? "bolt.fill" : "bolt.slash.fill",
                        label: torch.isAvailable
                            ? (torchIsOn ? "Turn Flash Off" : "Turn Flash On")
                            : "Flash Unavailable",
                        disabled: torch.isAvailable == false || active == false
                    ) {
                        send(.torchToggled)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack {
                Button {
                    send(.dismissed)
                    dismiss()
                } label: {
                    Label("Back", systemImage: "chevron.backward")
                        .labelStyle(.iconOnly)
                        .frame(width: 40, height: 40)
                        .glassEffect(.regular.tint(.black.opacity(0.55)).interactive(), in: Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .accessibilityLabel("Close camera")
                Spacer()
                Button {
                    isCameraOptionsExpanded = false
                    captureLabel()
                } label: {
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.9), lineWidth: 1)
                        Circle()
                            .fill(.white)
                            .frame(width: 54, height: 54)
                    }
                    .frame(width: 68, height: 68)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Photograph nutrition label")
                .disabled(busy)
                Spacer()

                Button {
                    isCameraOptionsExpanded.toggle()
                } label: {
                    Image(systemName: isCameraOptionsExpanded ? "xmark" : "ellipsis")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 40, height: 40)
                        .glassEffect(.regular.tint(.black.opacity(0.55)).interactive(), in: Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .accessibilityLabel(isCameraOptionsExpanded ? "Collapse camera options" : "More camera options")
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(canLiveScan ? .white : .primary)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12 + bottomSafeAreaInset)
    }

    private func cameraOptionButton(
        systemImage: String,
        label: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 40, height: 40)
                .glassEffect(.regular.tint(.black.opacity(0.55)).interactive(), in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .disabled(disabled)
        .accessibilityLabel(label)
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
        Group {
            if canLiveScan {
                FoodCameraPreview(
                    onReady: { controller in
                        scannerController = controller
                        if pendingScannerStart { startScanner() }
                    },
                    onBarcode: { foundBarcode($0) }
                )
            } else {
                Color(uiColor: .secondarySystemBackground)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    static let zoomTransitionID = "food-camera"

    let loggingDay: CalendarDay?
    let onFoodLogged: () -> Void

    var body: some View {
        ContentUnavailableView("Camera unavailable", systemImage: "camera")
    }
}
#endif
