import XCTest
import StyleVaultCore
@testable import StyleVaultNative

final class LocalizationTests: XCTestCase {
    func testOgniEtichettaHaItalianoEInglese() throws {
        let keys = Catalog.categories.flatMap { [$0.labelKey] + $0.subcategories.map(\.labelKey) }
            + Catalog.seasons.map(\.labelKey) + Catalog.occasions.map(\.labelKey) + Catalog.colors.map(\.labelKey)
            + ["nav.wardrobe", "nav.outfit", "nav.add", "nav.calendar", "nav.profile", "native.sync.off"]
        for language in ["it", "en"] {
            let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"))
            let bundle = try XCTUnwrap(Bundle(path: path))
            for key in keys {
                XCTAssertNotEqual(bundle.localizedString(forKey: key, value: key, table: nil), key, "\(language): \(key)")
            }
        }
    }
}
