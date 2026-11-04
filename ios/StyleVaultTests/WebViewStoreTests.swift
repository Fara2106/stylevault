import WebKit
import XCTest
@testable import StyleVault

final class WebViewStoreTests: XCTestCase {
    func testErroriDiReteMostranoOffline() {
        for code in [NSURLErrorNotConnectedToInternet, NSURLErrorCannotFindHost,
                     NSURLErrorNetworkConnectionLost, NSURLErrorTimedOut,
                     NSURLErrorCannotConnectToHost] {
            let error = NSError(domain: NSURLErrorDomain, code: code)
            XCTAssertTrue(WebViewStore.isOfflineError(error), "codice \(code)")
        }
    }

    // Review I1/I2: la sessione e i messaggi valgono solo per il sito;
    // i link esterni (negozi, ChatGPT, Gemini) si aprono fuori dall'app
    func testSoloIlSitoRiceveLaSessione() {
        XCTAssertTrue(WebViewStore.isSiteURL(AppConfig.siteURL.appendingPathComponent("wardrobe")))
        XCTAssertFalse(WebViewStore.isSiteURL(URL(string: "https://evil.example/stylevault/")!))
        XCTAssertFalse(WebViewStore.isSiteURL(nil))
    }

    func testLinkEsterniFuoriDallApp() {
        XCTAssertTrue(WebViewStore.opensExternally(URL(string: "https://gemini.google.com/")!))
        XCTAssertTrue(WebViewStore.opensExternally(URL(string: "https://www.zalando.it/p.html")!))
        XCTAssertFalse(WebViewStore.opensExternally(AppConfig.siteURL))
        XCTAssertFalse(WebViewStore.opensExternally(URL(string: "about:blank")!))
    }

    func testAltriErroriNonSonoOffline() {
        // Navigazione annullata (es. un link cliccato due volte): non è offline
        XCTAssertFalse(WebViewStore.isOfflineError(NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)))
        XCTAssertFalse(WebViewStore.isOfflineError(NSError(domain: "altro", code: -1009)))
    }

    func testCallScriptConApici() throws {
        let place = PlacePayload(latitude: 42.35, longitude: 13.4, name: "L'Aquila")
        let script = WebViewStore.callScript("setLocation", json: try JSONEncoder().encode(place))
        XCTAssertTrue(script.hasPrefix("window.svNative && window.svNative.setLocation && window.svNative.setLocation("))
        XCTAssertTrue(script.hasSuffix(")"))
        // L'argomento è JSON valido, apostrofo compreso
        let start = script.index(script.firstIndex(of: "{")!, offsetBy: 0)
        let json = String(script[start..<script.index(before: script.endIndex)])
        let back = try JSONDecoder().decode([String: AnyDecodable].self, from: Data(json.utf8))
        XCTAssertEqual(back["name"]?.string, "L'Aquila")
    }

    /// Il sito si riconosce "dentro l'app" da window.webkit.messageHandlers.svNative:
    /// senza, nasconde "Rifai le foto del corpo", il meteo del telefono e l'avatar.
    @MainActor
    func testIlSitoVedeIlPonteSvNative() async throws {
        let store = WebViewStore()
        let loaded = expectation(description: "pagina caricata")
        let delegate = LoadWaiter { loaded.fulfill() }
        store.webView.navigationDelegate = delegate
        store.webView.loadHTMLString("<html><body>ok</body></html>", baseURL: AppConfig.siteURL)
        await fulfillment(of: [loaded], timeout: 10)
        let kind = try await store.webView.evaluateJavaScript(
            "typeof (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.svNative)"
        ) as? String
        XCTAssertEqual(kind, "object")
        withExtendedLifetime(delegate) {}
    }
}

/// Solo per leggere un JSON qualsiasi nei test.
private struct AnyDecodable: Decodable {
    let string: String?
    init(from decoder: Decoder) throws {
        string = try? decoder.singleValueContainer().decode(String.self)
    }
}

private final class LoadWaiter: NSObject, WKNavigationDelegate {
    let done: () -> Void
    init(done: @escaping () -> Void) { self.done = done }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { done() }
}
