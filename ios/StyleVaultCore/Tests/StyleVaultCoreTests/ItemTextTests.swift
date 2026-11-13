import XCTest
@testable import StyleVaultCore

final class ItemTextTests: XCTestCase {
    func testIniziale() {
        XCTAssertEqual(ItemText.placeholderInitial("maglione blu"), "M")
        XCTAssertEqual(ItemText.placeholderInitial("  èlite"), "È")
        XCTAssertEqual(ItemText.placeholderInitial(""), "·")
        XCTAssertEqual(ItemText.placeholderInitial(nil), "·")
    }

    func testPrezzo() {
        XCTAssertEqual(ItemText.parsePrice(""), .empty)
        XCTAssertEqual(ItemText.parsePrice("  "), .empty)
        XCTAssertEqual(ItemText.parsePrice("12"), .value(12))
        XCTAssertEqual(ItemText.parsePrice("12,50"), .value(12.5))
        XCTAssertEqual(ItemText.parsePrice("12.50"), .value(12.5))
        XCTAssertEqual(ItemText.parsePrice("0"), .value(0))
        XCTAssertEqual(ItemText.parsePrice("abc"), .invalid)
        XCTAssertEqual(ItemText.parsePrice("-5"), .invalid)
        XCTAssertEqual(ItemText.parsePrice("1.234,50"), .invalid)
    }
}
