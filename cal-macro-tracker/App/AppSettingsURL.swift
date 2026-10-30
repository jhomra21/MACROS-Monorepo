import Foundation
#if os(iOS)
import UIKit
#endif

enum AppSettingsURL {
    /// The iOS Settings page for MACROS. Nil off iOS.
    static var url: URL? {
        #if os(iOS)
        URL(string: UIApplication.openSettingsURLString)
        #else
        nil
        #endif
    }
}
