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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var heroRingDiameter: CGFloat = 150
    @State private var heroTotals = NutritionSnapshot.zero
    @State private var didAnimateHero = false

    private static let heroGoals = MacroGoalsSnapshot(
        calorieGoal: 2_000,
        proteinGoalGrams: 150,
        fatGoalGrams: 65,
        carbGoalGrams: 200
    )

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: OnboardingLayout.headerSpacing) {
                        OnboardingHeader(title: AppBrand.displayName, subtitle: nil, isWelcome: true) {
                            MacroRingSetView(
                                totals: heroTotals,
                                goals: Self.heroGoals,
                                ringDiameter: min(heroRingDiameter, 180),
                                centerValueFontSize: nil,
                                minimumLineWidth: 10,
                                showsGoalSubtitle: false
                            )
                        }
                        VStack(spacing: 12) {
                            Label("No account needed", systemImage: "person.crop.circle.badge.checkmark")
                            Label("Scan or add any food", systemImage: "barcode.viewfinder")
                            Label("Your data stays on your phone", systemImage: "iphone")
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, OnboardingLayout.horizontalInset)
                    .padding(.vertical, OnboardingLayout.verticalPadding)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            BottomPinnedActionBar(
                title: "Get Started", systemImage: nil, isDisabled: false,
                edgeFadeColor: PlatformColors.groupedBackground, action: onContinue)
        }
        .background(PlatformColors.groupedBackground)
        .navigationBarBackButtonHidden()
        .onAppear {
            guard !didAnimateHero else { return }
            didAnimateHero = true
            var generator = SystemRandomNumberGenerator()
            let totals = Self.randomHeroTotals(goals: Self.heroGoals, using: &generator)
            if reduceMotion {
                heroTotals = totals
            } else {
                withAnimation(.smooth(duration: 1.1).delay(0.15)) {
                    heroTotals = totals
                }
            }
        }
    }

    private static func randomHeroTotals<Generator: RandomNumberGenerator>(
        goals: MacroGoalsSnapshot,
        using generator: inout Generator
    ) -> NutritionSnapshot {
        let protein = goals.proteinGoalGrams * Double.random(in: 0.45...0.92, using: &generator)
        let carbs = goals.carbGoalGrams * Double.random(in: 0.45...0.92, using: &generator)
        let fat = goals.fatGoalGrams * Double.random(in: 0.45...0.92, using: &generator)
        return NutritionSnapshot(
            calories: protein * 4 + carbs * 4 + fat * 9,
            protein: protein,
            fat: fat,
            carbs: carbs
        )
    }
}

struct OnboardingChoiceScreen: View {
    let onComplete: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: OnboardingLayout.headerSpacing) {
                OnboardingHeader(
                    symbol: "slider.horizontal.3", title: "Set your goals",
                    subtitle: "How would you like to set your targets?")
                choiceRows
            }
            .padding(.horizontal, OnboardingLayout.horizontalInset)
            .padding(.vertical, OnboardingLayout.verticalPadding)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(PlatformColors.groupedBackground)
        .navigationTitle("")
        .inlineNavigationTitle()
    }

    private var choiceRows: some View {
        VStack(spacing: OnboardingLayout.cardSpacing) {
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
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardBackground(cornerRadius: 20)
        .accessibilityElement(children: .combine)
    }
}

