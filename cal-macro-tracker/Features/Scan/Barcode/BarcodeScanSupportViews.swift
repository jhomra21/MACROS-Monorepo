#if os(iOS)
import PhotosUI
import SwiftUI

struct BarcodeScanOptionsList: View {
    let canScanLive: Bool
    let canUseCamera: Bool
    let isLoading: Bool
    @Binding var selectedPhoto: PhotosPickerItem?
    let onOpenLiveScanner: () -> Void
    let onOpenCamera: () -> Void

    var body: some View {
        List {
            Section("Scan Barcode") {
                if canScanLive {
                    Button("Scan Live", action: onOpenLiveScanner)
                } else {
                    Text("Live barcode scanning is not available on this device right now.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Choose Barcode Photo", systemImage: "photo")
                }

                if canUseCamera {
                    Button("Take Barcode Photo", action: onOpenCamera)
                }
            }

            if isLoading {
                Section {
                    HStack {
                        ProgressView()
                        Text("Looking up product…")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Scan Barcode")
        .inlineNavigationTitle()
    }
}

struct BarcodeLiveScannerSheet: View {
    let onBarcodeScanned: (String) -> Void
    let onStartFailed: (Error) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            BarcodeLiveScannerView(onBarcodeScanned: onBarcodeScanned, onStartFailed: onStartFailed)
                .ignoresSafeArea()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: onCancel)
                    }
                }
        }
    }
}
#endif
