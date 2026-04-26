import SwiftUI

struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.foodName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("\(entry.quantitySummary) • \(entry.dateLogged.timeTitle)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text("\(entry.caloriesConsumed.roundedForDisplay) kcal")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                Text(
                    "P \(entry.proteinConsumed.roundedForDisplay) • C \(entry.carbsConsumed.roundedForDisplay) • F \(entry.fatConsumed.roundedForDisplay)"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 16)
    }
}
