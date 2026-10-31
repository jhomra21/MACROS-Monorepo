#if os(iOS)
import AVFoundation
import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import VisionKit

struct FoodCameraSheet: View {
    static let zoomTransitionID = "food-camera"
    static let cameraAccessDeniedMessage =
        "Camera access is off. Allow camera access in Settings, or choose a photo from your library."

    @Environment(\.dismiss) var dismiss
    @Environment(\.isPresented) var isPresented
    @Environment(\.modelContext) var modelContext
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(SharingSyncService.self) var sharingSyncService

    let loggingDay: CalendarDay?
    let onFoodLogged: () -> Void

    @State private var cameraRevealVisible = false
    @State private var cameraCardVisible = false
    @State private var resultContentHeight: CGFloat = 0
    @State private var isCameraDismissalActive = false
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
    @State var frozenImage: UIImage?
    @State var pendingImageHadNoBarcode = false
    @State var logDestination: FoodCameraLogDestination?
    @State var storedRecoveryDestination: BarcodeScanLogFoodDestination?
    @State var route: FoodCameraRoute?
    @State var feedbackToken = 0
    @State var detectionFeedbackToken = 0
    @State var permissionDenied = false
    @State var logError: String?

    let barcodeScanner = BarcodeImageScanner()
    let labelRecognizer = NutritionLabelTextRecognizer()
    @State var torch = FoodCameraTorch()
    @State var torchIsOn = false
    @State private var isCameraOptionsExpanded = false
    @Namespace private var optionsNamespace

    var result: FoodCameraResultPanel.Content { panelContent }

