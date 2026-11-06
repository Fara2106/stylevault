import XCTest

/// Le foto del corpo nel Profilo e "Vedilo addosso". Vision non gira nel simulatore: analisi e
/// composizione sono finte, quelle vere si provano sul Mac con `swift test` e sul telefono.
final class BodyPhotoFlowTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private let outfit = ["-SVFakeForecast", "-SVSeedWardrobe", "-SVFakeBody"]

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func openCard(_ app: XCUIApplication) {
        tab(app, "Outfit").tap()
        let button = app.buttons["outfit-avatar"].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 30))
        for _ in 0..<6 where !button.isHittable { app.swipeUp() }
        button.tap()
    }

    func testIlProfiloHaLeTreFotoESpiegaCheFareNeSpiega() {
        let app = launch(language: "it", extra: ["-SVFakeBody"])
        tab(app, "Profilo").tap()
        for view in ["front", "side", "back"] {
            XCTAssertTrue(element(app, "body-photo-\(view)").waitForExistence(timeout: 30))
        }
        element(app, "body-photo-front").tap()
        XCTAssertTrue(element(app, "body-guide").waitForExistence(timeout: 30))
        XCTAssertTrue(element(app, "body-notice").exists)
        XCTAssertTrue(element(app, "body-library").exists)
        XCTAssertFalse(app.buttons["body-delete"].exists, "non c'è ancora niente da cancellare")
    }

    func testUnaFotoSalvataSiPuoCancellare() {
        let app = launch(language: "it", extra: ["-SVFakeBody", "-SVSeedBodyPhoto"])
        tab(app, "Profilo").tap()
        let tile = element(app, "body-photo-front")
        XCTAssertTrue(tile.waitForExistence(timeout: 30))
        XCTAssertFalse(tile.staticTexts["Manca"].exists)
        tile.tap()
        let delete = app.buttons["body-delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 30))
        delete.tap()
        let confirm = app.alerts.buttons["Elimina"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 30))
        confirm.tap()
        XCTAssertTrue(element(app, "body-library").waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["body-delete"].exists)
    }

    func testSenzaFotoLAvatarPortaAdAggiungerla() {
        let app = launch(language: "it", extra: outfit)
        openCard(app)
        let add = app.buttons["avatar-add-photo"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 30))
        add.tap()
        XCTAssertTrue(element(app, "body-guide").waitForExistence(timeout: 30))
    }

    func testConLaFotoLOutfitSiVedeAddosso() {
        let app = launch(language: "it", extra: outfit + ["-SVSeedBodyPhoto"])
        openCard(app)
        XCTAssertTrue(element(app, "avatar-image-front").waitForExistence(timeout: 30))
    }
}
