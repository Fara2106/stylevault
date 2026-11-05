import XCTest
@testable import StyleVaultCore

private struct SiteCatalog: Decodable {
    struct Sub: Decodable { let id: String; let labelKey: String }
    struct Cat: Decodable { let id: String; let icon: String; let labelKey: String; let subcategories: [Sub] }
    struct Choice: Decodable { let id: String; let labelKey: String; let icon: String }
    struct Color: Decodable { let id: String; let hex: String; let labelKey: String }
    let categories: [Cat]
    let seasons: [Choice]
    let occasions: [Choice]
    let colors: [Color]
}

final class CatalogTests: XCTestCase {
    private func loadFixture() throws -> SiteCatalog {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "catalog", withExtension: "json", subdirectory: "Fixtures"))
        return try JSONDecoder().decode(SiteCatalog.self, from: Data(contentsOf: url))
    }

    func testCoincideColSito() throws {
        let site = try loadFixture()
        XCTAssertEqual(
            Catalog.categories,
            site.categories.map { c in
                WardrobeCategory(id: c.id, icon: c.icon, labelKey: c.labelKey,
                                 subcategories: c.subcategories.map { Subcategory(id: $0.id, labelKey: $0.labelKey) })
            })
        XCTAssertEqual(Catalog.seasons, site.seasons.map { ChoiceOption(id: $0.id, labelKey: $0.labelKey, icon: $0.icon) })
        XCTAssertEqual(Catalog.occasions, site.occasions.map { ChoiceOption(id: $0.id, labelKey: $0.labelKey, icon: $0.icon) })
        XCTAssertEqual(Catalog.colors, site.colors.map { ClothingColor(id: $0.id, hex: $0.hex, labelKey: $0.labelKey) })
    }

    func testColorePerId() {
        XCTAssertEqual(Catalog.color(id: "navy")?.hex, "#1B2A4A")
        XCTAssertNil(Catalog.color(id: "boh"))
    }

    func testCategoriaSconosciutaNonEsiste() {
        XCTAssertNil(Catalog.category(id: "boh"))
        XCTAssertEqual(Catalog.category(id: "shoes")?.icon, "👟")
    }
}
