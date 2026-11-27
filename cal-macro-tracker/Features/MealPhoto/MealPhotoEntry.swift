import PhotosUI
import SwiftUI
import UIKit

struct MealPhotoCapture: Identifiable, Hashable {
    let id = UUID()
    let image: UIImage

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// The "Scan a meal" entry in Add Food. Pro people scan freely; everyone else gets a small free trial, then the paywall.
struct MealPhotoEntry: View {
    @Environment(AppEntitlements.self) private var entitlements
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(AppStorageKeys.mealPhotoTrialScansUsed) private var trialScansUsed = 0

    let onCapture: (UIImage) -> Void

    @State private var isCameraPresented = false
    @State private var isLibraryPresented = false
    @State private var isPaywallPresented = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var errorMessage: String?

    private var hasPro: Bool { entitlements.canUse(.mealPhotoScan) }
    private var remaining: Int { MealPhotoTrial.remaining(used: trialScansUsed) }

    var body: some View {
        Group {
            if MealPhotoTrial.canScan(hasPro: hasPro, used: trialScansUsed) {
                Menu {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button("Take Photo", systemImage: "camera") { isCameraPresented = true }
                    }
                    Button("Choose from Library", systemImage: "photo.on.rectangle") { openLibrary() }
                } label: {
                    label
                }
            } else {
                Button {
                    isPaywallPresented = true
                } label: {
                    label
                }
                .accessibilityHint("Opens the Pro paywall")
            }
        }
        .buttonStyle(.glass)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .accessibilityIdentifier("scan-meal")
        .photosPicker(isPresented: $isLibraryPresented, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task { await load(item) }
        }
        .fullScreenCover(isPresented: $isCameraPresented) {
            CameraImagePicker(
                onImagePicked: { image in
                    isCameraPresented = false
                    onCapture(image)
                },
                onCancel: { isCameraPresented = false }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $isPaywallPresented) {
            ProPaywallSheet(context: .mealPhoto)
        }
        .errorBanner(message: $errorMessage)
    }

    private var label: some View {
        let layout =
            dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout(spacing: 10))
        return layout {
            Label("Scan a meal", systemImage: "fork.knife")
                .font(.headline)
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
            if !hasPro {
                HStack(spacing: 8) {
                    Text("Pro")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.18), in: .capsule)
                        .foregroundStyle(Color.accentColor)
                    Text(remaining == 1 ? "1 free scan left" : "\(remaining) free scans left")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(.horizontal, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        guard !hasPro else { return "Scan a meal" }
        return "Scan a meal, Pro feature, \(remaining) free \(remaining == 1 ? "scan" : "scans") left"
    }

    private func openLibrary() {
        #if DEBUG
        // The simulator cannot script the system photo picker, so UI tests supply a still instead.
        if let path = UITestFixture.current?.cameraImagePath, let image = UIImage(contentsOfFile: path) {
            onCapture(image)
            return
        }
        #endif
        isLibraryPresented = true
    }

    private func load(_ item: PhotosPickerItem) async {
        defer { selectedPhoto = nil }
        do {
            onCapture(try await ScanImageLoading.loadUIImage(from: item))
        } catch {
            guard !ScanCancellation.isCancellation(error) else { return }
            errorMessage = error.localizedDescription
        }
    }
}
