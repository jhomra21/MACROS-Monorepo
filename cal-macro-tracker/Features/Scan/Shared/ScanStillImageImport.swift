#if os(iOS)
import PhotosUI
import SwiftUI
import UIKit

enum ScanStillImageImport {
    @MainActor
    static func loadSelectedPhoto(
        _ item: PhotosPickerItem,
        clearSelection: () -> Void,
        processImage: (UIImage) async -> Void,
        onError: (String) -> Void
    ) async {
        defer { clearSelection() }

        do {
            let image = try await ScanImageLoading.loadUIImage(from: item)
            await processImage(image)
        } catch {
            guard ScanCancellation.isCancellation(error) == false else { return }
            onError(error.localizedDescription)
        }
    }
}
#endif
