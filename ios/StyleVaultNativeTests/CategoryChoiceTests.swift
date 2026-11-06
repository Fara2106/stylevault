import XCTest
@testable import StyleVaultNative

final class CategoryChoiceTests: XCTestCase {
    func testUnNomeDelCatalogoPortaAQuellaCategoria() {
        XCTAssertEqual(CategoryChoice.catalogID(named: "Top"), "tops")
        XCTAssertEqual(CategoryChoice.catalogID(named: "  tOP "), "tops")
    }

    func testUnNomeNuovoNonEDelCatalogo() {
        XCTAssertNil(CategoryChoice.catalogID(named: "Mare"))
        XCTAssertNil(CategoryChoice.catalogID(named: "   "))
    }
}
