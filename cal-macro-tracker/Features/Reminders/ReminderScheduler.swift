import Foundation
import SwiftData
import UserNotifications

struct ReminderDefinition: Equatable {
    let title: String
    let hour: Int
    let minute: Int
    let onlyIfNothingLogged: Bool
}

enum ReminderScheduler {
    static func resolveReminders(
        free: ReminderDefinition?,
        pro: [ReminderDefinition],
        hasPro: Bool
    ) -> [ReminderDefinition] {
        var scheduledTimes: Set<Int> = []
        let candidates = hasPro ? pro + [free].compactMap { $0 } : [free].compactMap { $0 }
        return candidates.filter { reminder in
            let minuteOfDay = reminder.hour * 60 + reminder.minute
            return scheduledTimes.insert(minuteOfDay).inserted
        }
        .prefix(hasPro ? 3 : 1)
        .map { $0 }
    }

    static func upcomingDays(
        from date: Date,
        count: Int,
        loggedDates: [Date],
        calendar: Calendar = .current
    ) -> [Date] {
        guard count > 0 else { return [] }
        let loggedDays = Set(loggedDates.map(calendar.startOfDay(for:)))
        return (0..<count).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: date)) else {
                return nil
            }
            return loggedDays.contains(day) ? nil : day
        }
    }

    @MainActor
    static func refresh(container: ModelContainer, hasPro: Bool, calendar: Calendar = .current) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let defaults = UserDefaults.standard
        let old = await center.pendingNotificationRequests()
        for request in old where request.identifier.hasPrefix("reminder.daily.") {
            center.removePendingNotificationRequests(withIdentifiers: [request.identifier])
        }
        for request in old where request.identifier.hasPrefix("reminder.pro.") {
            center.removePendingNotificationRequests(withIdentifiers: [request.identifier])
        }
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        let context = container.mainContext
        let entries = (try? context.fetch(FetchDescriptor<LogEntry>())) ?? []
        let days = Self.upcomingDays(from: .now, count: 7, loggedDates: [], calendar: calendar)
        let unloggedDays = Self.upcomingDays(
            from: .now,
            count: 7,
            loggedDates: entries.map(\.dateLogged),
            calendar: calendar
        )
        let freeReminder =
            defaults.bool(forKey: AppStorageKeys.reminderEnabled)
            ? ReminderDefinition(
                title: "Log today's meals",
                hour: Self.hour(forKey: AppStorageKeys.reminderHour, default: 20),
                minute: Self.minute(forKey: AppStorageKeys.reminderMinute),
                onlyIfNothingLogged: true
            )
            : nil
        let proReminders = [
            defaults.bool(forKey: AppStorageKeys.reminderBreakfastEnabled)
                ? ReminderDefinition(
                    title: "Breakfast",
                    hour: Self.hour(forKey: AppStorageKeys.reminderBreakfastHour, default: 8),
                    minute: Self.minute(forKey: AppStorageKeys.reminderBreakfastMinute),
                    onlyIfNothingLogged: false
                ) : nil,
            defaults.bool(forKey: AppStorageKeys.reminderLunchEnabled)
                ? ReminderDefinition(
                    title: "Lunch",
                    hour: Self.hour(forKey: AppStorageKeys.reminderLunchHour, default: 12),
                    minute: Self.minute(forKey: AppStorageKeys.reminderLunchMinute),
                    onlyIfNothingLogged: false
                ) : nil,
            defaults.bool(forKey: AppStorageKeys.reminderDinnerEnabled)
                ? ReminderDefinition(
                    title: "Dinner",
                    hour: Self.hour(forKey: AppStorageKeys.reminderDinnerHour, default: 18),
                    minute: Self.minute(forKey: AppStorageKeys.reminderDinnerMinute),
                    onlyIfNothingLogged: false
                ) : nil,
            defaults.bool(forKey: AppStorageKeys.reminderSmartEveningEnabled)
                ? ReminderDefinition(title: "Evening check-in", hour: 20, minute: 0, onlyIfNothingLogged: true)
                : nil
        ].compactMap { $0 }

        let reminders = Self.resolveReminders(free: freeReminder, pro: proReminders, hasPro: hasPro)
        for reminder in reminders {
            let scheduledDays = reminder.onlyIfNothingLogged ? unloggedDays : days
            await schedule(
                title: reminder.title,
                hour: reminder.hour,
                minute: reminder.minute,
                prefix: hasPro ? "reminder.pro.\(reminder.title.lowercased())" : "reminder.daily",
                days: scheduledDays,
                calendar: calendar,
                center: center)
        }
    }

    private static func schedule(
        title: String,
        hour: Int,
        minute: Int,
        prefix: String,
        days: [Date],
        calendar: Calendar,
        center: UNUserNotificationCenter
    ) async {
        for day in days {
            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = hour
            components.minute = minute
            guard let fireDate = calendar.date(from: components), fireDate > .now else { continue }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = "Take a moment to log your food."
            content.sound = .default
            content.userInfo = ["openRequest": "add-food"]
            let request = UNNotificationRequest(
                identifier: "\(prefix).\(CalendarDay(date: day, calendar: calendar).sharingDayKey)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            try? await center.add(request)
        }
    }

    private static func hour(forKey key: String, default defaultHour: Int) -> Int {
        UserDefaults.standard.object(forKey: key) as? Int ?? defaultHour
    }

    private static func minute(forKey key: String) -> Int {
        UserDefaults.standard.object(forKey: key) as? Int ?? 0
    }
}
