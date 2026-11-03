import StoreKit
import SwiftData
import SwiftUI
import os

extension Notification.Name {
    static let didSuccessfullyLogFood = Notification.Name("didSuccessfullyLogFood")
}

struct ReviewPromptModifier: ViewModifier {
    let isTodayIdle: Bool

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "cal-macro-tracker", category: "AppReview")
    @Environment(\.modelContext) private var modelContext
    @Environment(AppDayContext.self) private var dayContext
    @Environment(\.requestReview) private var requestReview
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppStorageKeys.reviewPromptedAppVersion) private var promptedVersion = ""
    @AppStorage(AppStorageKeys.reviewLastRequestedAt) private var lastRequestedAt = 0.0
    @AppStorage(AppStorageKeys.isProPaywallPresented) private var isPaywallPresented = false
    @State private var isRequestPending = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                UserDefaults.standard.set(false, forKey: AppStorageKeys.isProPaywallPresented)
            }
            .onReceive(NotificationCenter.default.publisher(for: .didSuccessfullyLogFood)) { _ in
                if isEligible { isRequestPending = true }
            }
            .task(id: canRequestReview) {
                guard canRequestReview else { return }
                // Wait at a natural stopping point, not in the log button's completion.
                // https://developer.apple.com/documentation/storekit/requesting-app-store-reviews
                #if DEBUG
                Self.logger.notice("Review request waiting for two seconds of idle Today.")
                #endif
                do {
                    try await Task.sleep(for: .seconds(2))
                } catch {
                    #if DEBUG
                    Self.logger.notice("Review idle wait cancelled; request remains pending.")
                    #endif
                    return
                }
                guard !Task.isCancelled, canRequestReview, isEligible else { return }
                promptedVersion = appVersion
                lastRequestedAt = Date.now.timeIntervalSince1970
                isRequestPending = false
                #if DEBUG
                Self.logger.notice("Requesting App Store review after two seconds of idle Today.")
                #endif
                requestReview()
            }
    }

    private var canRequestReview: Bool {
        isRequestPending && isTodayIdle && !isPaywallPresented && scenePhase == .active
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    private var isEligible: Bool {
        guard !appVersion.isEmpty, promptedVersion != appVersion else { return false }
        // Space requests across releases too, as Apple's HIG recommends.
        // https://developer.apple.com/design/human-interface-guidelines/ratings-and-reviews
        guard lastRequestedAt == 0 || Date.now.timeIntervalSince1970 - lastRequestedAt >= 14 * 24 * 60 * 60 else {
            return false
        }

        let calendar = dayContext.today.resolvedCalendar
        guard let start = calendar.date(byAdding: .day, value: -90, to: dayContext.today.startDate) else { return false }
        let descriptor = LogEntryQuery.descriptor(start: start, end: dayContext.today.dayInterval.end)
        guard let entries = try? modelContext.fetch(descriptor) else { return false }

        let distinctDays = Set(entries.map { CalendarDay(date: $0.dateLogged, calendar: calendar) })
        return entries.count >= 5 && distinctDays.count >= 3
    }
}
