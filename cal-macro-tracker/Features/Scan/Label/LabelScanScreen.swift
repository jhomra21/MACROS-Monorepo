#if os(iOS)
import PhotosUI
import SwiftUI

struct LabelScanScreen: View {
    let loggingDay: CalendarDay?
    let onFoodLogged: () -> Void

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var logFoodDestination: LogFoodDestination?
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showingCamera = false
    @State private var scanFeedbackToken = 0
    @State private var workTask: Task<Void, Never>?

    private let recognizer = NutritionLabelTextRecognizer()

    init(onFoodLogged: @escaping () -> Void, loggingDay: CalendarDay? = nil) {
        self.loggingDay = loggingDay
        self.onFoodLogged = onFoodLogged
    }

    var body: some View {
        List {
            Section("Nutrition Label") {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Choose Label Photo", systemImage: "photo")
                }

                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Take Label Photo") {
                        showingCamera = true
                    }
                }
            }

            if isLoading {
                Section {
                    HStack {
                        ProgressView()
                        Text("Reading nutrition label…")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Scan Label")
        .inlineNavigationTitle()
        .scanCameraCaptureSheet(isPresented: $showingCamera) { image in
            await parseLabelImage(image)
        }
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
                    requiredReviewNutrients: logFoodDestination.missingRequiredNutrients,
                    previewImageData: logFoodDestination.previewImageData,
                    onFoodLogged: onFoodLogged
                )
            }
        }
        .sensoryFeedback(.success, trigger: scanFeedbackToken)
        .errorBanner(message: $errorMessage)
    }

    private func startWorkTask(_ operation: @escaping @Sendable () async -> Void) {
        workTask?.cancel()
        workTask = Task {
            await operation()
        }
    }

    private var isShowingLogFood: Binding<Bool> {
        Binding(
            get: { logFoodDestination != nil },
            set: { isPresented in
                if !isPresented {
                    logFoodDestination = nil
                }
            }
        )
    }

    private func loadSelectedPhoto(_ item: PhotosPickerItem) async {
        await ScanStillImageImport.loadSelectedPhoto(
            item,
            clearSelection: { selectedPhoto = nil },
            processImage: { image in
                await parseLabelImage(image)
            },
            onError: { message in
                errorMessage = message
            }
        )
    }

    private func parseLabelImage(_ image: UIImage) async {
        do {
            isLoading = true
            defer { isLoading = false }

            let recognizedText = try await recognizer.recognizeText(in: image)
            let result = NutritionLabelParser.parse(recognizedText: recognizedText)

            presentLogFood(
                LogFoodDestination(
                    draft: result.draft,
                    reviewNotes: result.notes,
                    missingRequiredNutrients: result.missingRequiredNutrients,
                    previewImageData: image.jpegData(compressionQuality: 0.9)
                )
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func presentLogFood(_ destination: LogFoodDestination) {
        logFoodDestination = destination
        scanFeedbackToken += 1
    }
}

private struct LogFoodDestination {
    let draft: FoodDraft
    let reviewNotes: [String]
    let missingRequiredNutrients: [RequiredNutritionReviewNutrient]
    let previewImageData: Data?
}
#else
import SwiftUI

struct LabelScanScreen: View {
    let loggingDay: CalendarDay?
    let onFoodLogged: () -> Void

    init(onFoodLogged: @escaping () -> Void, loggingDay: CalendarDay? = nil) {
        self.loggingDay = loggingDay
        self.onFoodLogged = onFoodLogged
    }

    var body: some View {
        ContentUnavailableView(
            "Label scan unavailable",
            systemImage: "camera.viewfinder",
            description: Text("Nutrition label scanning is only available on iPhone builds.")
        )
        .navigationTitle("Scan Label")
    }
}
#endif
