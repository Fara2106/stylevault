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

    func testAltriErroriNonSonoOffline() {
        // Navigazione annullata (es. un link cliccato due volte): non è offline
        XCTAssertFalse(WebViewStore.isOfflineError(NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)))
        XCTAssertFalse(WebViewStore.isOfflineError(NSError(domain: "altro", code: -1009)))
    }
}
