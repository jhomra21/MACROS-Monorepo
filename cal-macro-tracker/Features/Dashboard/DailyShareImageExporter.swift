import SwiftUI

#if os(iOS)
import LinkPresentation
import UIKit

@MainActor
enum DailyShareImageExporter {
    private static let maximumRenderAttempts = 3

    /// `ImageRenderer` occasionally returns nil, so a failed render is retried before it is reported.
    static func exportImage(
        day: CalendarDay,
        snapshot: LogEntryDaySnapshot,
        goals: MacroGoalsSnapshot,
        size: ShareImageSize,
        detail: ShareDetail,
        colorScheme: ColorScheme
    ) throws -> UIImage {
        for _ in 0..<maximumRenderAttempts {
            if let image = renderImage(
                day: day, snapshot: snapshot, goals: goals, size: size, detail: detail, colorScheme: colorScheme
            ) {
                return image
            }
        }

        throw DailyShareImageExportError.renderingFailed
    }

    static func warmUpRenderingPipeline(colorScheme: ColorScheme) {
        _ = renderImage(
            day: CalendarDay(date: .now),
            snapshot: .empty,
            goals: .default,
            size: .story,
            detail: .macros,
            colorScheme: colorScheme
        )
    }

    private static func renderImage(
        day: CalendarDay,
        snapshot: LogEntryDaySnapshot,
        goals: MacroGoalsSnapshot,
        size: ShareImageSize,
        detail: ShareDetail,
        colorScheme: ColorScheme
    ) -> UIImage? {
        let content = DailyShareCardView(day: day, snapshot: snapshot, goals: goals, size: size, detail: detail)
            .environment(\.colorScheme, colorScheme)

        let renderer = ImageRenderer(content: content)
        renderer.scale = ShareImageSize.renderScale

        guard let image = renderer.uiImage else { return nil }

        return opaqueImage(from: image, colorScheme: colorScheme)
    }

    private static func opaqueImage(from image: UIImage, colorScheme: ColorScheme) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true
        let backgroundColor = UIColor.systemGroupedBackground.resolvedColor(
            with: UITraitCollection(userInterfaceStyle: colorScheme.userInterfaceStyle)
        )

        return UIGraphicsImageRenderer(size: image.size, format: format).image { context in
            backgroundColor.setFill()
            context.fill(CGRect(origin: .zero, size: image.size))
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}

private extension ColorScheme {
    var userInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .dark:
            .dark
        case .light:
            .light
        @unknown default:
            .unspecified
        }
    }
}

enum DailyShareImageExportError: Error {
    case renderingFailed
}

final class DashboardShareImageItemSource: NSObject, UIActivityItemSource {
    private let image: UIImage
    private let title: String
    private let savePhotoDataLock = NSLock()
    private var savePhotoJPEGData: Data?

    init(image: UIImage, title: String) {
        self.image = image
        self.title = title
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        image
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        if activityType == .saveToCameraRoll {
            return savePhotoItem()
        }

        return image
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        thumbnailImageForActivityType activityType: UIActivity.ActivityType?,
        suggestedSize size: CGSize
    ) -> UIImage? {
        thumbnailImage(suggestedSize: size)
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        metadata.imageProvider = NSItemProvider(object: image)
        return metadata
    }

    private func thumbnailImage(suggestedSize size: CGSize) -> UIImage {
        guard size.width > 0, size.height > 0 else { return image }

        let scale = min(size.width / image.size.width, size.height / image.size.height, 1)
        let thumbnailSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true

        return UIGraphicsImageRenderer(size: thumbnailSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: thumbnailSize))
        }
    }

    private func savePhotoItem() -> Any {
        savePhotoDataLock.lock()
        defer { savePhotoDataLock.unlock() }

        if let savePhotoJPEGData {
            return savePhotoJPEGData
        }

        guard let jpegData = ImageJPEGEncoder.jpegDataSynchronously(from: image, compressionQuality: 0.95) else {
            return image
        }

        savePhotoJPEGData = jpegData
        return jpegData
    }
}

/// Offers the caption only to activities that post it, so saving, copying or AirDropping the image stays image-only.
final class DashboardShareCaptionItemSource: NSObject, UIActivityItemSource {
    private let caption: String

    init(caption: String) {
        self.caption = caption
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        caption
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        switch activityType {
        case .saveToCameraRoll, .airDrop, .copyToPasteboard, .print, .assignToContact:
            nil
        default:
            caption
        }
    }
}

#endif
