import SwiftData
import SwiftUI
import UserNotifications

struct OnboardingFlow: View {
    let onComplete: () -> Void
    @State private var profile = BodyProfileDraft()
    @State private var path: [OnboardingStep] = []

    var body: some View {
        NavigationStack(path: $path) {
            OnboardingWelcomeScreen {
                path.append(.choice)
            }
            .navigationDestination(for: OnboardingStep.self) { step in
                switch step {
                case .choice:
                    OnboardingChoiceScreen(onComplete: completeGoalSetup)
                case .aboutYou:
                    BodyProfileFormScreen(profile: $profile) {
                        path.append(.targets)
                    }
                case .targets:
                    TargetReviewScreen(profile: $profile, onComplete: completeGoalSetup)
                case .reminders:
                    OnboardingRemindersScreen(onComplete: onComplete)
                }
            }
        }
    }

    private func completeGoalSetup() {
        path.append(.reminders)
    }
}

enum OnboardingStep: Hashable {
    case choice
    case aboutYou
    case targets
    case reminders
}

private struct OnboardingWelcomeScreen: View {
    let onContinue: () -> Void
    @ScaledMetric(relativeTo: .largeTitle) private var heroIconSize: CGFloat = 56

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "heart.text.clipboard")
                .font(.system(size: heroIconSize, weight: .medium))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text(AppBrand.displayName)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            VStack(spacing: 12) {
                Label("No account needed", systemImage: "person.crop.circle.badge.checkmark")
                Label("Scan or add any food", systemImage: "barcode.viewfinder")
                Label("Your data stays on your phone", systemImage: "iphone")
            }
            .font(.body)
            .foregroundStyle(.secondary)
            Spacer()
            BottomPinnedActionBar(title: "Get Started", systemImage: nil, isDisabled: false, action: onContinue)
        }
        .padding(.top, 32)
        .background(PlatformColors.groupedBackground)
        .navigationBarBackButtonHidden()
    }
}

