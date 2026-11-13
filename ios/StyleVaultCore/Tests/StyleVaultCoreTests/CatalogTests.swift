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

    func testIlCaloreDiPartenzaSegueIlTipoDiCapo() {
        XCTAssertEqual(Catalog.defaultWarmth(category: "outerwear", subcategory: "coat"), 5)
        XCTAssertEqual(Catalog.defaultWarmth(category: "outerwear", subcategory: "blazer"), 3)
        XCTAssertEqual(Catalog.defaultWarmth(category: "tops", subcategory: "sweater"), 4)
        XCTAssertEqual(Catalog.defaultWarmth(category: "tops", subcategory: "tank"), 1)
        XCTAssertEqual(Catalog.defaultWarmth(category: "shoes", subcategory: "sandals"), 1)
    }

    func testSenzaTipoIlCaloreSegueLaCategoria() {
        XCTAssertEqual(Catalog.defaultWarmth(category: "outerwear", subcategory: nil), 4)
        XCTAssertEqual(Catalog.defaultWarmth(category: "bottoms", subcategory: nil), 3)
        XCTAssertEqual(Catalog.defaultWarmth(category: "tops", subcategory: "boh"), 2)
        XCTAssertEqual(Catalog.defaultWarmth(category: "accessories", subcategory: "belt"), 2)
        XCTAssertEqual(Catalog.defaultWarmth(category: "", subcategory: nil), 2)
    }

    func testOgniTipoDiCapoCheContaPerIlMeteoHaIlSuoCalore() {
        for category in Catalog.categories where ["tops", "bottoms", "outerwear", "dresses", "shoes"].contains(category.id) {
            for sub in category.subcategories {
                XCTAssertTrue((1...5).contains(Catalog.defaultWarmth(category: category.id, subcategory: sub.id)), sub.id)
            }
        }
    }

    /// Il caso da cui è nata la regola: a 12° camicia, jeans, sneakers e cappotto non sono «troppo leggeri».
    func testConIlCappottoADodiciGradiNonETroppoLeggero() {
        let levels = [("tops", "shirt"), ("bottoms", "jeans"), ("shoes", "sneakers"), ("outerwear", "coat")]
            .map { Catalog.defaultWarmth(category: $0.0, subcategory: $0.1) }
        let average = Double(levels.reduce(0, +)) / Double(levels.count)
        let target = Double(OutfitEngine.warmthTarget(temperature: 12, windSpeed: 5))
        XCTAssertGreaterThanOrEqual(average, target - 1)
        // Anche senza scegliere il tipo: solo le categorie.
        let plain = ["tops", "bottoms", "shoes", "outerwear"].map { Catalog.defaultWarmth(category: $0, subcategory: nil) }
        XCTAssertGreaterThanOrEqual(Double(plain.reduce(0, +)) / Double(plain.count), target - 1)
    }

    func testCategoriaSconosciutaNonEsiste() {
        XCTAssertNil(Catalog.category(id: "boh"))
        XCTAssertEqual(Catalog.category(id: "shoes")?.icon, "👟")
    }
}
