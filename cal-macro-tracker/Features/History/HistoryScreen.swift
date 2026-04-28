import SwiftData
import SwiftUI

struct HistoryScreen: View {
    @Environment(AppDayContext.self) private var dayContext
    @Query private var goals: [DailyGoals]

    @State private var daySelection = AppDaySelection(today: CalendarDay(date: .now))
    @State private var showsCalendar = false

    private var currentGoals: MacroGoalsSnapshot {
        MacroGoalsSnapshot(goals: DailyGoals.activeRecord(from: goals))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HistoryWeekCard(
                    selectedDay: selectedDayBinding,
                    showsCalendar: $showsCalendar,
                    goals: currentGoals,
                    maximumDay: dayContext.today
                )

                LogEntryDaySnapshotReader(day: daySelection.selectedDay) { snapshot in
                    CompactMacroSummaryView(totals: snapshot.totals, goals: currentGoals, horizontalPadding: 0)

                    LogEntryListSection(
                        title: daySelection.selectedDay.dayTitle,
                        emptyTitle: "Nothing logged",
                        emptySystemImage: "calendar.badge.exclamationmark",
                        emptyDescription: "No entries were saved for this date.",
                        entries: snapshot.entries,
                        emptyVerticalPadding: 20,
                        showsHeader: false
                    )
                }
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .background(PlatformColors.groupedBackground)
        .navigationTitle("")
        .inlineNavigationTitle()
        .onAppear {
            guard daySelection.followsCurrentDay else { return }
            daySelection.resetToToday(dayContext.today)
        }
        .onChange(of: dayContext.today) { oldToday, newToday in
            daySelection.syncToday(from: oldToday, to: newToday)
        }
        .toolbar {
            ToolbarItem(placement: .appTopBarLeading) {
                Text(historyToolbarTitle)
                    .appTopBarTitleStyle()
            }
            .sharedBackgroundVisibility(.hidden)

            ToolbarItem(placement: .appTopBarTrailing) {
                calendarToolbarButton
                    .padding(.horizontal, 4)
            }
        }
    }

    private func toggleCalendar() {
        withAnimation(.easeInOut(duration: 0.24)) {
            showsCalendar.toggle()
        }
    }

    private var selectedDayBinding: Binding<CalendarDay> {
        Binding(
            get: { daySelection.selectedDay },
            set: { updateSelectedDay($0) }
        )
    }

    private var historyToolbarTitle: String {
        daySelection.selectedDay.topBarTitle
    }

    private func updateSelectedDay(_ newDay: CalendarDay) {
        daySelection.select(newDay, today: dayContext.today)
    }

    private var calendarToolbarButton: some View {
        Button(action: toggleCalendar) {
            Image(systemName: "calendar")
                .appTopBarIconStyle()
        }
        .accessibilityLabel("Toggle calendar")
        .accessibilityValue(showsCalendar ? "Expanded" : "Collapsed")
    }
}

private struct HistoryWeekCard: View {
    @Binding var selectedDay: CalendarDay
    @Binding var showsCalendar: Bool
    let goals: MacroGoalsSnapshot
    let maximumDay: CalendarDay

    var body: some View {
        cardContent
            .appGlassRoundedRect(cornerRadius: showsCalendar ? 28 : 24, interactive: false)
            .clipShape(RoundedRectangle(cornerRadius: showsCalendar ? 28 : 24, style: .continuous))
            .animation(.easeInOut(duration: 0.24), value: showsCalendar)
    }

    @ViewBuilder
    private var cardContent: some View {
        if #available(iOS 26, macOS 26, *) {
            GlassEffectContainer(spacing: 12) {
                content
            }
        } else {
            content
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            HistoryWeekStrip(selectedDay: $selectedDay, goals: goals, maximumDay: maximumDay)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(height: 0.5)
                .padding(.horizontal, 16)

            if showsCalendar {
                calendarSection
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
    }

    private var calendarSection: some View {
        HistoryCalendarView(selection: $selectedDay, maximumDay: maximumDay)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
    }
}

private struct HistoryWeekStrip: View {
    @Binding var selectedDay: CalendarDay
    let goals: MacroGoalsSnapshot
    let maximumDay: CalendarDay

    @Query private var entries: [LogEntry]

    init(selectedDay: Binding<CalendarDay>, goals: MacroGoalsSnapshot, maximumDay: CalendarDay) {
        _selectedDay = selectedDay
        self.goals = goals
        self.maximumDay = maximumDay

        let weekDays = selectedDay.wrappedValue.weekDays
        let weekStart = weekDays.first?.startDate ?? selectedDay.wrappedValue.startDate
        let weekEnd =
            Calendar.current.date(
                byAdding: .day,
                value: 1,
                to: weekDays.last?.startDate ?? selectedDay.wrappedValue.startDate
            ) ?? selectedDay.wrappedValue.startDate
        _entries = Query(LogEntryQuery.descriptor(start: weekStart, end: weekEnd))
    }

    private var weekDays: [CalendarDay] {
        selectedDay.weekDays
    }

    var body: some View {
        let days = weekDays
        let snapshotsByDay = LogEntryDaySummary.snapshotsByDay(for: entries, matching: days)

        HStack(alignment: .top, spacing: 0) {
            ForEach(days, id: \.self) { day in
                let isSelectable = day.startDate <= maximumDay.startDate

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedDay = day
                    }
                } label: {
                    HistoryWeekdayCell(
                        day: day,
                        isSelected: day == selectedDay,
                        isEnabled: isSelectable,
                        snapshot: snapshotsByDay[day] ?? .empty,
                        goals: goals
                    )
                }
                .buttonStyle(.plain)
                .disabled(!isSelectable)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct HistoryWeekdayCell: View {
    let day: CalendarDay
    let isSelected: Bool
    let isEnabled: Bool
    let snapshot: LogEntryDaySnapshot
    let goals: MacroGoalsSnapshot

    var body: some View {
        VStack(spacing: 8) {
            Text(day.weekdayNarrowTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? .white : .secondary)
                .frame(width: 32, height: 32)
                .background {
                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                    }
                }

            WeekdayMacroRingView(totals: snapshot.totals, goals: goals)
        }
        .frame(maxWidth: .infinity)
        .opacity(isEnabled ? 1 : 0.4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(day.weekdayAccessibilityTitle))
        .accessibilityValue(Text("\(snapshot.entries.count) logged items"))
    }
}
