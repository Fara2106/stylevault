import XCTest

final class WardrobeFlowTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func openForm(_ app: XCUIApplication) -> XCUIElement {
        tab(app, "Aggiungi").tap()
        let sheet = app.otherElements["add-sheet"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))
        return sheet
    }

    func testFoglioVuotoSiChiudeSenzaDomande() {
        let app = launch(language: "it")
        let sheet = openForm(app)
        app.buttons["item-close"].tap()
        XCTAssertTrue(waitForDisappearance(of: sheet))
    }

    func testBozzaChiedeConferma() {
        let app = launch(language: "it")
        let sheet = openForm(app)
        let name = app.textFields["item-name"]
        name.tap()
        name.typeText("Giacca")
        app.buttons["item-close"].tap()
        let keep = app.buttons["Continua a modificare"]
        XCTAssertTrue(keep.waitForExistence(timeout: 3))
        keep.tap()
        XCTAssertTrue(sheet.exists)
        XCTAssertEqual(name.value as? String, "Giacca")
        app.buttons["item-close"].tap()
        let discard = app.buttons["Scarta"]
        XCTAssertTrue(discard.waitForExistence(timeout: 3))
        discard.tap()
        XCTAssertTrue(waitForDisappearance(of: sheet))
    }

    func testErroriInItaliano() {
        let app = launch(language: "it")
        let sheet = openForm(app)
        let save = app.buttons["item-save"]
        while !save.isHittable { app.swipeUp() }
        save.tap()
        while !app.textFields["item-name"].isHittable { app.swipeDown() }
        XCTAssertTrue(anyText(app, "Dai un nome al capo").waitForExistence(timeout: 3))
        XCTAssertTrue(anyText(app, "Scegli una categoria").exists)
        XCTAssertTrue(sheet.exists)
    }
}
