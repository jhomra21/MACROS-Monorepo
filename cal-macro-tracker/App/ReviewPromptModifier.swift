import StoreKit
import SwiftData
import SwiftUI
import os

extension Notification.Name {
    static let didSuccessfullyLogFood = Notification.Name("didSuccessfullyLogFood")
}

struct ReviewPromptModifier: ViewModifier {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "cal-macro-tracker", category: "AppReview")
    @Environment(\.modelContext) private var modelContext
    @Environment(AppDayContext.self) private var dayContext
    @Environment(\.requestReview) private var requestReview
    @AppStorage(AppStorageKeys.reviewPromptedAppVersion) private var promptedVersion = ""
    @State private var successfulLogSaveCount = 0

    func body(content: Content) -> some View {
        content
            .onAppear {
                UserDefaults.standard.set(false, forKey: AppStorageKeys.isProPaywallPresented)
            }
            .onReceive(NotificationCenter.default.publisher(for: .didSuccessfullyLogFood)) { _ in
                successfulLogSaveCount += 1
            }
            .task(id: successfulLogSaveCount) {
                guard successfulLogSaveCount > 0 else { return }
                await Task.yield()
                guard Task.isCancelled == false else { return }
                requestReviewIfEligible()
            }
    }

    private func requestReviewIfEligible() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let isPaywallPresented = UserDefaults.standard.bool(forKey: AppStorageKeys.isProPaywallPresented)
        guard !version.isEmpty, promptedVersion != version, !isPaywallPresented else { return }

        let calendar = dayContext.today.resolvedCalendar
        guard let start = calendar.date(byAdding: .day, value: -90, to: dayContext.today.startDate) else { return }
        var descriptor = LogEntryQuery.descriptor(start: start, end: dayContext.today.dayInterval.end)
        guard let entries = try? modelContext.fetch(descriptor) else { return }

        let distinctDays = Set(entries.map { CalendarDay(date: $0.dateLogged, calendar: calendar) })
        let meetsLogThreshold = entries.count >= 5 && distinctDays.count >= 3
        guard meetsLogThreshold else { return }

        promptedVersion = version
        #if DEBUG
        Self.logger.notice("Requesting App Store review after qualifying log save.")
        #endif
        requestReview()
    }
}
