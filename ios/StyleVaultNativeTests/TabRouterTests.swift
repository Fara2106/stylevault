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

    func testAggiungiDallaWishlist() {
        var router = TabRouter()
        router.selected = .profile
        router.openAdd(to: .wishlist)
        XCTAssertTrue(router.isAddSheetPresented)
        XCTAssertEqual(router.addDestination, .wishlist)
        XCTAssertEqual(router.selected, .profile)
    }

    func testIlTastoPiuTornaAlGuardaroba() {
        var router = TabRouter()
        router.openAdd(to: .wishlist)
        router.isAddSheetPresented = false
        router.select(.add)
        XCTAssertEqual(router.addDestination, .wardrobe)
    }
}
