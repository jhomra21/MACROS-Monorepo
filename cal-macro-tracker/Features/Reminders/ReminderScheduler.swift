import Foundation
import SwiftData
import UserNotifications

enum ReminderScheduler {
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
        let days = Self.upcomingDays(from: .now, count: 7, loggedDates: entries.map(\.dateLogged), calendar: calendar)
        let hour = defaults.object(forKey: AppStorageKeys.reminderHour) as? Int ?? 20
        let minute = defaults.object(forKey: AppStorageKeys.reminderMinute) as? Int ?? 0
        if defaults.bool(forKey: AppStorageKeys.reminderEnabled) {
            for day in days {
                var components = calendar.dateComponents([.year, .month, .day], from: day)
                components.hour = hour
                components.minute = minute
                guard let fireDate = calendar.date(from: components), fireDate > .now else { continue }
                let content = UNMutableNotificationContent()
                content.title = "Log today's meals"
                content.body = "Take a moment to add what you ate today."
                content.sound = .default
                content.userInfo = ["openRequest": "add-food"]
                let request = UNNotificationRequest(
                    identifier: "reminder.daily.\(CalendarDay(date: day, calendar: calendar).sharingDayKey)",
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                )
                try? await center.add(request)
            }
        }
        guard hasPro else { return }
        let namedReminders: [(String, String, Int, Int)] = [
            (
                "Breakfast", AppStorageKeys.reminderBreakfastEnabled,
                Self.hour(forKey: AppStorageKeys.reminderBreakfastHour, default: 8),
                Self.minute(forKey: AppStorageKeys.reminderBreakfastMinute)
            ),
            (
                "Lunch", AppStorageKeys.reminderLunchEnabled, Self.hour(forKey: AppStorageKeys.reminderLunchHour, default: 12),
                Self.minute(forKey: AppStorageKeys.reminderLunchMinute)
            ),
            (
                "Dinner", AppStorageKeys.reminderDinnerEnabled, Self.hour(forKey: AppStorageKeys.reminderDinnerHour, default: 18),
                Self.minute(forKey: AppStorageKeys.reminderDinnerMinute)
            )
        ]
        for (title, enabledKey, hour, minute) in namedReminders where defaults.bool(forKey: enabledKey) {
            await schedule(
                title: title, hour: hour, minute: minute, prefix: "reminder.pro.\(title.lowercased())",
                days: days, calendar: calendar, center: center)
        }
        if defaults.bool(forKey: AppStorageKeys.reminderSmartEveningEnabled) {
            await schedule(
                title: "Evening check-in", hour: 20, minute: 0, prefix: "reminder.pro.evening",
                days: days, calendar: calendar, center: center)
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
