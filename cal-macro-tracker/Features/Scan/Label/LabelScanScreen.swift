#if os(iOS)
import PhotosUI
import SwiftUI

struct LabelScanScreen: View {
    let onFoodLogged: () -> Void

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var logFoodDestination: LogFoodDestination?
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showingCamera = false
    @State private var scanFeedbackToken = 0

    private let recognizer = NutritionLabelTextRecognizer()

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
            Task {
                await loadSelectedPhoto(item)
            }
        }
        .navigationDestination(isPresented: isShowingLogFood) {
            if let logFoodDestination {
                LogFoodScreen(
                    initialDraft: logFoodDestination.draft,
                    reviewNotes: logFoodDestination.reviewNotes,
                    previewImageData: logFoodDestination.previewImageData,
                    onFoodLogged: onFoodLogged
                )
            }
        }
        .sensoryFeedback(.success, trigger: scanFeedbackToken)
        .errorBanner(message: $errorMessage)
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
    let previewImageData: Data?
}
#else
import SwiftUI

struct LabelScanScreen: View {
    let onFoodLogged: () -> Void

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
