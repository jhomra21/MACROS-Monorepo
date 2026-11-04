import SwiftUI
import WidgetKit

@main
struct CalMacroWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyMacroWidget()
        #if os(iOS)
        DailyMacroAccessoryWidget()
        SharedPersonMacroWidget()
        SharedPersonMacroAccessoryWidget()
        #endif
    }
}
