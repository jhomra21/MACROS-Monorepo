#if os(iOS)
import UIKit

/// Shrinks a photo to what the Worker accepts: JPEG, longest side at most 1024 px, at most 1.5 MB.
enum MealPhotoImagePreparer {
    nonisolated static let maximumSide: CGFloat = 1_024
    nonisolated private static let qualities: [CGFloat] = [0.8, 0.6, 0.4, 0.25]

    nonisolated static func jpegData(from image: UIImage) -> Data? {
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, maximumSide / longest)
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        // Drawing applies the photo's orientation, so the upload is upright.
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        for quality in qualities {
            if let data = resized.jpegData(compressionQuality: quality), data.count <= MealPhotoClient.maximumImageBytes {
                return data
            }
        }
        return nil
    }
}
#endif
