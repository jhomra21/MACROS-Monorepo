import SwiftData
import SwiftUI

struct HistoryScreen: View {
    @Query private var goals: [DailyGoals]

    @State private var selectedDate = Date().startOfDayValue

    private var currentGoals: DailyGoals {
        goals.first ?? DailyGoals()
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
                .background(PlatformColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                LogEntryDaySnapshotReader(date: selectedDate) { snapshot in
                    MacroRingView(totals: snapshot.totals, goals: currentGoals)

                    LogEntryListSection(
                        title: selectedDate.dayTitle,
                        emptyTitle: "Nothing logged",
                        emptySystemImage: "calendar.badge.exclamationmark",
                        emptyDescription: "No entries were saved for this date.",
                        entries: snapshot.entries,
                        emptyVerticalPadding: 20
                    )
                }
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .background(PlatformColors.groupedBackground)
        .navigationTitle("History")
    }
}
