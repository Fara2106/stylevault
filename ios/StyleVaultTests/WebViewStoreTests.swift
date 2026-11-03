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
}
