import XCTest
@testable import StyleVault

final class DeviceInfoTests: XCTestCase {
    func testVersioneDellAppConBuild() {
        let info = ["CFBundleShortVersionString": "0.1.0", "CFBundleVersion": "7"]
        XCTAssertEqual(DeviceInfo.appVersion(from: info), "0.1.0 (7)")
        XCTAssertEqual(DeviceInfo.appVersion(from: nil), "? (?)")
    }

    func testModelloVeroOSimulato() {
        XCTAssertEqual(DeviceInfo.model(machine: "iPhone18,2", environment: [:]), "iPhone18,2")
        XCTAssertEqual(
            DeviceInfo.model(machine: "arm64", environment: ["SIMULATOR_MODEL_IDENTIFIER": "iPhone18,1"]),
            "iPhone18,1 (simulatore)"
        )
    }

    func testLoScriptEspongeSoloLeTreInfo() throws {
        let script = DeviceInfo(appVersion: "0.1.0 (1)", osVersion: "iOS 27.0", model: "iPhone18,2").script
        XCTAssertTrue(script.hasPrefix("window.svDeviceInfo = "))
        let json = String(script.dropFirst("window.svDeviceInfo = ".count).dropLast())
        let decoded = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: String]
        XCTAssertEqual(decoded, ["appVersion": "0.1.0 (1)", "osVersion": "iOS 27.0", "model": "iPhone18,2"])
    }

    @MainActor func testInfoCorrentiNelSimulatore() {
        let info = DeviceInfo.current
        XCTAssertTrue(info.osVersion.hasPrefix("iOS "))
        XCTAssertFalse(info.model.isEmpty)
        XCTAssertFalse(info.appVersion.hasPrefix("?"))
    }
}
