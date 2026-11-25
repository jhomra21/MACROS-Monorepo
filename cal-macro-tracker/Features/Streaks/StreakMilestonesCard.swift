import SwiftUI

/// Free Insights card: the five badges, streak numbers and this week's days, with the weekly flex day control.
struct StreakMilestonesCard: View {
    let today: CalendarDay

    @AppStorage(AppStorageKeys.streakFlexDays) private var flexDays = ""
    @ScaledMetric(relativeTo: .body) private var dotSize: CGFloat = 26

    var body: some View {
        LoggingStreakReader(today: today) { summary, earnedBadges in
            StreakPaletteReader { palette in
                InsightsCard(title: "Milestones", subtitle: nextBadgeText(summary: summary, earned: earnedBadges)) {
                    badgeRow(earned: earnedBadges, palette: palette)
                    statRow(summary: summary)
                    Divider()
                    weekSection(summary: summary, palette: palette)
                }
                .accessibilityIdentifier("milestones-card")
            }
        }
    }

    private func nextBadgeText(summary: LoggingStreakSummary, earned: [StreakBadge]) -> String {
        guard let next = StreakBadge.allCases.first(where: { !earned.contains($0) }) else {
            return "Every badge earned. They are yours to keep."
        }
        let remaining = next.days - summary.current
        return "Next: \(next.title) at \(next.days) days" + (summary.current > 0 ? ", \(remaining) to go." : ".")
    }

    private func badgeRow(earned: [StreakBadge], palette: MacroRingPalette) -> some View {
        HStack(spacing: 0) {
            ForEach(StreakBadge.allCases) { badge in
                StreakMedallionView(badge: badge, palette: palette, isEarned: earned.contains(badge), diameter: 56)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func statRow(summary: LoggingStreakSummary) -> some View {
        let stats = [
            ("Current streak", summary.current), ("Best streak", summary.best), ("Days logged", summary.totalLoggedDays)
        ]
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .top) {
                ForEach(stats, id: \.0) { stat($0.0, $0.1) }
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(stats, id: \.0) { stat($0.0, $0.1) }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func stat(_ title: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.title2.weight(.bold).monospacedDigit())
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func weekSection(summary: LoggingStreakSummary, palette: MacroRingPalette) -> some View {
        let week = summary.currentWeek
        let marks = FlexDayMarks.days(from: flexDays, calendar: today.resolvedCalendar)
        let markedDay = week.first { marks.contains($0.day) }?.day

        return VStack(alignment: .leading, spacing: 12) {
            Text("This week")
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 0) {
                ForEach(week, id: \.day) { entry in
                    dayDot(entry, palette: palette)
                        .frame(maxWidth: .infinity)
                }
            }
            flexMenu(week: week.map(\.day), markedDay: markedDay)
            Text("One flex day a week keeps your streak going. If you miss a day, the first one is used for you.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func dayDot(_ entry: LoggingStreakSummary.Day, palette: MacroRingPalette) -> some View {
        VStack(spacing: 6) {
            dot(for: entry.state, palette: palette)
                .frame(width: dotSize, height: dotSize)
            Text(entry.day.weekdayNarrowTitle)
                .font(.caption2)
                .foregroundStyle(entry.day == today ? .primary : .secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.day.weekdayAccessibilityTitle)
        .accessibilityValue(entry.state.accessibilityText)
    }

    @ViewBuilder
    private func dot(for state: LoggingStreakSummary.DayState, palette: MacroRingPalette) -> some View {
        switch state {
        case .logged:
            Circle().fill(palette.protein)
        case .flex:
            ZStack {
                Circle().stroke(palette.carbs, lineWidth: 2)
                Image(systemName: "leaf.fill")
                    .font(.system(size: dotSize * 0.45))
                    .foregroundStyle(palette.carbs)
            }
        case .missed:
            Circle().stroke(.tertiary, lineWidth: 2)
        case .future:
            Circle().fill(Color.secondary.opacity(0.14))
        }
    }

    private func flexMenu(week: [CalendarDay], markedDay: CalendarDay?) -> some View {
        Menu {
            ForEach(week.filter { $0 >= today }, id: \.self) { day in
                Button {
                    flexDays = FlexDayMarks.setting(day, inWeek: week, stored: flexDays)
                } label: {
                    if day == markedDay {
                        Label(day.weekdayName, systemImage: "checkmark")
                    } else {
                        Text(day.weekdayName)
                    }
                }
            }
            if markedDay != nil {
                Divider()
                Button("Remove flex day", role: .destructive) {
                    flexDays = FlexDayMarks.setting(nil, inWeek: week, stored: flexDays)
                }
            }
        } label: {
            Label(markedDay.map { "Flex day: \($0.weekdayName)" } ?? "Plan a flex day", systemImage: "leaf")
                .frame(minHeight: 32)
        }
        .menuStyle(.button)
        .buttonStyle(.bordered)
        .accessibilityIdentifier("flex-day-menu")
        .accessibilityHint("Choose a day this week that will not break your streak")
    }
}

private extension LoggingStreakSummary.DayState {
    var accessibilityText: String {
        switch self {
        case .logged: "Logged"
        case .flex: "Flex day"
        case .missed: "Not logged"
        case .future: "Not yet"
        }
    }
}

extension CalendarDay {
    var weekdayName: String {
        let style = Date.FormatStyle(
            date: .omitted, time: .omitted, locale: .current, calendar: resolvedCalendar, timeZone: timeZone
        ).weekday(.wide)
        return isToday ? "Today" : startDate.formatted(style)
    }
}
