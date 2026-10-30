import SwiftUI

struct BackupImportSummarySheet: View {
    let backup: MACROSBackup
    let unmatchedMealItemCount: Int
    let onImport: (BackupImportMode) async throws -> Void
    @Binding var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    @State private var isImporting = false
    @State private var importTask: Task<Void, Never>?
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
                    if unmatchedMealItemCount > 0 {
                        Text("\(unmatchedMealItemCount) meal items could not be matched to bundled foods")
                    }
                    if isImporting {
                        ProgressView("Importing backup…")
                    }
                } footer: {
                    Text("Merge keeps existing rows with matching IDs. Replace removes your saved data before importing this backup.")
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 10) {
                    AppAccentActionButton(
                        title: "Merge", systemImage: "square.and.arrow.down", isCompact: false,
                        action: { startImport(.merge) }
                    )
                    Button(role: .destructive) {
                        confirmingReplace = true
                    } label: {
                        Label("Replace All Data", systemImage: "trash")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.glass)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .disabled(isImporting)
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
                Button("Replace All Data", role: .destructive) { startImport(.replace) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your current logs, meals, foods, goals, profile, and weight entries will be removed. Common foods stay available.")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isImporting)
        .onDisappear { importTask?.cancel() }
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

    private func startImport(_ mode: BackupImportMode) {
        isImporting = true
        importTask = Task {
            defer {
                isImporting = false
                importTask = nil
            }

            do {
                try await onImport(mode)
                dismiss()
            } catch is CancellationError {
            } catch {
                errorMessage = error.localizedDescription
                dismiss()
            }
        }
    }
}
