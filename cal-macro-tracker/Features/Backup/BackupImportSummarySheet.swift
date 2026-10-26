import SwiftUI

struct BackupImportSummarySheet: View {
    let backup: MACROSBackup
    @Binding var isImporting: Bool
    let onImport: (BackupImportMode) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingReplace = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Backup") {
                    LabeledContent("App version", value: backup.appVersion)
                    if let dateRange {
                        LabeledContent("Date range", value: dateRange)
                    }
                }
                Section("Data to import") {
                    countRow("Goals", backup.goals.count)
                    countRow("Body profiles", backup.bodyProfile.count)
                    countRow("Foods", backup.foods.count)
                    countRow("Meals", backup.meals.count)
                    countRow("Log entries", backup.logEntries.count)
                    countRow("Weight entries", backup.weightEntries.count)
                }
                Section {
                    if isImporting {
                        ProgressView("Importing backup…")
                    } else {
                        Button("Merge") { onImport(.merge) }
                        Button("Replace All Data", role: .destructive) { confirmingReplace = true }
                    }
                } footer: {
                    Text("Merge keeps existing rows with matching IDs. Replace removes your saved data before importing this backup.")
                }
            }
            .navigationTitle("Import Backup")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isImporting)
                }
            }
            .confirmationDialog(
                "Replace all saved data?",
                isPresented: $confirmingReplace,
                titleVisibility: .visible
            ) {
                Button("Replace All Data", role: .destructive) { onImport(.replace) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your current logs, meals, foods, goals, profile, and weight entries will be removed. Common foods stay available.")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var dateRange: String? {
        let dates = backup.logEntries.map(\.dateLogged) + backup.weightEntries.map(\.recordedAt)
        guard let first = dates.min(), let last = dates.max() else { return nil }
        let formatter = Date.FormatStyle(date: .abbreviated, time: .omitted)
        return first.formatted(formatter) == last.formatted(formatter)
            ? first.formatted(formatter)
            : "\(first.formatted(formatter)) – \(last.formatted(formatter))"
    }

    private func countRow(_ title: String, _ count: Int) -> some View {
        LabeledContent(title, value: count.formatted())
    }
}
