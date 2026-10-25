import SwiftData
import SwiftUI

struct WeightScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WeightEntry.recordedAt, order: .reverse) private var entries: [WeightEntry]
    @Query private var profiles: [BodyProfile]
    @State private var isPresentingEntry = false

    private var unitSystem: GoalUnitSystem { BodyProfile.activeRecord(from: profiles)?.unitSystem ?? .metric }
    private var unitLabel: String { unitSystem == .metric ? "kg" : "lb" }

    var body: some View {
        List {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No weight entries", systemImage: "scalemass", description: Text("Log a weight to start tracking your progress."))
            } else {
                ForEach(groupedEntries, id: \.week) { group in
                    Section(group.week.formatted(.dateTime.month(.abbreviated).day())) {
                        ForEach(group.entries, id: \.persistentModelID) { entry in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.recordedAt, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                                    Text(entry.source == .healthKit ? "Apple Health" : "Manual")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(displayWeight(entry.weightKg), specifier: "%.1f") \(unitLabel)")
                                    .font(.headline.monospacedDigit())
                            }
                        }
                        .onDelete { offsets in delete(group.entries, offsets: offsets) }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            BottomPinnedActionBar(title: "Log weight", systemImage: "plus", isDisabled: false) {
                isPresentingEntry = true
            }
        }
        .navigationTitle("Weight")
        .inlineNavigationTitle()
        .sheet(isPresented: $isPresentingEntry) { WeightEntrySheet() }
    }

    private var groupedEntries: [(week: Date, entries: [WeightEntry])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: entries) { entry in
            calendar.dateInterval(of: .weekOfYear, for: entry.recordedAt)?.start ?? calendar.startOfDay(for: entry.recordedAt)
        }
        return groups.keys.sorted(by: >).map { ($0, groups[$0] ?? []) }
    }

    private func displayWeight(_ kilograms: Double) -> Double {
        unitSystem == .metric ? kilograms : GoalCalculator.pounds(fromKg: kilograms)
    }

    private func delete(_ group: [WeightEntry], offsets: IndexSet) {
        for index in offsets {
            try? WeightRepository(modelContext: modelContext).delete(group[index])
        }
    }
}
