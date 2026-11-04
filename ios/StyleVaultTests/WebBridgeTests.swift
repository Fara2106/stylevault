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

    func testDescriptorOpzionaleNelPayload() {
        func parse(_ extra: [String: Any]) -> AvatarItem? {
            var item: [String: Any] = ["id": "1", "category": "tops", "slot": "top",
                                       "photo": "https://x/a.jpg", "name": "Maglione"]
            item.merge(extra) { $1 }
            guard case let .openAvatar(request)? = BridgeMessage.parse(
                ["type": "openAvatar", "payload": ["items": [item]]]) else { return nil }
            return request.items.first
        }
        XCTAssertNil(parse([:])?.descriptor)
        XCTAssertEqual(parse(["descriptor": "cream sweater"])?.descriptor, "cream sweater")
    }

    func testMessaggiSemplici() {
        XCTAssertEqual(BridgeMessage.parse(["type": "signOut"]), .signOut)
        XCTAssertEqual(
            BridgeMessage.parse(["type": "themeChanged", "payload": ["setting": "dark"]]),
            .themeChanged("dark")
        )
    }

    func testIlSitoEProntoARicevereLaSessione() {
        XCTAssertEqual(BridgeMessage.parse(["type": "ready"]), .ready)
    }

    func testMessaggiSconosciutiONonValidi() {
        XCTAssertNil(BridgeMessage.parse(["type": "boh"]))
        XCTAssertNil(BridgeMessage.parse("stringa"))
        XCTAssertNil(BridgeMessage.parse(["type": "openAvatar", "payload": ["items": "no"]]))
    }

    func testRequestLocation() {
        XCTAssertEqual(BridgeMessage.parse(["type": "requestLocation"]), .requestLocation)
    }

    func testRequestForecast() {
        let body: [String: Any] = ["type": "requestForecast",
                                   "payload": ["latitude": 41.9, "longitude": 12.5, "name": "Roma"]]
        XCTAssertEqual(BridgeMessage.parse(body),
                       .requestForecast(ForecastRequest(latitude: 41.9, longitude: 12.5, name: "Roma")))
        XCTAssertNil(BridgeMessage.parse(["type": "requestForecast", "payload": ["longitude": 12.5]]))
    }
}
