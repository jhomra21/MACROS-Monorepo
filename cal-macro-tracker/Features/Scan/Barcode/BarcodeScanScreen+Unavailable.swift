#if !os(iOS)
import SwiftUI

struct BarcodeScanScreen: View {
    enum EntryMode {
        case options
        case immediateCamera
    }

    let onFoodLogged: () -> Void
    let loggingDay: CalendarDay?
    let entryMode: EntryMode

    init(
        onFoodLogged: @escaping () -> Void,
        loggingDay: CalendarDay? = nil,
        entryMode: EntryMode = .options
    ) {
        self.onFoodLogged = onFoodLogged
        self.loggingDay = loggingDay
        self.entryMode = entryMode
    }

    var body: some View {
        ContentUnavailableView(
            "Barcode scan unavailable",
            systemImage: "barcode.viewfinder",
            description: Text("Barcode scanning is only available on iPhone builds.")
        )
        .navigationTitle("Scan Barcode")
    }
}
#endif
