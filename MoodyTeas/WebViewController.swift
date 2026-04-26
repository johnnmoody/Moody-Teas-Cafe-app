import UIKit
import WebKit
import SafariServices

final class WebViewController: UIViewController {

    // MARK: - Constants

    static let sharedProcessPool = WKProcessPool()
    private let appHost = "cafe.moodyteas.co"
    private let appURL  = URL(string: "https://cafe.moodyteas.co")!

    // Set by SceneDelegate before viewDidLoad when a universal link cold-launches the app
    var pendingURL: URL?

    // MARK: - Views

    private var webView: WKWebView!
    private let refreshControl = UIRefreshControl()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupWebView()
        setupObservers()
        loadInitialPage()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    // MARK: - Setup

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.processPool = WebViewController.sharedProcessPool

        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.delaysContentTouches = false

        let bg = UIColor(red: 22/255, green: 30/255, blue: 27/255, alpha: 1)
        view.backgroundColor = bg
        webView.backgroundColor = bg
        webView.isOpaque = false

        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        refreshControl.tintColor = UIColor(red: 140/255, green: 195/255, blue: 160/255, alpha: 1)
        refreshControl.addTarget(self, action: #selector(hardReload), for: .valueChanged)
        webView.scrollView.addSubview(refreshControl)
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleOpenURL(_:)), name: .openURL, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleAPNSToken), name: .apnsTokenReceived, object: nil)
    }

    private func loadInitialPage() {
        let url = pendingURL ?? appURL
        pendingURL = nil
        webView.load(URLRequest(url: url))
    }

    // MARK: - Actions

    @objc private func hardReload() {
        webView.load(URLRequest(url: appURL))
    }

    @objc private func handleOpenURL(_ notification: Notification) {
        guard let url = notification.object as? URL else { return }
        DispatchQueue.main.async { self.webView.load(URLRequest(url: url)) }
    }

    @objc private func handleAPNSToken() {
        // Token just arrived after the page was already loaded — register now
        registerAPNSToken()
    }

    // MARK: - APNS registration

    private func registerAPNSToken() {
        guard let js = PushNotificationManager.shared.registrationJS else { return }
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    // MARK: - Offline screen

    private func showOfflinePage() {
        let html = """
        <!DOCTYPE html><html>
        <head><meta name='viewport' content='width=device-width,initial-scale=1'>
        <style>
        *{box-sizing:border-box;margin:0;padding:0}
        body{background:#161e1b;color:#c8d6cc;font-family:-apple-system,sans-serif;
             display:flex;flex-direction:column;align-items:center;justify-content:center;
             height:100svh;padding:32px;text-align:center}
        h2{font-size:22px;margin-bottom:8px}
        p{font-size:15px;color:#7a9e8a;margin-bottom:32px}
        button{background:#3d6b52;color:#fff;border:none;border-radius:14px;
               padding:14px 36px;font-size:17px;-webkit-tap-highlight-color:transparent}
        </style></head>
        <body>
        <h2>No Connection</h2>
        <p>Check your internet connection and try again.</p>
        <button onclick='window.location.reload()'>Retry</button>
        </body></html>
        """
        webView.loadHTMLString(html, baseURL: appURL)
    }
}

// MARK: - WKNavigationDelegate

extension WebViewController: WKNavigationDelegate {

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow); return
        }

        // Same-host navigation stays inside the webview
        if url.host == appHost || url.scheme == "about" || url.scheme == "blob" {
            decisionHandler(.allow); return
        }

        // System URL schemes
        if ["mailto", "tel", "sms", "maps"].contains(url.scheme ?? "") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            decisionHandler(.cancel); return
        }

        // All other HTTP(S) links open in an in-app Safari sheet
        if url.scheme == "https" || url.scheme == "http" {
            let safari = SFSafariViewController(url: url)
            safari.preferredControlTintColor = UIColor(
                red: 61/255, green: 107/255, blue: 82/255, alpha: 1)
            present(safari, animated: true)
            decisionHandler(.cancel); return
        }

        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        refreshControl.endRefreshing()
        registerAPNSToken()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        refreshControl.endRefreshing()
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        refreshControl.endRefreshing()
        let code = (error as NSError).code
        guard code != NSURLErrorCancelled else { return }
        showOfflinePage()
    }
}

// MARK: - WKUIDelegate

extension WebViewController: WKUIDelegate {

    // Handle window.open() — keep it inside the webview
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        present(alert, animated: true)
    }
}
