import Foundation
import WebKit

/// Tiene la WKWebView del sito e il suo stato: il ponte "svNative", la
/// schermata offline e il passaggio della sessione dal login nativo.
@MainActor
final class WebViewStore: NSObject, ObservableObject {
    let webView: WKWebView
    @Published private(set) var offline = false
    var onMessage: (BridgeMessage) -> Void = { _ in }

    /// Ultima sessione nota: la si ripassa a ogni caricamento della pagina.
    private var session: (access: String, refresh: String)?

    override init() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        config.userContentController.add(WeakHandler(self), name: "svNative")
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        // Le zone sicure le gestisce il CSS (env(safe-area-inset-*)): niente
        // rientri automatici della scroll view, sennò si sommano o spariscono
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        #if DEBUG
        webView.isInspectable = true
        #endif
    }

    func load() {
        offline = false
        webView.load(URLRequest(url: AppConfig.siteURL))
    }

    func injectSession(access: String, refresh: String) {
        session = (access, refresh)
        pushSession()
    }

    private func pushSession() {
        guard let session else { return }
        let args = [session.access, session.refresh]
            .map { "'\($0.replacingOccurrences(of: "'", with: "\\'"))'" }
            .joined(separator: ",")
        webView.evaluateJavaScript("window.svNative && window.svNative.setSession(\(args))")
    }

    /// Errori che significano "niente rete": mostrano la schermata offline.
    nonisolated static func isOfflineError(_ error: Error) -> Bool {
        let error = error as NSError
        guard error.domain == NSURLErrorDomain else { return false }
        return [NSURLErrorNotConnectedToInternet, NSURLErrorCannotFindHost,
                NSURLErrorNetworkConnectionLost, NSURLErrorTimedOut,
                NSURLErrorCannotConnectToHost].contains(error.code)
    }
}

extension WebViewStore: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        pushSession()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        if Self.isOfflineError(error) { offline = true }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if Self.isOfflineError(error) { offline = true }
    }
}

/// WKUserContentController trattiene forte l'handler: questo ponte evita il ciclo.
private final class WeakHandler: NSObject, WKScriptMessageHandler {
    weak var store: WebViewStore?
    init(_ store: WebViewStore) { self.store = store }

    func userContentController(_ controller: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard let parsed = BridgeMessage.parse(message.body) else { return }
        MainActor.assumeIsolated { store?.onMessage(parsed) }
    }
}
