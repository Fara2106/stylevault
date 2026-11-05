import XCTest
import StyleVaultCore

final class SmokeTests: XCTestCase {
    func testIlPacchettoCoreERaggiungibile() {
        XCTAssertEqual(Catalog.categories.count, 7)
    }
}
