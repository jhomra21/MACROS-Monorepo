import SwiftData
import SwiftUI

struct HistoryScreen: View {
    @Query(sort: \LogEntry.dateLogged, order: .reverse) private var entries: [LogEntry]
    @Query private var goals: [DailyGoals]

    @State private var selectedDate = Date().startOfDayValue

    private var currentGoals: DailyGoals {
        goals.first ?? DailyGoals()
    }

    private var selectedEntries: [LogEntry] {
        entries.filter { Calendar.current.isDate($0.dateLogged, inSameDayAs: selectedDate) }
    }

    private var totals: NutritionSnapshot {
        NutritionMath.totals(for: selectedEntries)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                DatePicker(
                    "Select Day",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                MacroRingView(totals: totals, goals: currentGoals)

                LogEntryListSection(
                    title: selectedDate.dayTitle,
                    emptyTitle: "Nothing logged",
                    emptySystemImage: "calendar.badge.exclamationmark",
                    emptyDescription: "No entries were saved for this date.",
                    entries: selectedEntries,
                    emptyVerticalPadding: 20
                )
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .background(PlatformColors.groupedBackground)
        .navigationTitle("History")
    }
}
