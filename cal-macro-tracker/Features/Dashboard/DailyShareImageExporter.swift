import SwiftUI

#if os(iOS)
import UIKit

@MainActor
enum DailyShareImageExporter {
    static func exportPNG(
        day: CalendarDay,
        snapshot: LogEntryDaySnapshot,
        goals: MacroGoalsSnapshot,
        colorScheme: ColorScheme
    ) throws -> URL {
        try cleanUpGeneratedFiles()

        let content = DailyShareCardView(day: day, snapshot: snapshot, goals: goals)
            .environment(\.colorScheme, colorScheme)
            .padding(8)
            .background(PlatformColors.groupedBackground)

        let renderer = ImageRenderer(content: content)
        renderer.scale = UIScreen.main.scale

        guard let image = renderer.uiImage, let data = image.pngData() else {
            throw DailyShareImageExportError.renderingFailed
        }

        let fileURL = generatedFilesDirectory().appendingPathComponent(fileName(for: day))
        try data.write(to: fileURL, options: [.atomic])
        return fileURL
    }

    private static func fileName(for day: CalendarDay) -> String {
        let date = day.startDate.formatted(
            .iso8601.year().month().day().dateSeparator(.dash)
        )
        return "macros-\(date).png"
    }

    private static func cleanUpGeneratedFiles() throws {
        let directory = generatedFilesDirectory()
        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )

        for fileURL in fileURLs
        where fileURL.lastPathComponent.hasPrefix("macros-")
            && fileURL.pathExtension == "png"
        {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    private static func generatedFilesDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "macro-share",
            isDirectory: true
        )
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

enum DailyShareImageExportError: Error {
    case renderingFailed
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
