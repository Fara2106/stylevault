import Foundation
import UIKit
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
        // Per le segnalazioni del Feedback: versione app, iOS e modello
        config.userContentController.addUserScript(WKUserScript(
            source: DeviceInfo.current.script, injectionTime: .atDocumentStart, forMainFrameOnly: true
        ))
        webView.navigationDelegate = self
        webView.uiDelegate = self
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

    /// Chiamata quando il sito dice "ready": solo allora window.svNative esiste.
    func pushSession() {
        guard let session, Self.isSiteURL(webView.url) else { return }
        let args = [session.access, session.refresh]
            .map { "'\($0.replacingOccurrences(of: "'", with: "\\'"))'" }
            .joined(separator: ",")
        webView.evaluateJavaScript("window.svNative && window.svNative.setSession(\(args))")
    }

    /// Solo le pagine del sito ricevono la sessione e possono mandare messaggi.
    nonisolated static func isSiteURL(_ url: URL?) -> Bool {
        guard let url else { return false }
        return url.scheme == AppConfig.siteURL.scheme && url.host == AppConfig.siteURL.host
            && url.port == AppConfig.siteURL.port
    }

    /// Link http(s) fuori dal sito (negozi, ChatGPT, Gemini): si aprono in Safari.
    nonisolated static func opensExternally(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else { return false }
        return !isSiteURL(url)
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

extension WebViewStore: WKNavigationDelegate, WKUIDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url, Self.opensExternally(url) {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }

    /// target="_blank" e window.open: WKWebView li ignora senza questo.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url { UIApplication.shared.open(url) }
        return nil
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
        guard message.frameInfo.isMainFrame, WebViewStore.isSiteURL(message.frameInfo.request.url),
              let parsed = BridgeMessage.parse(message.body) else { return }
        MainActor.assumeIsolated {
            if parsed == .ready { store?.pushSession() }
            store?.onMessage(parsed)
        }
    }
}
