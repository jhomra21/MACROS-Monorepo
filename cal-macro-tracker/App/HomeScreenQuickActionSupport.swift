#if os(iOS)
import Combine
import UIKit

@MainActor
final class HomeScreenQuickActionAppDelegate: NSObject, UIApplicationDelegate, ObservableObject {
    @Published private(set) var requestToken = 0

    private var pendingRequest: AppOpenRequest?

    func consumePendingRequest() -> AppOpenRequest? {
        defer { pendingRequest = nil }
        return pendingRequest
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if let shortcutItem = options.shortcutItem {
            queue(shortcutItem)
        }

        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = HomeScreenQuickActionSceneDelegate.self
        return configuration
    }

    fileprivate func queue(_ shortcutItem: UIApplicationShortcutItem) {
        guard let request = HomeScreenQuickAction(shortcutItem: shortcutItem)?.request else { return }
        pendingRequest = request
        requestToken += 1
    }
}

final class HomeScreenQuickActionSceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        guard
            HomeScreenQuickAction(shortcutItem: shortcutItem) != nil,
            let appDelegate = UIApplication.shared.delegate as? HomeScreenQuickActionAppDelegate
        else {
            completionHandler(false)
            return
        }

        appDelegate.queue(shortcutItem)
        completionHandler(true)
    }
}

private enum HomeScreenQuickAction: String {
    case addFood = "juan-test.cal-macro-tracker.add-food"
    case scanBarcode = "juan-test.cal-macro-tracker.scan-barcode"
    case scanLabel = "juan-test.cal-macro-tracker.scan-label"
    case manualEntry = "juan-test.cal-macro-tracker.manual-entry"

    init?(shortcutItem: UIApplicationShortcutItem) {
        self.init(rawValue: shortcutItem.type)
    }

    var request: AppOpenRequest {
        switch self {
        case .addFood:
            .addFood(.addFood)
        case .scanBarcode:
            .addFood(.scanBarcode)
        case .scanLabel:
            .addFood(.scanLabel)
        case .manualEntry:
            .addFood(.manualEntry)
        }
    }
}
#endif
