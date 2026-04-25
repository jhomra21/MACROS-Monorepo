import SwiftUI

struct HistoryCalendarView: View {
    @Binding var selection: CalendarDay
    let maximumDay: CalendarDay

    var body: some View {
        DatePicker(
            "Select Day",
            selection: normalizedSelection,
            in: ...maximumDay.startDate,
            displayedComponents: .date
        )
        .datePickerStyle(.graphical)
        .labelsHidden()
    }

    private var normalizedSelection: Binding<Date> {
        Binding(
            get: {
                selection.startDate
            },
            set: { newValue in
                selection = CalendarDay(date: newValue)
            }
        )
    }
}
