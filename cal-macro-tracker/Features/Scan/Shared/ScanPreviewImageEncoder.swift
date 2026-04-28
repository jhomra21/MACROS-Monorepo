#if os(iOS)
import SwiftUI
import UIKit

enum ScanPreviewImageEncoder {
    static func jpegData(from image: UIImage, compressionQuality: CGFloat) async -> Data? {
        await Task.detached(priority: .utility) {
            image.jpegData(compressionQuality: compressionQuality)
        }.value
    }
}
#endif
