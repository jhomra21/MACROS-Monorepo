#if os(iOS)
import Combine
import UIKit
import UserNotifications

@MainActor
final class HomeScreenQuickActionAppDelegate: NSObject, UIApplicationDelegate, ObservableObject, UNUserNotificationCenterDelegate {
    @Published private(set) var requestToken = 0

    private var pendingRequest: AppOpenRequest?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

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
            _ = queue(shortcutItem)
        }

        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = HomeScreenQuickActionSceneDelegate.self
        return configuration
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.notification.request.content.userInfo["openRequest"] as? String == "add-food" {
            queue(.addFood(.addFood))
        }
        completionHandler()
    }

    private func queue(_ request: AppOpenRequest) {
        pendingRequest = request
        requestToken += 1
    }

    fileprivate func queue(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard let request = AppOpenRequest(shortcutItem: shortcutItem) else { return false }
        queue(request)
        return true
    }
}

final class HomeScreenQuickActionSceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        guard let appDelegate = UIApplication.shared.delegate as? HomeScreenQuickActionAppDelegate else {
            completionHandler(false)
            return
        }

        completionHandler(appDelegate.queue(shortcutItem))
    }
}
#endif
