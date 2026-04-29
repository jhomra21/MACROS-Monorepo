import SwiftUI

#if os(iOS)
import LinkPresentation
import UIKit

@MainActor
enum DailyShareImageExporter {
    static func exportImage(
        day: CalendarDay,
        snapshot: LogEntryDaySnapshot,
        goals: MacroGoalsSnapshot,
        colorScheme: ColorScheme
    ) throws -> UIImage {
        guard let image = renderImage(day: day, snapshot: snapshot, goals: goals, colorScheme: colorScheme) else {
            throw DailyShareImageExportError.renderingFailed
        }

        return image
    }

    static func warmUpRenderingPipeline(colorScheme: ColorScheme) {
        _ = renderImage(
            day: CalendarDay(date: .now),
            snapshot: .empty,
            goals: .default,
            colorScheme: colorScheme
        )
    }

    private static func renderImage(
        day: CalendarDay,
        snapshot: LogEntryDaySnapshot,
        goals: MacroGoalsSnapshot,
        colorScheme: ColorScheme
    ) -> UIImage? {
        let content = DailyShareCardView(day: day, snapshot: snapshot, goals: goals)
            .padding(8)
            .background(PlatformColors.groupedBackground)
            .environment(\.colorScheme, colorScheme)

        let renderer = ImageRenderer(content: content)
        renderer.scale = UIScreen.main.scale

        return renderer.uiImage
    }
}

enum DailyShareImageExportError: Error {
    case renderingFailed
}

struct ShareSheet: UIViewControllerRepresentable {
    let itemSource: DashboardShareImageItemSource

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [itemSource], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
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

#endif
