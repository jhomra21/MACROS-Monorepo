#if os(iOS)
import UIKit

enum ImageJPEGEncoder {
    static func jpegData(from image: UIImage, compressionQuality: CGFloat) async -> Data? {
        await Task.detached(priority: .utility) {
            image.jpegData(compressionQuality: compressionQuality)
        }.value
    }

    static func jpegDataSynchronously(from image: UIImage, compressionQuality: CGFloat) -> Data? {
        image.jpegData(compressionQuality: compressionQuality)
    }
}
#endif
