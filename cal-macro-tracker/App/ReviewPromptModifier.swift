import StoreKit
import SwiftData
import SwiftUI
import os

extension Notification.Name {
    static let didSuccessfullyLogFood = Notification.Name("didSuccessfullyLogFood")
}

struct ReviewPromptModifier: ViewModifier {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MACROS", category: "AppReview")
    @Environment(\.modelContext) private var modelContext
    @Environment(AppDayContext.self) private var dayContext
    @Environment(\.requestReview) private var requestReview
    @AppStorage(AppStorageKeys.reviewPromptedAppVersion) private var promptedVersion = ""

    func body(content: Content) -> some View {
        content
            .onAppear {
                UserDefaults.standard.set(false, forKey: AppStorageKeys.isProPaywallPresented)
            }
            .onReceive(NotificationCenter.default.publisher(for: .didSuccessfullyLogFood)) { _ in
                requestReviewIfEligible()
            }
    }

    private func requestReviewIfEligible() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        guard let entries = try? modelContext.fetch(FetchDescriptor<LogEntry>()) else { return }

        let calendar = dayContext.today.resolvedCalendar
        let distinctDays = Set(entries.map { CalendarDay(date: $0.dateLogged, calendar: calendar) })
        let isPaywallPresented = UserDefaults.standard.bool(forKey: AppStorageKeys.isProPaywallPresented)
        let hasNotRequestedForVersion = promptedVersion != version
        let meetsLogThreshold = entries.count >= 5 && distinctDays.count >= 3
        guard !version.isEmpty, hasNotRequestedForVersion, !isPaywallPresented, meetsLogThreshold else { return }

        promptedVersion = version
        #if DEBUG
        Self.logger.notice("Requesting App Store review after qualifying log save.")
        #endif
        requestReview()
    }
}
