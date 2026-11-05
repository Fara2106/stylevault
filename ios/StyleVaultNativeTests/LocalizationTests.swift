import XCTest
import StyleVaultCore
@testable import StyleVaultNative

final class LocalizationTests: XCTestCase {
    private static let wardrobeKeys: [String] =
        ["title", "emptyState", "emptyAction", "deleteConfirm", "searchPlaceholder", "tabWardrobe", "tabWishlist"]
            .map { "wardrobe.\($0)" }
        + ["title", "subtitle", "bought", "emptyState", "emptyAction", "moveToWardrobe", "openLink"]
            .map { "wishlist.\($0)" }
        + ["title", "photo", "link", "uploadPhoto", "takePhoto", "pasteLink", "analyzeLink", "itemName", "category",
           "subcategory", "brand", "size", "colors", "season", "occasion", "warmth", "photoHint", "changePhoto", "price",
           "destination", "toWardrobe", "toWishlist", "linkLoading", "linkError", "linkSuccess", "nameRequired",
           "categoryRequired", "photoBack", "photoBackHint", "photoBackAdd", "photoBackRemove",
           "warmthLevels.1", "warmthLevels.2", "warmthLevels.3", "warmthLevels.4", "warmthLevels.5"]
            .map { "addItem.\($0)" }
        + ["title", "openShop", "deleteItem"].map { "itemDetail.\($0)" }
        + ["save", "cancel", "delete", "edit", "close", "all", "favorites", "noResults", "optional"].map { "common.\($0)" }
        + ["form.priceInvalid", "form.photoError", "form.discard.title", "form.discard.confirm", "form.discard.keep",
           "category.new", "category.name", "category.delete", "category.inUse", "detail.photoBack", "detail.cutout"]
            .map { "native.\($0)" }

    func testOgniEtichettaHaItalianoEInglese() throws {
        let keys = Catalog.categories.flatMap { [$0.labelKey] + $0.subcategories.map(\.labelKey) }
            + Catalog.seasons.map(\.labelKey) + Catalog.occasions.map(\.labelKey) + Catalog.colors.map(\.labelKey)
            + ["nav.wardrobe", "nav.outfit", "nav.add", "nav.calendar", "nav.profile", "native.sync.off"]
            + Self.wardrobeKeys
        for language in ["it", "en"] {
            let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"))
            let bundle = try XCTUnwrap(Bundle(path: path))
            for key in keys {
                XCTAssertNotEqual(bundle.localizedString(forKey: key, value: key, table: nil), key, "\(language): \(key)")
            }
        }
    }

    func testIlContoDeiCapiHaIlPlurale() throws {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "it", ofType: "lproj"))
        let bundle = try XCTUnwrap(Bundle(path: path))
        let format = bundle.localizedString(forKey: "native.wardrobe.count %lld", value: nil, table: nil)
        XCTAssertEqual(String.localizedStringWithFormat(format, 1), "1 capo")
        XCTAssertEqual(String.localizedStringWithFormat(format, 3), "3 capi")
    }

    func testLaFotocameraHaIlMotivoNelleDueLingue() throws {
        for language in ["it", "en"] {
            let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"))
            let bundle = try XCTUnwrap(Bundle(path: path))
            XCTAssertNotEqual(bundle.localizedString(forKey: "NSCameraUsageDescription", value: nil, table: "InfoPlist"),
                              "NSCameraUsageDescription", language)
        }
    }
}
