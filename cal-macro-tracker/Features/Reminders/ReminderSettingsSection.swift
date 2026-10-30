import SwiftUI
import UserNotifications
#if os(iOS)
import UIKit
#endif

struct ReminderSettingsSection: View {
    @AppStorage(AppStorageKeys.reminderEnabled) private var isEnabled = false
    @AppStorage(AppStorageKeys.reminderHour) private var hour = 20
    @AppStorage(AppStorageKeys.reminderMinute) private var minute = 0
    @AppStorage(AppStorageKeys.reminderBreakfastEnabled) private var breakfastEnabled = false
    @AppStorage(AppStorageKeys.reminderBreakfastHour) private var breakfastHour = 8
    @AppStorage(AppStorageKeys.reminderBreakfastMinute) private var breakfastMinute = 0
    @AppStorage(AppStorageKeys.reminderLunchEnabled) private var lunchEnabled = false
    @AppStorage(AppStorageKeys.reminderLunchHour) private var lunchHour = 12
    @AppStorage(AppStorageKeys.reminderLunchMinute) private var lunchMinute = 0
    @AppStorage(AppStorageKeys.reminderDinnerEnabled) private var dinnerEnabled = false
    @AppStorage(AppStorageKeys.reminderDinnerHour) private var dinnerHour = 18
    @AppStorage(AppStorageKeys.reminderDinnerMinute) private var dinnerMinute = 0
    @AppStorage(AppStorageKeys.reminderSmartEveningEnabled) private var smartEveningEnabled = false
    @Environment(AppEntitlements.self) private var entitlements
    @Environment(\.openURL) private var openURL
    @State private var isDenied = false
    @State private var isPresentingPro = false

    var body: some View {
        Section("Reminders") {
            Toggle("Daily log reminder", isOn: $isEnabled)
                .onChange(of: isEnabled) { _, enabled in
                    handleReminderChange(enabled, binding: $isEnabled)
                }
            if isEnabled {
                DatePicker(
                    "Reminder time",
                    selection: Binding(
                        get: { Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? .now },
                        set: {
                            hour = Calendar.current.component(.hour, from: $0)
                            minute = Calendar.current.component(.minute, from: $0)
                            NotificationCenter.default.post(name: .remindersDidChange, object: nil)
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
            }
            if entitlements.canUse(.multipleReminders) {
                reminderToggle("Breakfast", enabled: $breakfastEnabled, hour: $breakfastHour, minute: $breakfastMinute)
                reminderToggle("Lunch", enabled: $lunchEnabled, hour: $lunchHour, minute: $lunchMinute)
                reminderToggle("Dinner", enabled: $dinnerEnabled, hour: $dinnerHour, minute: $dinnerMinute)
                Toggle("Evening check-in if nothing is logged", isOn: $smartEveningEnabled)
                    .onChange(of: smartEveningEnabled) { _, enabled in
                        handleReminderChange(enabled, binding: $smartEveningEnabled)
                    }
            } else {
                Button {
                    isPresentingPro = true
                } label: {
                    Label("Multiple reminders", systemImage: "lock.fill")
                }
            }
            if isDenied {
                Button("Open notification settings") {
                    openURL(URL(string: UIApplication.openSettingsURLString)!)
                }
            }
        }
        .sheet(isPresented: $isPresentingPro) {
            ProPaywallSheet(context: .reminders)
        }
        .task {
            isDenied = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
        }
    }

    private func reminderToggle(
        _ title: String,
        enabled: Binding<Bool>,
        hour: Binding<Int>,
        minute: Binding<Int>
    ) -> some View {
        VStack(alignment: .leading) {
            Toggle(title, isOn: enabled)
                .onChange(of: enabled.wrappedValue) { _, value in handleReminderChange(value, binding: enabled) }
            if enabled.wrappedValue {
                DatePicker(
                    "\(title) reminder time",
                    selection: Binding(
                        get: { Calendar.current.date(from: DateComponents(hour: hour.wrappedValue, minute: minute.wrappedValue)) ?? .now },
                        set: {
                            hour.wrappedValue = Calendar.current.component(.hour, from: $0)
                            minute.wrappedValue = Calendar.current.component(.minute, from: $0)
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .onChange(of: hour.wrappedValue) { _, _ in refreshSchedule() }
                .onChange(of: minute.wrappedValue) { _, _ in refreshSchedule() }
                .padding(.leading, 12)
            }
        }
    }

    private func handleReminderChange(_ enabled: Bool, binding: Binding<Bool>) {
        refreshSchedule()
        guard enabled else { return }
        Task {
            let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
            isDenied = !granted
            if !granted { binding.wrappedValue = false }
            refreshSchedule()
        }
    }

    private func refreshSchedule() {
        NotificationCenter.default.post(name: .remindersDidChange, object: nil)
    }
}

extension Notification.Name {
    static let remindersDidChange = Notification.Name("remindersDidChange")
}
