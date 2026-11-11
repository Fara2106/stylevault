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
        + ["subtitle", "generateOutfit", "regenerate", "regenerateHint", "today", "tomorrow", "noOutfits", "noItemsForOutfit",
           "missingPiece.top", "missingPiece.bottom", "missingPiece.shoes", "outfitScore", "weatherMatch", "colorMatch",
           "wearThis", "saved", "top", "bottom", "shoes", "outerwear", "accessoriesLabel", "dress", "lockItem", "unlockItem",
           "adviceTitle", "manualWeather", "manualTemp", "manualRain", "myPosition", "chosenByHand", "location"]
            .map { "outfit.\($0)" }
        + ["colorsHarmonious", "colorsClash", "tooManyColors", "monochrome", "perfectWarmth", "rainShoes", "rainOuter",
           "elevated", "uvHigh", "windStrong"].map { "advice.\($0)" }
        + ["title", "subtitle", "noOutfit", "planned", "worn", "markWorn", "assignOutfit", "pickOutfit", "noSavedOutfits",
           "customOutfit", "removeEntry"].map { "calendar.\($0)" }
        + ["cloudy", "rainy", "snow", "clear", "partlyCloudy", "fog", "drizzle", "thunderstorm",
           "part.morning", "part.afternoon", "part.evening", "partTitle.morning", "partTitle.afternoon", "partTitle.evening"]
            .map { "weather.\($0)" }
        + ["stats", "totalOutfits", "statsMostWorn", "statsLeastWorn", "statsByCategory", "statsByColor", "statsCostPerWear",
           "statsNoData", "statsNever"].map { "profile.\($0)" }
        + ["native.outfit.saved.title", "native.outfit.saved.empty", "common.loading", "native.wardrobe.emptyHint"]
        + ["native.avatar.realistic"]
        + ["title", "intro", "time", "generate", "again", "keepOpen", "pausedHeat", "pausedBackground", "failed", "aiLabel",
           "imageLabel", "share", "report", "stopTitle", "stopConfirm", "stopKeep"].map { "native.realistic.\($0)" }
        + ["bodyPhotosTitle", "bodyPhotosHintWeb", "bodyPhotoMissing", "bodyViewFront", "bodyViewSide", "bodyViewBack",
           "ownPhotoNotice"].map { "profile.\($0)" }
        + ["guide.front", "guide.side", "guide.back", "check.noPerson", "check.multiplePeople", "check.notFullBody",
           "check.wrongView.front", "check.wrongView.side", "check.wrongView.back", "use", "retake", "delete",
           "deleteConfirm", "analyzeError", "saveError"].map { "native.body.\($0)" }
        + ["title", "preparing", "failed", "addPhoto", "changePhoto", "missing.front", "missing.side", "missing.back"]
            .map { "native.avatar.\($0)" }

    func testIlMotivoDellaPosizioneHaLeDueLingue() throws {
        for language in ["it", "en"] {
            let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"))
            let bundle = try XCTUnwrap(Bundle(path: path))
            XCTAssertNotEqual(bundle.localizedString(forKey: "NSLocationWhenInUseUsageDescription", value: nil, table: "InfoPlist"),
                              "NSLocationWhenInUseUsageDescription", language)
        }
    }

    func testGliUtilizziHannoIlPlurale() throws {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "it", ofType: "lproj"))
        let bundle = try XCTUnwrap(Bundle(path: path))
        let format = bundle.localizedString(forKey: "profile.statsWears %lld", value: nil, table: nil)
        XCTAssertEqual(String.localizedStringWithFormat(format, 1), "1 utilizzo")
        XCTAssertEqual(String.localizedStringWithFormat(format, 3), "3 utilizzi")
    }

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
