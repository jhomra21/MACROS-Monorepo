import Foundation

nonisolated enum SharedAppConfiguration {
    static let convexDeploymentURL = "https://energized-pigeon-822.convex.cloud"
    static let authBaseURL = URL(string: "https://macros-auth.jhonra121.workers.dev")!
    static let appGroupIdentifier = "group.juan-test.cal-macro-tracker"
    static let dailyMacroWidgetKind = "DailyMacroWidget"
    static let dailyMacroAccessoryWidgetKind = "DailyMacroAccessoryWidget"
    static let sharedPersonMacroWidgetKind = "SharedPersonMacroWidget"
    static let sharedPersonMacroAccessoryWidgetKind = "SharedPersonMacroAccessoryWidget"
    static let deepLinkScheme = "calmacrotracker"
    static let quickActionTypePrefix = "juan-test.cal-macro-tracker."
}
