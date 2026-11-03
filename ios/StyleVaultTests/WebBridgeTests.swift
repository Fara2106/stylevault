import XCTest
@testable import StyleVault

final class WebBridgeTests: XCTestCase {
    func testOpenAvatarConUnCapoSenzaRetro() {
        let body: [String: Any] = [
            "type": "openAvatar",
            "payload": ["items": [[
                "id": "1", "category": "tops", "slot": "top",
                "photo": "https://x/a.jpg", "name": "Maglione",
            ]]],
        ]
        guard case let .openAvatar(request)? = BridgeMessage.parse(body) else {
            return XCTFail("atteso openAvatar")
        }
        XCTAssertEqual(request.items.count, 1)
        XCTAssertEqual(request.items[0].slot, "top")
        XCTAssertNil(request.items[0].photoBack)
    }

    func testMessaggiSemplici() {
        XCTAssertEqual(BridgeMessage.parse(["type": "signOut"]), .signOut)
        XCTAssertEqual(
            BridgeMessage.parse(["type": "themeChanged", "payload": ["setting": "dark"]]),
            .themeChanged("dark")
        )
    }

    func testMessaggiSconosciutiONonValidi() {
        XCTAssertNil(BridgeMessage.parse(["type": "boh"]))
        XCTAssertNil(BridgeMessage.parse("stringa"))
        XCTAssertNil(BridgeMessage.parse(["type": "openAvatar", "payload": ["items": "no"]]))
    }
}