    var recoveryDestination: BarcodeScanLogFoodDestination? {
        get { storedRecoveryDestination }
        nonmutating set { send(.recoveryDestinationChanged(newValue)) }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    stagedResultPanel(maxHeight: geometry.size.height * 0.45)
                    cameraViewport(bottomSafeAreaInset: geometry.safeAreaInsets.bottom)
                }
                .animation(resultAnimation, value: panelContent)
                .animation(resultAnimation, value: resultContentHeight)
                .background { Color.black.ignoresSafeArea() }
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
                        send(.contentChanged(.error(Self.cameraAccessDeniedMessage)))
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
                    send(.contentChanged(.error(Self.cameraAccessDeniedMessage)))
                }
            }
            .onAppear {
                if flow.phase != .dismissed { send(.sceneActive) }
            }
            .onDisappear { send(.navigationAway) }
            .sensoryFeedback(.success, trigger: feedbackToken)
            .sensoryFeedback(.impact(weight: .medium), trigger: detectionFeedbackToken)
            .photosPicker(isPresented: $showingLibraryPicker, selection: $selectedPhoto, matching: .images)
        }
        .background {
            CameraPresentationTransitionObserver(
                onPresentationFinished: revealCameraCard,
                onDismissalBegan: softenCameraForDismissal,
                onDismissalCancelled: restoreCameraAfterCancelledDismissal
            )
            .frame(width: 0, height: 0)
        }
        .onChange(of: isPresented) { _, presented in
            if presented == false {
                frozenImage = nil
                send(.dismissed)
            }
        }
        .alert(
            "Couldn’t log",
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
    private func resultPanel(maxHeight: CGFloat) -> some View {
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
            onManual: showManualRecovery,
            onSearch: { route = .search },
            showSettings: permissionDenied,
            onSettings: openSettings
        )
        ScrollView {
            panel
                .onGeometryChange(for: CGFloat.self) {
                    $0.size.height
                } action: {
                    resultContentHeight = $0
                }
        }
        .scrollDisabled(!isResultExpanded)
        .scrollBounceBehavior(.basedOnSize)
        .frame(height: min(resultContentHeight, maxHeight))
        .foregroundStyle(.primary)
        .padding(.top, 12)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .padding(.horizontal, 16)
        .layoutPriority(2)
    }

    private var displayedResult: FoodCameraResultPanel.Content {
        if canLiveScan == false, case .hint = result {
            return .hint("Camera unavailable. Choose a photo to scan a barcode or nutrition label.")
        }
        return result
    }

    private func stagedResultPanel(maxHeight: CGFloat) -> some View {
        resultPanel(maxHeight: maxHeight)
            .opacity(cameraCardVisible ? 1 : 0)
            .offset(y: cameraCardVisible || reduceMotion ? 0 : 56)
            .blur(radius: reduceMotion || cameraCardVisible ? 0 : 8)
            .allowsHitTesting(cameraCardVisible)
            .accessibilityHidden(!cameraCardVisible)
    }

    // One curve for the card, the viewport and the Scan again overlay; Reduce Motion keeps only a short crossfade.
    private var resultAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.15) : .smooth(duration: 0.3)
    }

    private var resultOverlay: some View {
        let isLabel = if case .label = result { true } else { false }
        return Button(action: resumeScanning) {
            Label(isLabel ? "Retake" : "Scan again", systemImage: "arrow.counterclockwise")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .buttonBorderShape(.capsule)
        .transition(reduceMotion ? .opacity : .scale(scale: 0.9).combined(with: .opacity))
    }

    private func cameraViewport(bottomSafeAreaInset: CGFloat) -> some View {
        ZStack {
            Color(uiColor: .darkGray)

            preview
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(cameraRevealVisible ? 1 : 0)

            // Result frozen: recognition is stopped, but the capture session stays running on purpose.
            // DataScannerViewController cannot pause its camera, and tearing it down costs a 0.5-1 s cold start plus
            // the reveal animation on every Scan again, versus a few seconds of sensor time while a result is shown.
            // A sharp still covers the live feed instead; the live layer is never blurred.
            Color.clear.overlay {
                if let frozenImage, isResultExpanded, cameraCardVisible {
                    Image(uiImage: frozenImage)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                }
            }
            .clipped()
            .allowsHitTesting(false)

            Color.black.opacity(isResultExpanded && cameraCardVisible ? 0.2 : 0)
                .allowsHitTesting(false)

            Color.clear.overlay(alignment: .top) {
                if isResultExpanded && cameraCardVisible {
                    resultOverlay.padding(.top, 16)
                }
            }

            VStack {
                Spacer()
                cameraControls(bottomSafeAreaInset: bottomSafeAreaInset)
            }
            .opacity(cameraRevealVisible ? 1 : 0)
            .blur(radius: reduceMotion || cameraRevealVisible ? 0 : 8)
        }
        .frame(maxWidth: .infinity, minHeight: 120, maxHeight: .infinity)
        .layoutPriority(0)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .padding(16)
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                cameraRevealVisible = true
            }
        }
    }

    private func revealCameraCard() {
        isCameraDismissalActive = false
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) {
            cameraCardVisible = true
        }
    }

    private func softenCameraForDismissal() {
        guard isCameraDismissalActive == false else { return }
        isCameraDismissalActive = true
        send(.sceneInactive)
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
            cameraCardVisible = false
            cameraRevealVisible = false
        }
    }

    private func restoreCameraAfterCancelledDismissal() {
        isCameraDismissalActive = false
        send(.sceneActive)
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) {
            cameraCardVisible = true
            cameraRevealVisible = true
        }
    }

    private func cameraControls(bottomSafeAreaInset: CGFloat) -> some View {
        HStack {
            Button {
                guard isCameraDismissalActive == false else { return }
                softenCameraForDismissal()
                dismiss()
            } label: {
                Label("Close camera", systemImage: "chevron.backward")
                    .labelStyle(.iconOnly)
                    .frame(width: 40, height: 40)
                    .glassEffect(.regular.tint(.black.opacity(0.55)).interactive(), in: Circle())
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
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
            Color.clear
                .frame(width: 44, height: 44)
                .overlay(alignment: .bottom) {
                    GlassEffectContainer(spacing: 12) {
                        VStack(spacing: 8) {
                            if isCameraOptionsExpanded {
                                cameraOptionButton(
                                    id: "photo",
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
                                    id: "torch",
                                    systemImage: torchIsOn ? "bolt.fill" : "bolt.slash.fill",
                                    label: torch.isAvailable
                                        ? (torchIsOn ? "Turn Flash Off" : "Turn Flash On")
                                        : "Flash Unavailable",
                                    disabled: torch.isAvailable == false || active == false
                                ) {
                                    send(.torchToggled)
                                }
                            }
                            Button {
                                isCameraOptionsExpanded.toggle()
                            } label: {
                                Image(systemName: isCameraOptionsExpanded ? "xmark" : "ellipsis")
                                    .font(.system(size: 18, weight: .semibold))
                                    .frame(width: 40, height: 40)
                                    .glassEffect(.regular.tint(.black.opacity(0.55)).interactive(), in: Circle())
                                    .glassEffectID("toggle", in: optionsNamespace)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.white)
                            .accessibilityLabel(isCameraOptionsExpanded ? "Collapse camera options" : "More camera options")
                        }
                    }
                    .animation(reduceMotion ? nil : .smooth(duration: 0.28), value: isCameraOptionsExpanded)
                }
        }
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(canLiveScan ? .white : .primary)
        .disabled(isCameraDismissalActive)
        .padding(.horizontal, 24)
        .padding(.bottom, 12 + bottomSafeAreaInset)
    }

    private func cameraOptionButton(
        id: String,
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
                .glassEffectID(id, in: optionsNamespace)
                .glassEffectTransition(.matchedGeometry)
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
                Color.clear
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

private struct CameraPresentationTransitionObserver: UIViewControllerRepresentable {
    let onPresentationFinished: () -> Void
    let onDismissalBegan: () -> Void
    let onDismissalCancelled: () -> Void

    func makeUIViewController(context: Context) -> TransitionObserverController {
        let controller = TransitionObserverController()
        update(controller)
        return controller
    }

    func updateUIViewController(_ controller: TransitionObserverController, context: Context) {
        update(controller)
    }

    private func update(_ controller: TransitionObserverController) {
        controller.onPresentationFinished = onPresentationFinished
        controller.onDismissalBegan = onDismissalBegan
        controller.onDismissalCancelled = onDismissalCancelled
    }

    final class TransitionObserverController: UIViewController {
        var onPresentationFinished: (() -> Void)?
        var onDismissalBegan: (() -> Void)?
        var onDismissalCancelled: (() -> Void)?

        private weak var presentationRoot: UIViewController?
        private var registeredPresentation = false
        private var trackingDismissal = false

        override func loadView() {
            let view = UIView(frame: .zero)
            view.isHidden = true
            view.isUserInteractionEnabled = false
            self.view = view
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)

            guard registeredPresentation == false,
                let modal = enclosingModal,
                modal.host.isBeingPresented,
                modal.presenter.presentedViewController === modal.host,
                let coordinator = modal.host.transitionCoordinator,
                coordinator.viewController(forKey: .from) === modal.presenter,
                coordinator.viewController(forKey: .to) === modal.host
            else { return }

            presentationRoot = modal.host
            registeredPresentation = true
            coordinator.animate(alongsideTransition: nil) { [weak self, weak host = modal.host, weak presenter = modal.presenter] context in
                guard let self, let host, let presenter,
                    self.presentationRoot === host,
                    context.viewController(forKey: .from) === presenter,
                    context.viewController(forKey: .to) === host
                else { return }

                guard context.isCancelled == false,
                    host.presentingViewController === presenter,
                    presenter.presentedViewController === host
                else {
                    self.registeredPresentation = false
                    self.presentationRoot = nil
                    return
                }

                self.onPresentationFinished?()
            }
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            // Fallback when the presentation identity check missed; reveal is idempotent.
            if registeredPresentation == false { onPresentationFinished?() }
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)

            guard trackingDismissal == false,
                let modal = enclosingModal,
                modal.host.isBeingDismissed,
                modal.host.presentingViewController === modal.presenter,
                modal.presenter.presentedViewController === modal.host,
                let coordinator = modal.host.transitionCoordinator,
                coordinator.viewController(forKey: .from) === modal.host,
                coordinator.viewController(forKey: .to) === modal.presenter
            else { return }

            trackingDismissal = true
            onDismissalBegan?()
            coordinator.animate(alongsideTransition: nil) { [weak self, weak host = modal.host, weak presenter = modal.presenter] context in
                guard let self, let host, let presenter,
                    context.viewController(forKey: .from) === host,
                    context.viewController(forKey: .to) === presenter
                else { return }

                self.trackingDismissal = false
                if context.isCancelled,
                    host.presentingViewController === presenter,
                    presenter.presentedViewController === host
                {
                    self.onDismissalCancelled?()
                } else {
                    self.registeredPresentation = false
                    self.presentationRoot = nil
                }
            }
        }

        private var enclosingModal: (host: UIViewController, presenter: UIViewController)? {
            var candidate = parent
            while let host = candidate {
                if let presenter = host.presentingViewController,
                    presenter.presentedViewController === host
                {
                    return (host, presenter)
                }
                candidate = host.parent
            }
            return nil
        }
    }
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