struct OnboardingChoiceScreen: View {
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("How would you like to set your targets?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            choiceRows
            Spacer()
        }
        .padding(.top, 32)
        .navigationTitle("Set your goals")
        .inlineNavigationTitle()
    }

    private var choiceRows: some View {
        VStack(spacing: 14) {
            NavigationLink(value: OnboardingStep.aboutYou) {
                choiceRow("Calculate my targets", subtitle: "Get a starting point based on your routine", symbol: "sparkles")
            }
            NavigationLink {
                GoalSetupScreen(onComplete: onComplete)
            } label: {
                choiceRow("I already know my numbers", subtitle: "Enter your daily goals directly", symbol: "slider.horizontal.3")
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    private func choiceRow(_ title: String, subtitle: String, symbol: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardBackground(cornerRadius: 20)
        .accessibilityElement(children: .combine)
    }
}

private struct OnboardingRemindersScreen: View {
    @Environment(AppEntitlements.self) private var entitlements
    @Environment(\.openURL) private var openURL
    @State private var settings = OnboardingReminderSettings()
    @State private var isRequestingPermission = false
    @State private var isShowingPermissionMessage = false
    @State private var permissionMessage = ""
    @State private var didFinish = false
    @State private var authorizationTask: Task<Void, Never>?
    @State private var isPresentingPro = false

    let onComplete: () -> Void

    private var selectedCount: Int {
        [
            settings.dailyEnabled, includesProChoices && settings.breakfastEnabled,
            includesProChoices && settings.lunchEnabled, includesProChoices && settings.dinnerEnabled,
            includesProChoices && settings.eveningEnabled
        ].filter { $0 }.count
    }

    private var includesProChoices: Bool {
        entitlements.canUse(.multipleReminders)
    }

    private var canEnableProReminder: Bool {
        entitlements.canUse(.multipleReminders) && selectedCount < ReminderLimits.maxCount
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(spacing: 10) {
                        Text("Choose reminders")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Text(
                            "A gentle nudge to log your day. Change reminders anytime in Settings. "
                                + "iOS asks permission only if a reminder is on when you continue."
                        )
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 8)

                    if selectedCount > ReminderLimits.maxCount {
                        Text("Choose no more than three reminders before continuing.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    reminderCards
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 24)
                .disabled(isRequestingPermission)
            }

            BottomPinnedActionBar(
                title: "Continue",
                systemImage: nil,
                isDisabled: isRequestingPermission || selectedCount > ReminderLimits.maxCount,
                isLoading: isRequestingPermission,
                action: continueOnboarding
            )
            .disabled(isRequestingPermission)
        }
        .background(PlatformColors.groupedBackground)
        .navigationTitle("Reminders")
        .inlineNavigationTitle()
        .navigationBarBackButtonHidden()
        .onDisappear {
            authorizationTask?.cancel()
        }
        .alert("Notifications aren’t enabled", isPresented: $isShowingPermissionMessage) {
            if let settingsURL = AppSettingsURL.url {
                Button("Open Settings") { openURL(settingsURL) }
            }
            Button("Continue", role: .cancel) { finishOnboarding() }
        } message: {
            Text(permissionMessage)
        }
        .sheet(isPresented: $isPresentingPro) {
            ProPaywallSheet(context: .reminders)
        }
    }

    private var reminderCards: some View {
        VStack(spacing: 14) {
            dailyReminderCard
            additionalReminderCard
        }
    }

    private var dailyReminderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily reminder")
                .font(.headline)

            Toggle("Remind me to log food", isOn: $settings.dailyEnabled)

            if settings.dailyEnabled {
                timePicker("Reminder time", hour: $settings.dailyHour, minute: $settings.dailyMinute)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardBackground(cornerRadius: 20)
    }

    private var additionalReminderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Additional reminders")
                    .font(.headline)

                if !includesProChoices {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text("PRO")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }

            if includesProChoices {
                Text("Up to three reminders total, including your daily reminder.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    proToggle("Breakfast", enabled: $settings.breakfastEnabled)
                    if settings.breakfastEnabled {
                        timePicker("Breakfast reminder time", hour: $settings.breakfastHour, minute: $settings.breakfastMinute)
                    }
                    proToggle("Lunch", enabled: $settings.lunchEnabled)
                    if settings.lunchEnabled {
                        timePicker("Lunch reminder time", hour: $settings.lunchHour, minute: $settings.lunchMinute)
                    }
                    proToggle("Dinner", enabled: $settings.dinnerEnabled)
                    if settings.dinnerEnabled {
                        timePicker("Dinner reminder time", hour: $settings.dinnerHour, minute: $settings.dinnerMinute)
                    }
                    proToggle("Evening check-in if nothing is logged", enabled: $settings.eveningEnabled)
                }
            } else {
                Text("Multiple reminders are available with Pro.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardBackground(cornerRadius: 20)
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .onTapGesture {
            guard !includesProChoices else { return }
            isPresentingPro = true
        }
        .accessibilityAddTraits(includesProChoices ? [] : .isButton)
        .accessibilityHint(includesProChoices ? "" : "Opens the Pro paywall")
    }

    private func timePicker(_ title: String, hour: Binding<Int>, minute: Binding<Int>) -> some View {
        DatePicker(
            title,
            selection: Binding(
                get: { Calendar.current.date(from: DateComponents(hour: hour.wrappedValue, minute: minute.wrappedValue)) ?? .now },
                set: {
                    hour.wrappedValue = Calendar.current.component(.hour, from: $0)
                    minute.wrappedValue = Calendar.current.component(.minute, from: $0)
                }
            ),
            displayedComponents: .hourAndMinute
        )
    }

    @ViewBuilder
    private func proToggle(_ title: String, enabled: Binding<Bool>) -> some View {
        Toggle(
            title,
            isOn: Binding(
                get: { enabled.wrappedValue },
                set: { value in
                    if value, !enabled.wrappedValue, !canEnableProReminder { return }
                    enabled.wrappedValue = value
                }
            )
        )
        .disabled(!enabled.wrappedValue && !canEnableProReminder)
    }

    private func continueOnboarding() {
        guard !isRequestingPermission, !didFinish else { return }
        settings.save(includeProChoices: includesProChoices)
        guard selectedCount > 0 else {
            NotificationCenter.default.post(name: .remindersDidChange, object: nil)
            finishOnboarding()
            return
        }

        isRequestingPermission = true
        authorizationTask = Task {
            let center = UNUserNotificationCenter.current()
            let status = await center.notificationSettings().authorizationStatus
            guard !Task.isCancelled else { return }
            switch status {
            case .authorized, .provisional:
                NotificationCenter.default.post(name: .remindersDidChange, object: nil)
                finishOnboarding()
            case .ephemeral:
                NotificationCenter.default.post(name: .remindersDidChange, object: nil)
                showPermissionMessage(
                    "These reminders can’t be delivered in this app session. Your choices are saved; you can continue and manage reminders later in Settings."
                )
            case .notDetermined:
                do {
                    let granted = try await center.requestAuthorization(options: [.alert, .sound])
                    guard !Task.isCancelled else { return }
                    NotificationCenter.default.post(name: .remindersDidChange, object: nil)
                    if granted {
                        finishOnboarding()
                    } else {
                        showPermissionMessage(
                            "Notifications are off. Your reminder choices are saved, but iOS won’t deliver them. You can enable notifications in Settings."
                        )
                    }
                } catch {
                    guard !Task.isCancelled else { return }
                    NotificationCenter.default.post(name: .remindersDidChange, object: nil)
                    showPermissionMessage(
                        "Your reminder choices are saved, but iOS couldn’t request notification permission. You can continue and manage reminders later in Settings."
                    )
                }
            case .denied:
                NotificationCenter.default.post(name: .remindersDidChange, object: nil)
                showPermissionMessage(
                    "Notifications are off. Your reminder choices are saved, but iOS won’t deliver them. You can enable notifications in Settings."
                )
            @unknown default:
                NotificationCenter.default.post(name: .remindersDidChange, object: nil)
                showPermissionMessage(
                    "Notification permission is unavailable right now. Your reminder choices are saved; you can continue and manage reminders later in Settings."
                )
            }
        }
    }

    private func showPermissionMessage(_ message: String) {
        isRequestingPermission = false
        permissionMessage = message
        isShowingPermissionMessage = true
    }

    private func finishOnboarding() {
        guard !didFinish else { return }
        didFinish = true
        onComplete()
    }
}

private struct OnboardingReminderSettings {
    var dailyEnabled: Bool
    var dailyHour: Int
    var dailyMinute: Int
    var breakfastEnabled: Bool
    var breakfastHour: Int
    var breakfastMinute: Int
    var lunchEnabled: Bool
    var lunchHour: Int
    var lunchMinute: Int
    var dinnerEnabled: Bool
    var dinnerHour: Int
    var dinnerMinute: Int
    var eveningEnabled: Bool

    init() {
        let defaults = UserDefaults.standard
        let hasExistingReminderChoice = defaults.object(forKey: AppStorageKeys.reminderEnabled) != nil
        dailyEnabled = defaults.object(forKey: AppStorageKeys.reminderEnabled) as? Bool ?? true
        dailyHour = defaults.object(forKey: AppStorageKeys.reminderHour) as? Int ?? (hasExistingReminderChoice ? 20 : 9)
        dailyMinute = defaults.object(forKey: AppStorageKeys.reminderMinute) as? Int ?? 0
        breakfastEnabled = defaults.bool(forKey: AppStorageKeys.reminderBreakfastEnabled)
        breakfastHour = defaults.object(forKey: AppStorageKeys.reminderBreakfastHour) as? Int ?? 8
        breakfastMinute = defaults.object(forKey: AppStorageKeys.reminderBreakfastMinute) as? Int ?? 0
        lunchEnabled = defaults.bool(forKey: AppStorageKeys.reminderLunchEnabled)
        lunchHour = defaults.object(forKey: AppStorageKeys.reminderLunchHour) as? Int ?? 12
        lunchMinute = defaults.object(forKey: AppStorageKeys.reminderLunchMinute) as? Int ?? 0
        dinnerEnabled = defaults.bool(forKey: AppStorageKeys.reminderDinnerEnabled)
        dinnerHour = defaults.object(forKey: AppStorageKeys.reminderDinnerHour) as? Int ?? 18
        dinnerMinute = defaults.object(forKey: AppStorageKeys.reminderDinnerMinute) as? Int ?? 0
        eveningEnabled = defaults.bool(forKey: AppStorageKeys.reminderSmartEveningEnabled)
    }

    func save(includeProChoices: Bool) {
        let defaults = UserDefaults.standard
        defaults.set(dailyEnabled, forKey: AppStorageKeys.reminderEnabled)
        defaults.set(dailyHour, forKey: AppStorageKeys.reminderHour)
        defaults.set(dailyMinute, forKey: AppStorageKeys.reminderMinute)
        guard includeProChoices else { return }
        defaults.set(breakfastEnabled, forKey: AppStorageKeys.reminderBreakfastEnabled)
        defaults.set(breakfastHour, forKey: AppStorageKeys.reminderBreakfastHour)
        defaults.set(breakfastMinute, forKey: AppStorageKeys.reminderBreakfastMinute)
        defaults.set(lunchEnabled, forKey: AppStorageKeys.reminderLunchEnabled)
        defaults.set(lunchHour, forKey: AppStorageKeys.reminderLunchHour)
        defaults.set(lunchMinute, forKey: AppStorageKeys.reminderLunchMinute)
        defaults.set(dinnerEnabled, forKey: AppStorageKeys.reminderDinnerEnabled)
        defaults.set(dinnerHour, forKey: AppStorageKeys.reminderDinnerHour)
        defaults.set(dinnerMinute, forKey: AppStorageKeys.reminderDinnerMinute)
        defaults.set(eveningEnabled, forKey: AppStorageKeys.reminderSmartEveningEnabled)
    }
}
