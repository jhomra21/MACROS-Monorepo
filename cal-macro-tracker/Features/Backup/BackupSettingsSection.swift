import SwiftData
import SwiftUI
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#endif

struct BackupSettingsSection: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppEntitlements.self) private var entitlements
    @Environment(SharingSyncService.self) private var sharingSyncService
    @State private var presentation: BackupPresentation?
    @State private var isImportingFile = false
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        Section {
            if entitlements.canUse(.backup) {
                Button("Export backup") { exportBackup() }
                    .disabled(isWorking)
                Button("Export logs as CSV") { exportCSV() }
                    .disabled(isWorking)
                Button("Import backup") { isImportingFile = true }
                    .disabled(isWorking)
                    .fileImporter(
                        isPresented: $isImportingFile, allowedContentTypes: [.json],
                        allowsMultipleSelection: false, onCompletion: importFile
                    )
            } else {
                Button {
                    presentation = .paywall(.backup)
                } label: {
                    Label("Export backup", systemImage: "lock.fill")
                }
                Button {
                    presentation = .paywall(.backup)
                } label: {
                    Label("Export logs as CSV", systemImage: "lock.fill")
                }
                Button {
                    presentation = .paywall(.backup)
                } label: {
                    Label("Import backup", systemImage: "lock.fill")
                }
            }
        } header: {
            Text("Backup")
                .sheet(item: $presentation) { presentation in
                    switch presentation {
                    case let .importSummary(backup, unmatchedCount):
                        BackupImportSummarySheet(
                            backup: backup,
                            unmatchedMealItemCount: unmatchedCount,
                            onImport: { mode in
                                try await importBackup(backup, mode: mode)
                            },
                            errorMessage: $errorMessage
                        )
                    case let .share(url):
                        BackupFileShareSheet(url: url)
                    case let .paywall(context):
                        ProPaywallSheet(context: context)
                    }
                }
                .errorBanner(message: $errorMessage)
        } footer: {
            Text("Backups contain your saved data and can be shared or stored in Files.")
        }
    }

    private func importFile(_ result: Result<[URL], Error>) {
        let container = modelContext.container
        Task {
            do {
                guard let url = try result.get().first else { return }
                let backup = try await Task.detached {
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                    return try BackupImporter.decode(Data(contentsOf: url))
                }.value
                let exporter = await BackupExportActor.background(container: container)
                let count = try await exporter.unmatchedMealItemCount(in: backup)
                presentation = .importSummary(backup, count)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func exportBackup() {
        let container = modelContext.container
        let settings = BackupSettings.current()
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                let exporter = await BackupExportActor.background(container: container)
                let data = try await exporter.export(settings: settings)
                let url = try await Task.detached { try Self.makeShareItem(data: data, extension: "json") }.value
                presentation = .share(url)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func exportCSV() {
        let container = modelContext.container
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                let exporter = await BackupExportActor.background(container: container)
                let data = try await exporter.exportCSV()
                let url = try await Task.detached { try Self.makeShareItem(data: data, extension: "csv") }.value
                presentation = .share(url)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    private func importBackup(
        _ backup: MACROSBackup,
        mode: BackupImportMode
    ) async throws {
        try await BackupImporter.apply(backup, to: modelContext.container, mode: mode)
        WidgetTimelineReloader.reloadMacroWidgets()
        sharingSyncService.syncAfterDailyTotalsChange(container: modelContext.container)
        NotificationCenter.default.post(name: .remindersDidChange, object: nil)
        presentation = nil
    }

    nonisolated private static func makeShareItem(data: Data, extension fileExtension: String) throws -> URL {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        let prefix = fileExtension == "csv" ? "MACROS-logs" : "MACROS-backup"
        let filename = "\(prefix)-\(formatter.string(from: .now)).\(fileExtension)"
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MACROS-Backup", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }
}

private enum BackupPresentation: Identifiable {
    case importSummary(MACROSBackup, Int)
    case share(URL)
    case paywall(ProPaywallContext)

    var id: String {
        switch self {
        case let .importSummary(backup, _): "import-\(backup.id.timeIntervalSinceReferenceDate)"
        case let .share(url): "share-\(url.path)"
        case let .paywall(context): "paywall-\(context.rawValue)"
        }
    }
}

#if os(iOS)
private struct BackupFileShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#endif
