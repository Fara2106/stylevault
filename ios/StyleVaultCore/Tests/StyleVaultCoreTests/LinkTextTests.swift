import XCTest
@testable import StyleVaultCore

/// Casi presi da src/services/linkMetadata.test.js.
final class LinkTextTests: XCTestCase {
    func testURL() {
        XCTAssertEqual(LinkText.httpURL(from: " https://zara.com/p/1\n")?.absoluteString, "https://zara.com/p/1")
        XCTAssertNotNil(LinkText.httpURL(from: "http://example.com"))
        XCTAssertNil(LinkText.httpURL(from: "ftp://x.com"))
        XCTAssertNil(LinkText.httpURL(from: "non-un-url"))
        XCTAssertNil(LinkText.httpURL(from: "https://"))
        XCTAssertNil(LinkText.httpURL(from: ""))
    }

    func testTitoloSenzaNegozio() {
        XCTAssertEqual(LinkText.stripShopSuffix("Camicia in lino - Zara", site: "Zara"), "Camicia in lino")
        XCTAssertEqual(LinkText.stripShopSuffix("Polo Club RIGBY GO U - Maglione - ecru/bianco - Zalando.it", site: "zalando.it"),
                       "Polo Club RIGBY GO U - Maglione - ecru/bianco")
        XCTAssertEqual(LinkText.stripShopSuffix("Pantaloni chino", site: "Shop"), "Pantaloni chino")
        XCTAssertEqual(LinkText.stripShopSuffix("T-shirt - Blu", site: "Zara"), "T-shirt - Blu")
    }

    func testNomeDelNegozio() {
        XCTAssertEqual(LinkText.siteName(host: "www.zalando.it"), "Zalando")
        XCTAssertEqual(LinkText.siteName(host: "www2.hm.com"), "Hm")
        XCTAssertEqual(LinkText.siteName(host: "www.zalando.co.uk"), "Zalando")
        XCTAssertEqual(LinkText.siteName(host: "shop.example.com"), "Example")
        XCTAssertEqual(LinkText.siteName(host: "localhost"), "Localhost")
    }

    func testPagineBloccate() {
        XCTAssertTrue(LinkText.isBlockedTitle("Access Denied"))
        XCTAssertTrue(LinkText.isBlockedTitle("  just a moment..."))
        XCTAssertTrue(LinkText.isBlockedTitle("403 Forbidden"))
        XCTAssertTrue(LinkText.isBlockedTitle("Page not found"))
        XCTAssertFalse(LinkText.isBlockedTitle("Maglione a trecce"))
    }
}
