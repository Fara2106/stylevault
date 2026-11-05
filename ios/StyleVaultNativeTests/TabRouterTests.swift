import XCTest
@testable import StyleVaultNative

final class TabRouterTests: XCTestCase {
    func testAggiungiApreIlFoglioELasciaLaTab() {
        var r = TabRouter(); r.select(.calendar); r.select(.add)
        XCTAssertEqual(r.selected, .calendar)
        XCTAssertTrue(r.isAddSheetPresented)
    }

    func testLeAltreTabCambianoSoltanto() {
        var r = TabRouter(); r.select(.profile)
        XCTAssertEqual(r.selected, .profile)
        XCTAssertFalse(r.isAddSheetPresented)
    }
}