private struct OnboardingRemindersScreen: View {
    @Environment(AppEntitlements.self) private var entitlements
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
                VStack(alignment: .leading, spacing: OnboardingLayout.headerSpacing) {
                    OnboardingHeader(
                        symbol: "bell.badge.fill", title: "Stay on track",
                        subtitle: "A gentle nudge to log your day. Change it anytime in Settings.")

                    if selectedCount > ReminderLimits.maxCount {
                        Text("Choose no more than three reminders before continuing.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    reminderCards

                    Text("iOS asks for permission only if a reminder is on.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, OnboardingLayout.horizontalInset)
                .padding(.vertical, OnboardingLayout.verticalPadding)
                .disabled(isRequestingPermission)
            }

            BottomPinnedActionBar(
                title: "Continue",
                systemImage: nil,
                isDisabled: isRequestingPermission || selectedCount > ReminderLimits.maxCount,
                isLoading: isRequestingPermission,
                edgeFadeColor: PlatformColors.groupedBackground,
                action: continueOnboarding
            )
            .disabled(isRequestingPermission)
        }
        .background(PlatformColors.groupedBackground)
        .navigationTitle("")
        .inlineNavigationTitle()
        .navigationBarBackButtonHidden(isRequestingPermission)
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
        VStack(spacing: OnboardingLayout.cardSpacing) {
            dailyReminderCard
            additionalReminderCard
        }
    }

    /// Text column starts after the 30 pt tile and its 12 pt gap.
    private let rowTextInset: CGFloat = 42

    @ViewBuilder
    private func reminderRow<Trailing: View>(
        _ title: String, subtitle: String, symbol: String, tint: Color,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        let tile = Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(tint, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .accessibilityHidden(true)
        let texts = VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline)
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }

        // At accessibility sizes the tile and control share a line above the text so the text keeps the full width.
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    tile
                    Spacer(minLength: 8)
                    trailing()
                }
                texts
            }
        } else {
            HStack(spacing: 12) {
                tile
                texts
                Spacer(minLength: 8)
                trailing()
            }
        }
    }

    private var dailyReminderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            reminderRow("Daily reminder", subtitle: "Remind me to log food", symbol: "bell.fill", tint: .accentColor) {
                Toggle("Daily reminder", isOn: $settings.dailyEnabled).labelsHidden()
            }

            if settings.dailyEnabled {
                Divider().padding(.leading, rowTextInset)
                timePicker("Daily reminder time", hour: $settings.dailyHour, minute: $settings.dailyMinute)
                    .padding(.leading, rowTextInset)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardBackground(cornerRadius: 20)
    }

    @ViewBuilder
    private var additionalReminderCard: some View {
        if includesProChoices {
            additionalReminderCardContent
        } else {
            Button {
                isPresentingPro = true
            } label: {
                additionalReminderCardContent.accessibilityElement(children: .combine)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the Pro paywall")
        }
    }

    private var additionalReminderCardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            reminderRow(
                "More reminders", subtitle: "Breakfast, lunch, dinner, evening check-in", symbol: "clock.badge.fill",
                tint: .orange
            ) {
                if !includesProChoices {
                    Text("PRO")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.tint.opacity(0.15), in: Capsule())
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }

            if includesProChoices {
                Text("Up to three reminders total, including your daily reminder.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Divider()
                proToggle("Breakfast", enabled: $settings.breakfastEnabled)
                if settings.breakfastEnabled {
                    timePicker("Breakfast reminder time", hour: $settings.breakfastHour, minute: $settings.breakfastMinute)
                        .padding(.leading, rowTextInset)
                }
                Divider()
                proToggle("Lunch", enabled: $settings.lunchEnabled)
                if settings.lunchEnabled {
                    timePicker("Lunch reminder time", hour: $settings.lunchHour, minute: $settings.lunchMinute)
                        .padding(.leading, rowTextInset)
                }
                Divider()
                proToggle("Dinner", enabled: $settings.dinnerEnabled)
                if settings.dinnerEnabled {
                    timePicker("Dinner reminder time", hour: $settings.dinnerHour, minute: $settings.dinnerMinute)
                        .padding(.leading, rowTextInset)
                }
                Divider()
                proToggle("Evening check-in if nothing is logged", enabled: $settings.eveningEnabled)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardBackground(cornerRadius: 20)
        .contentShape(RoundedRectangle(cornerRadius: 20))
    }

    private func timePicker(_ title: String, hour: Binding<Int>, minute: Binding<Int>) -> some View {
        DatePicker(
            "Time",
            selection: Binding(
                get: { Calendar.current.date(from: DateComponents(hour: hour.wrappedValue, minute: minute.wrappedValue)) ?? .now },
                set: {
                    hour.wrappedValue = Calendar.current.component(.hour, from: $0)
                    minute.wrappedValue = Calendar.current.component(.minute, from: $0)
                }
            ),
            displayedComponents: .hourAndMinute
        )
        .accessibilityLabel(title)
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
