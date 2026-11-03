import WidgetKit

enum WidgetTimelineReloader {
    static func reloadMacroWidgets() {
        WidgetCenter.shared.reloadTimelines(ofKind: SharedAppConfiguration.dailyMacroWidgetKind)
        WidgetCenter.shared.reloadTimelines(ofKind: SharedAppConfiguration.dailyMacroAccessoryWidgetKind)
    }

    static func reloadSharedPersonWidgets() {
        WidgetCenter.shared.reloadTimelines(ofKind: SharedAppConfiguration.sharedPersonMacroWidgetKind)
        WidgetCenter.shared.reloadTimelines(ofKind: SharedAppConfiguration.sharedPersonMacroAccessoryWidgetKind)
    }

    static func reloadAppearanceWidgets() {
        reloadMacroWidgets()
        WidgetCenter.shared.reloadTimelines(ofKind: SharedAppConfiguration.sharedPersonMacroWidgetKind)
    }
}
