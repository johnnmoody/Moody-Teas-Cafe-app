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

    // Custom URL scheme: moodyteas://auth?token=<magic_token>
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url,
              url.scheme == "moodyteas" else { return }

        // Extract token and load it as a full cafe URL so the webview handles auth
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
           var dest = URLComponents(string: "https://cafe.moodyteas.co") {
            dest.queryItems = [URLQueryItem(name: "token", value: token)]
            if let destURL = dest.url {
                NotificationCenter.default.post(name: .openURL, object: destURL)
            }
        } else {
            // Bare moodyteas:// with no token — just bring app to foreground
            NotificationCenter.default.post(name: .openURL, object: URL(string: "https://cafe.moodyteas.co")!)
        }
    }
}
