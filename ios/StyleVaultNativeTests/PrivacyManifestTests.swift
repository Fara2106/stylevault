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

    /// Con l'account l'app raccoglie email, nome e identificativo, solo per farlo funzionare.
    func testDichiaraIDatiDellAccount() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil)
        let manifest = try XCTUnwrap(plist as? [String: Any])
        let collected = try XCTUnwrap(manifest["NSPrivacyCollectedDataTypes"] as? [[String: Any]])

        XCTAssertEqual(Set(collected.compactMap { $0["NSPrivacyCollectedDataType"] as? String }), [
            "NSPrivacyCollectedDataTypeEmailAddress", "NSPrivacyCollectedDataTypeName",
            "NSPrivacyCollectedDataTypeUserID",
        ])
        for type in collected {
            XCTAssertEqual(type["NSPrivacyCollectedDataTypeLinked"] as? Bool, true)
            XCTAssertEqual(type["NSPrivacyCollectedDataTypeTracking"] as? Bool, false)
            XCTAssertEqual(type["NSPrivacyCollectedDataTypePurposes"] as? [String],
                           ["NSPrivacyCollectedDataTypePurposeAppFunctionality"])
        }
    }
}
