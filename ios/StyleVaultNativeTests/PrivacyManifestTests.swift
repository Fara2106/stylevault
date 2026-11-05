import XCTest

final class PrivacyManifestTests: XCTestCase {
    /// Senza questa voce Apple rifiuta il caricamento con ITMS-91053: l'app usa UserDefaults.
    func testDichiaraUserDefaultsSenzaTracciamento() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil)
        let manifest = try XCTUnwrap(plist as? [String: Any])

        XCTAssertEqual(manifest["NSPrivacyTracking"] as? Bool, false)
        let types = try XCTUnwrap(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let defaults = types.first { $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults" }
        XCTAssertEqual(defaults?["NSPrivacyAccessedAPITypeReasons"] as? [String], ["CA92.1"])
    }
}
