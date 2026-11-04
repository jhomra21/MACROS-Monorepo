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

    private static let sideButtonDiameter: CGFloat = 44
    private static let shutterDiameter: CGFloat = 66
    private static let shutterDiscDiameter: CGFloat = 52
    private static let shutterHitDiameter: CGFloat = 68

    @Environment(\.dismiss) var dismiss
    @Environment(\.isPresented) var isPresented
    @Environment(\.modelContext) var modelContext
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(SharingSyncService.self) var sharingSyncService
    @Query private var goals: [DailyGoals]

    let loggingDay: CalendarDay?
    let onFoodLogged: () -> Void

    @State private var cameraRevealVisible = false
    @State private var cameraCardVisible = false
    @State private var resultContentHeight: CGFloat = 0
    @State private var resultActionHeight: CGFloat = 0
    @State private var detailsButtonSize: CGSize = .zero
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
    @State var barcodeCaptureTask: Task<Void, Never>?
    @State var useStillCamera = false
    @State var captureImageData: Data?
    @State var pendingImage: UIImage?
    @State var frozenImage: UIImage?
    @State var pendingImageHadNoBarcode = false
    @State var detailsEditor: FoodLogEditorState?
    @State var detailsExpanded = false
    @State var scannerSuspendedForDetails = false
    @State private var isKeyboardVisible = false
    @State private var pendingExit: CameraDetailsExit?
    @Environment(\.verticalSizeClass) private var verticalSizeClass
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
                let sideBySide = detailsExpanded && verticalSizeClass == .compact && !isKeyboardVisible
                let layout = sideBySide ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))
                let expandedHeight =
                    isKeyboardVisible || sideBySide
                    ? geometry.size.height : min(geometry.size.height * 0.75, max(0, geometry.size.height - 170))
                layout {
                    stagedResultPanel(maxHeight: geometry.size.height * 0.45, expandedHeight: expandedHeight)
                        .frame(width: sideBySide ? geometry.size.width * 0.65 : nil)
                        .zIndex(1)
                    cameraViewport(bottomSafeAreaInset: geometry.safeAreaInsets.bottom)
                }
                .animation(layoutAnimation, value: panelContent.kind)
                .animation(layoutAnimation, value: resultContentHeight)
                .animation(layoutAnimation, value: detailsExpanded)
                .animation(layoutAnimation, value: isKeyboardVisible)
                .background { Color.black.ignoresSafeArea() }
                .containerBackground(.clear, for: .navigation)
                .toolbar(.hidden, for: .navigationBar)
                .environment(\.colorScheme, .dark)
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
                if flow.phase == .scanning { frozenImage = nil }
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
        .background { Color.black.ignoresSafeArea() }
        .bottomPinnedKeyboardVisibility($isKeyboardVisible)
        .modifier(
            CameraDirtyDismissal(isDirty: detailsEditor?.isDirty == true) {
                detailsEditor = nil
                detailsExpanded = false
                softenCameraForDismissal()
            }
        )
        .confirmationDialog(
            "Discard changes?",
            isPresented: Binding(
                get: { pendingExit != nil }, set: { if !$0 { pendingExit = nil } }
            ), titleVisibility: .visible, presenting: pendingExit
        ) { exit in
            Button("Discard Changes", role: .destructive) {
                pendingExit = nil
                if exit == .close { closeCamera() } else { resumeScanning() }
            }
            Button("Keep Editing") { pendingExit = nil }
        } message: { _ in
            Text("Your food edits haven’t been logged.")
        }
        .background {
            CameraPresentationTransitionObserver(
                onPresentationFinished: revealCameraCard,
                onDismissalBegan: {
                    if detailsEditor?.isDirty != true { softenCameraForDismissal() }
                },
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
    private func resultPanel(maxHeight: CGFloat, expandedHeight: CGFloat) -> some View {
        let panel = FoodCameraResultPanel(
            content: displayedResult,
            goals: MacroGoalsSnapshot(goals: DailyGoals.activeRecord(from: goals)),
            onChangeServings: { amount in
                if detailsEditor != nil {
                    detailsEditor?.servingsAmount = amount
                    return
                }
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
                if detailsEditor != nil {
                    detailsEditor?.draft.name = name
                    return
                }
                guard case let .label(draft, notes, missing, servings, logged) = result else { return }
                var editedDraft = draft
                editedDraft.name = name
                send(.contentChanged(.label(editedDraft, notes: notes, missingNutrients: missing, servings: servings, logged: logged)))
            },
            onLog: logBarcode,
            onDetails: openDetails,
            onManual: showManualRecovery,
            onSearch: { route = .search },
            showSettings: permissionDenied,
            onSettings: openSettings,
            showsActionButtons: !hasDetailsActions,
            gramsAmount: detailsEditor?.quantityMode == .grams ? detailsEditor?.gramsAmount : nil,
            headerTrailingInset: detailsExpanded && !separateDetailsHeader ? detailsButtonSize.width + 12 : 0
        )
        VStack(spacing: 0) {
            ScrollView {
                panel
                    .padding(.bottom, hasDetailsActions ? -16 : 0)
                    .onGeometryChange(for: CGFloat.self) {
                        $0.size.height
                    } action: {
                        resultContentHeight = $0
                    }
            }
            .frame(
                height: detailsExpanded && isKeyboardVisible
                    ? 0
                    : min(
                        resultContentHeight,
                        detailsExpanded
                            ? (dynamicTypeSize.isAccessibilitySize || verticalSizeClass == .compact
                                ? expandedHeight * 0.4 : resultContentHeight)
                            : max(0, maxHeight - (hasDetailsActions ? resultActionHeight : 0))
                    )
            )
            .scrollDisabled(!hasActionableResult)
            .scrollBounceBehavior(.basedOnSize)
            .clipped()
            .accessibilityHidden(detailsExpanded && isKeyboardVisible)
            .padding(.top, detailsExpanded && separateDetailsHeader ? detailsButtonSize.height + 12 : 0)
            if let editor = detailsEditor {
                FoodCameraDetailsEditor(
                    editor: Binding(get: { detailsEditor ?? editor }, set: { detailsEditor = $0 }),
                    onQuantityChange: { send(.servingsChanged($0)) },
                    isExpanded: detailsExpanded
                )
                // Keep the same Form, but reveal only its body below the single persistent summary.
                .frame(height: detailsExpanded ? nil : 0)
                .clipped()
                .allowsHitTesting(detailsExpanded)
                .accessibilityHidden(!detailsExpanded)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if hasDetailsActions {
                logFooter
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .onGeometryChange(for: CGFloat.self) {
                        $0.size.height
                    } action: {
                        if !detailsExpanded { resultActionHeight = $0 }
                    }
            }
        }
        .frame(
            height: detailsExpanded ? expandedHeight : min(resultContentHeight + (hasDetailsActions ? resultActionHeight : 0), maxHeight)
        )
        .overlay(alignment: detailsExpanded ? .topTrailing : .bottomLeading) {
            if hasDetailsActions {
                detailsToggle
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(
                        .bottom,
                        !detailsExpanded && dynamicTypeSize.isAccessibilitySize && showsCompactLog
                            ? max(16, resultActionHeight - detailsButtonSize.height - 16) : 16)
            }
        }
        .clipShape(.rect(cornerRadius: 24))
        .accessibilityIdentifier("camera-result-card")
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .controlSize(.large)
        .buttonBorderShape(.capsule)
        .foregroundStyle(.primary)
        .padding(.horizontal, 16)
        .layoutPriority(2)
        .transaction { transaction in
            if reduceMotion { transaction.disablesAnimations = true }
        }
    }

    private var separateDetailsHeader: Bool { dynamicTypeSize.isAccessibilitySize || isKeyboardVisible }

    private var logFooter: some View {
        let layout =
            dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            if !detailsExpanded {
                // Reserve the compact control's space, not a second rendered button.
                Color.clear
                    .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : detailsButtonSize.width, height: detailsButtonSize.height)
                    .accessibilityHidden(true)
            }
            if showsCompactLog || detailsExpanded {
                Button(action: logBarcode) { Text("Log").frame(maxWidth: .infinity) }
                    .buttonStyle(.glassProminent)
                    .disabled(!canLogResult)
                    .accessibilityIdentifier("camera-log")
            }
        }
    }

    private var detailsToggle: some View {
        Button {
            if detailsExpanded {
                KeyboardSupport.dismissFirstResponder()
                detailsExpanded = false
            } else {
                openDetails()
            }
        } label: {
            Text(detailsExpanded ? "Less" : compactDetailsTitle)
                .fixedSize(horizontal: true, vertical: false)
                .frame(maxWidth: showsCompactLog || detailsExpanded ? nil : .infinity)
        }
        .buttonStyle(.glass)
        .accessibilityLabel(detailsExpanded ? "Show less" : compactDetailsTitle)
        .accessibilityIdentifier("camera-details-toggle")
        .onGeometryChange(for: CGSize.self) {
            $0.size
        } action: {
            detailsButtonSize = $0
        }
    }

    private var displayedResult: FoodCameraResultPanel.Content {
        if let editor = detailsEditor {
            let amount = editor.previewLoggingAction.quantityMultiplier ?? editor.servingsAmount
            if case .label = result {
                return .label(editor.previewDraft, notes: [], missingNutrients: [], servings: amount, logged: false)
            }
            return .barcode(editor.previewDraft, servings: amount, logged: false)
        }
        if canLiveScan == false, case .hint = result {
            return .hint("Camera unavailable. Choose a photo to scan a barcode or nutrition label.")
        }
        return result
    }

    private var hasDetailsActions: Bool { result.kind == .barcode || result.kind == .label }

    private var compactDetailsTitle: String { result.kind == .label ? "Edit details" : "Details" }

    private var showsCompactLog: Bool {
        if detailsEditor != nil { return true }
        if case let .label(_, _, missing, _, _) = result { return missing.isEmpty }
        return true
    }

    private var canLogResult: Bool {
        if let editor = detailsEditor { return editor.canSave }
        if case let .label(draft, _, _, amount, _) = result {
            return draft.loggingAction(initialDraft: labelInitialDraft ?? draft, quantityMode: .servings, quantityAmount: amount).canLog
        }
        return true
    }

    private func stagedResultPanel(maxHeight: CGFloat, expandedHeight: CGFloat) -> some View {
        resultPanel(maxHeight: maxHeight, expandedHeight: expandedHeight)
            .opacity(cameraCardVisible ? 1 : 0)
            .offset(y: cameraCardVisible || reduceMotion ? 0 : 56)
            .blur(radius: reduceMotion || cameraCardVisible ? 0 : 8)
            .allowsHitTesting(cameraCardVisible)
            .accessibilityHidden(!cameraCardVisible)
    }

    // Let initial measurements settle during the zoom before animating result-driven layout changes.
    private var layoutAnimation: Animation? { cameraCardVisible && !reduceMotion ? .smooth(duration: 0.3) : nil }

    private var fadeAnimation: Animation { cameraFade(reduceMotion: reduceMotion) }

    /// Only real results freeze the viewport; errors keep the shutter and photo menu usable.
    private var isResultFrozen: Bool {
        switch result.kind {
        case .barcode, .barcodeLogged, .label, .labelLogged: true
        case .message, .hint, .error: false
        }
    }

    private var resultOverlay: some View {
        let isLabel = if case .label = result { true } else { false }
        return Button {
            requestExit(.scanAgain)
        } label: {
            Label(isLabel ? "Retake" : "Scan again", systemImage: "arrow.counterclockwise")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .buttonBorderShape(.capsule)
        // Keep both strip actions separate at AX sizes; their accessible names stay unchanged.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .transition(reduceMotion ? .opacity : .scale(scale: 0.9).combined(with: .opacity))
    }

    private func cameraViewport(bottomSafeAreaInset: CGFloat) -> some View {
        ZStack {
            Color(uiColor: .darkGray)

            preview
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(cameraRevealVisible ? 1 : 0)

            // Keep the captured still through a cold restart, until startScanning succeeds.
            Color.clear.overlay {
                if let frozenImage {
                    Image(uiImage: frozenImage)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                }
            }
            .clipped()
            .allowsHitTesting(false)
            .animation(fadeAnimation, value: frozenImage != nil)

            Color.black.opacity(isResultFrozen ? 0.2 : 0)
                .allowsHitTesting(false)
                .animation(fadeAnimation, value: isResultFrozen)

            Color.clear.overlay(alignment: .top) {
                if hasActionableResult {
                    resultOverlay.padding(.top, 16)
                }
            }
            .animation(fadeAnimation, value: hasActionableResult)

            VStack {
                Spacer()
                cameraControls(bottomSafeAreaInset: bottomSafeAreaInset)
            }
            .opacity(cameraRevealVisible ? 1 : 0)
            .blur(radius: reduceMotion || cameraRevealVisible ? 0 : 8)
        }
        .frame(maxWidth: .infinity, minHeight: hidesCameraStrip ? 0 : 120, maxHeight: hidesCameraStrip ? 0 : .infinity)
        .layoutPriority(0)
        .clipShape(
            .rect(
                uniformBottomCorners: .concentric(minimum: 28),
                topLeadingCorner: .fixed(28),
                topTrailingCorner: .fixed(28)
            )
        )
        .padding(hidesCameraStrip ? 0 : 16)
        .opacity(hidesCameraStrip ? 0 : 1)
        .allowsHitTesting(!hidesCameraStrip)
        .accessibilityHidden(hidesCameraStrip)
        .accessibilityIdentifier("camera-viewport")
        .ignoresSafeArea(detailsExpanded ? .container : .all, edges: .bottom)
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
                cameraRevealVisible = true
            }
        }
    }

    private var hidesCameraStrip: Bool { detailsExpanded && isKeyboardVisible }

    private enum CameraDetailsExit { case scanAgain, close }

    private func requestExit(_ exit: CameraDetailsExit) {
        if detailsEditor?.isDirty == true { pendingExit = exit } else if exit == .close { closeCamera() } else { resumeScanning() }
    }

    private func closeCamera() {
        detailsEditor = nil
        detailsExpanded = false
        softenCameraForDismissal()
        dismiss()
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
                requestExit(.close)
            } label: {
                Label("Close camera", systemImage: "chevron.backward")
                    .labelStyle(.iconOnly)
                    .frame(width: Self.sideButtonDiameter, height: Self.sideButtonDiameter)
                    .glassEffect(.regular.interactive(), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            Spacer()
            Button {
                isCameraOptionsExpanded = false
                captureLabel()
            } label: {
                Circle()
                    .fill(.white)
                    .frame(width: Self.shutterDiscDiameter, height: Self.shutterDiscDiameter)
                    .frame(width: Self.shutterDiameter, height: Self.shutterDiameter)
                    .glassEffect(.clear.interactive(), in: Circle())
                    .frame(width: Self.shutterHitDiameter, height: Self.shutterHitDiameter)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Photograph nutrition label")
            .disabled(busy)
            .modifier(FrozenHidden(isHidden: isResultFrozen, reduceMotion: reduceMotion))
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
                                    .frame(width: Self.sideButtonDiameter, height: Self.sideButtonDiameter)
                                    .glassEffect(.regular.interactive(), in: Circle())
                                    .glassEffectID("toggle", in: optionsNamespace)
                                    .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.white)
                            .accessibilityLabel(isCameraOptionsExpanded ? "Collapse camera options" : "More camera options")
                        }
                    }
                    .animation(reduceMotion ? nil : .smooth(duration: 0.28), value: isCameraOptionsExpanded)
                }
                .modifier(FrozenHidden(isHidden: isResultFrozen, reduceMotion: reduceMotion))
        }
        .onChange(of: isResultFrozen) { _, frozen in
            if frozen { isCameraOptionsExpanded = false }
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
                .frame(width: Self.sideButtonDiameter, height: Self.sideButtonDiameter)
                .glassEffect(.regular.interactive(), in: Circle())
                .glassEffectID(id, in: optionsNamespace)
                .glassEffectTransition(.matchedGeometry)
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
                barcodeCaptureTask?.cancel()
                barcodeCaptureTask = nil
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
            if canLiveScan && !scannerSuspendedForDetails {
                FoodCameraPreview(
                    onReady: { controller in
                        guard !scannerSuspendedForDetails else {
                            controller.stopScanning()
                            return
                        }
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

    private var hasActionableResult: Bool {
        switch result {
        case .message, .hint:
            false
        case .barcode, .label, .error:
            true
        }
    }

}

private func cameraFade(reduceMotion: Bool) -> Animation {
    reduceMotion ? .easeOut(duration: 0.15) : .smooth(duration: 0.3)
}

/// Fades a control out with a small downward move; it stays out of hit testing and VoiceOver while hidden.
private struct FrozenHidden: ViewModifier {
    let isHidden: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .accessibilityHidden(isHidden)
            .opacity(isHidden ? 0 : 1)
            .offset(y: isHidden && reduceMotion == false ? 8 : 0)
            .allowsHitTesting(!isHidden)
            .animation(cameraFade(reduceMotion: reduceMotion), value: isHidden)
    }
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
