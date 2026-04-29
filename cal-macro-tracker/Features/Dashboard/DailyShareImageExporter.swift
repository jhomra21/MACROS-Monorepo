import SwiftUI

#if os(iOS)
import LinkPresentation
import OSLog
import UIKit

@MainActor
enum DailyShareImageExporter {
    private static let logger = Logger(subsystem: "juan-test.cal-macro-tracker", category: "DashboardShare")

    static func exportImage(
        day: CalendarDay,
        snapshot: LogEntryDaySnapshot,
        goals: MacroGoalsSnapshot,
        colorScheme: ColorScheme
    ) throws -> UIImage {
        let startedAt = Date()

        guard let image = renderImage(day: day, snapshot: snapshot, goals: goals, colorScheme: colorScheme) else {
            throw DailyShareImageExportError.renderingFailed
        }

        logger.debug("Share image export finished in \(Date().timeIntervalSince(startedAt), format: .fixed(precision: 3))s")
        return image
    }

    static func logSheetPresentationStarted(since requestStartedAt: Date) {
        logger.debug(
            "Share sheet presentation requested after \(Date().timeIntervalSince(requestStartedAt), format: .fixed(precision: 3))s"
        )
    }

    static func logShareControllerCreated(creationDuration: TimeInterval, totalDuration: TimeInterval) {
        logger.debug(
            "Share controller created in \(creationDuration, format: .fixed(precision: 3))s; total since tap \(totalDuration, format: .fixed(precision: 3))s"
        )
    }

    static func logShareControllerUpdated(totalDuration: TimeInterval) {
        logger.debug("Share controller updated after \(totalDuration, format: .fixed(precision: 3))s since tap")
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
    let item: DashboardShareImageItemSource
    let requestStartedAt: Date

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let startedAt = Date()
        let controller = UIActivityViewController(activityItems: [item], applicationActivities: nil)
        DailyShareImageExporter.logShareControllerCreated(
            creationDuration: Date().timeIntervalSince(startedAt),
            totalDuration: Date().timeIntervalSince(requestStartedAt)
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        DailyShareImageExporter.logShareControllerUpdated(
            totalDuration: Date().timeIntervalSince(requestStartedAt)
        )
    }
}

final class DashboardShareImageItemSource: NSObject, UIActivityItemSource {
    private let image: UIImage
    private let title: String

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
        image
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
}
#endif
