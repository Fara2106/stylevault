import XCTest
@testable import StyleVaultCore

final class WardrobeFilterTests: XCTestCase {
    func testRicercaSuNomeEBrandSenzaMaiuscole() {
        let f = WardrobeFilter(search: "  ZARA ")
        XCTAssertTrue(f.matches(name: "Camicia", brand: "Zara", category: "tops", favorite: false))
        XCTAssertTrue(f.matches(name: "zara basic", brand: nil, category: "tops", favorite: false))
        XCTAssertFalse(f.matches(name: "Camicia", brand: nil, category: "tops", favorite: false))
    }

    func testCategoriaEPreferitiSiSommano() {
        let f = WardrobeFilter(category: "shoes", onlyFavorites: true)
        XCTAssertTrue(f.matches(name: "A", brand: nil, category: "shoes", favorite: true))
        XCTAssertFalse(f.matches(name: "A", brand: nil, category: "shoes", favorite: false))
        XCTAssertFalse(f.matches(name: "A", brand: nil, category: "tops", favorite: true))
    }

    func testFiltroVuotoPrendeTutto() {
        XCTAssertTrue(WardrobeFilter().matches(name: "", brand: nil, category: "", favorite: false))
    }
}
