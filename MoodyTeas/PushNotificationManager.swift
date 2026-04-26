import Foundation

final class PushNotificationManager {
    static let shared = PushNotificationManager()

    private let tokenKey = "co.moodyteas.apnsDeviceToken"

    var deviceToken: String? {
        get { UserDefaults.standard.string(forKey: tokenKey) }
        set { UserDefaults.standard.set(newValue, forKey: tokenKey) }
    }

    private init() {}

    /// JavaScript snippet that registers the stored APNS token with the backend.
    /// Runs inside the WKWebView — the existing auth cookie is sent automatically.
    var registrationJS: String? {
        guard let token = deviceToken else { return nil }
        // Sanitise: device tokens are hex-only, but be safe
        let safe = token.replacingOccurrences(of: "'", with: "")
        return """
        (function() {
            fetch('/api/push/apns-subscribe', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    device_token: '\(safe)',
                    bundle_id: 'co.moodyteas.cafe',
                    env: 'production'
                })
            }).catch(function() {});
        })();
        """
    }
}
