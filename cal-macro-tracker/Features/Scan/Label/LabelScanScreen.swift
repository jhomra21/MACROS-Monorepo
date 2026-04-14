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
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw NSError(
                    domain: "LabelScanScreen", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to load the selected image."])
            }

            let image = try ScanImageLoading.loadUIImage(from: data)
            selectedPhoto = nil
            await parseLabelImage(image)
        } catch {
            selectedPhoto = nil
            errorMessage = error.localizedDescription
        }
    }

    private func parseLabelImage(_ image: UIImage) async {
        do {
            isLoading = true
            let recognizedText = try await recognizer.recognizeText(in: image)
            let result = NutritionLabelParser.parse(recognizedText: recognizedText)
            logFoodDestination = LogFoodDestination(
                draft: result.draft,
                reviewNotes: result.notes,
                previewImageData: image.jpegData(compressionQuality: 0.9)
            )
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
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
