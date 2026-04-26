import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let webVC = WebViewController()

        // Universal link opened the app from cold launch
        if let activity = connectionOptions.userActivities.first,
           activity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = activity.webpageURL {
            webVC.pendingURL = url
        }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = webVC
        window.makeKeyAndVisible()
        self.window = window
    }

    // Universal link while app is already running
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else { return }
        NotificationCenter.default.post(name: .openURL, object: url)
    }
}
