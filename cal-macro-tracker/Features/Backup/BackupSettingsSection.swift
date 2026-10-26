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
    @Query private var logEntries: [LogEntry]
    @State private var presentation: BackupPresentation?
    @State private var isImportingFile = false
    @State private var isWorking = false
    @State private var importProgress: String?
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
            if isWorking {
                ProgressView(importProgress ?? "Importing backup…")
            }
        } header: {
            Text("Backup")
        } footer: {
            Text("Backups contain your saved data and can be shared or stored in Files.")
        }
        .fileImporter(
            isPresented: $isImportingFile,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false,
            onCompletion: importFile
        )
        .sheet(item: $presentation) { presentation in
            switch presentation {
            case let .importSummary(backup):
                BackupImportSummarySheet(
                    backup: backup,
                    isImporting: $isWorking,
                    onImport: { mode in
                        Task { await importBackup(backup, mode: mode) }
                    }
                )
            case let .share(url):
                BackupFileShareSheet(url: url)
            case let .paywall(context):
                ProPaywallSheet(context: context).presentationDetents([.medium, .large])
            }
        }
        .errorBanner(message: $errorMessage)
    }

    private func exportBackup() {
        do {
            let backup = try BackupExporter.makeBackup(from: modelContext)
            let data = try BackupExporter.encode(backup)
            presentation = .share(try makeShareItem(data: data, extension: "json"))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func exportCSV() {
        do {
            let data = Data(BackupExporter.csv(for: logEntries).utf8)
            presentation = .share(try makeShareItem(data: data, extension: "csv"))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func importFile(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }
            presentation = .importSummary(try BackupImporter.decode(Data(contentsOf: url)))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func importBackup(_ backup: MACROSBackup, mode: BackupImportMode) async {
        isWorking = true
        defer {
            isWorking = false
            importProgress = nil
        }
        await Task.yield()
        do {
            try BackupImporter.apply(backup, to: modelContext.container, mode: mode) {
                importProgress = $0
            }
            presentation = nil
            sharingSyncService.syncAfterDailyTotalsChange(container: modelContext.container)
            NotificationCenter.default.post(name: .remindersDidChange, object: nil)
        } catch {
            presentation = nil
            errorMessage = error.localizedDescription
        }
    }

    private func makeShareItem(data: Data, extension fileExtension: String) throws -> URL {
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
    case importSummary(MACROSBackup)
    case share(URL)
    case paywall(ProPaywallContext)

    var id: String {
        switch self {
        case let .importSummary(backup): "import-\(backup.id.timeIntervalSinceReferenceDate)"
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
