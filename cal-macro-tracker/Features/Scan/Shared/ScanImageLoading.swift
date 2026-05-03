#if os(iOS)
import CoreImage
import ImageIO
import PhotosUI
import SwiftUI
import UIKit

struct ScanVisionImage {
    let cgImage: CGImage
    let orientation: CGImagePropertyOrientation
}

struct SendableScanImage: @unchecked Sendable {
    let value: UIImage
}

struct ScanImageLoading {
    nonisolated private static let maximumStillImagePixelSize: CGFloat = 2_400
    nonisolated private static let ciContext = CIContext()

    static func loadUIImage(from item: PhotosPickerItem) async throws -> UIImage {
        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw NSError(
                domain: "ScanImageLoading",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to load the selected image."]
            )
        }

        return try loadUIImage(from: data)
    }

    nonisolated static func loadUIImage(from data: Data) throws -> UIImage {
        guard let image = downsampledUIImage(from: data, maximumPixelSize: maximumStillImagePixelSize) ?? UIImage(data: data) else {
            throw NSError(domain: "ScanImageLoading", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to load the selected image."])
        }

        return image
    }

    nonisolated static func makeVisionImage(from image: UIImage) throws -> ScanVisionImage {
        ScanVisionImage(
            cgImage: try makeCGImage(from: image),
            orientation: CGImagePropertyOrientation(image.imageOrientation)
        )
    }
    nonisolated static func makeCGImage(from image: UIImage) throws -> CGImage {
        if let cgImage = image.cgImage {
            return cgImage
        }

        guard let ciImage = image.ciImage else {
            throw NSError(
                domain: "ScanImageLoading", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Unable to prepare the selected image for scanning."])
        }

        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            throw NSError(
                domain: "ScanImageLoading", code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Unable to prepare the selected image for scanning."])
        }

        return cgImage
    }

    nonisolated private static func downsampledUIImage(from data: Data, maximumPixelSize: CGFloat) -> UIImage? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options) else { return nil }

        let downsampleOptions =
            [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize
            ] as CFDictionary

        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) else { return nil }
        return UIImage(cgImage: image)
    }
}

private extension CGImagePropertyOrientation {
    nonisolated init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up:
            self = .up
        case .upMirrored:
            self = .upMirrored
        case .down:
            self = .down
        case .downMirrored:
            self = .downMirrored
        case .left:
            self = .left
        case .leftMirrored:
            self = .leftMirrored
        case .right:
            self = .right
        case .rightMirrored:
            self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
}
#endif
