import WidgetKit

enum WidgetTimelineReloader {
    static func reloadMacroWidgets() {
        WidgetCenter.shared.reloadTimelines(ofKind: SharedAppConfiguration.dailyMacroWidgetKind)
        WidgetCenter.shared.reloadTimelines(ofKind: SharedAppConfiguration.dailyMacroAccessoryWidgetKind)
    }
}
