import XCTest

final class ProfileFlowTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testCinqueTabEFoglioAggiungi() {
        let app = launch(language: "it")
        for label in ["Guardaroba", "Outfit", "Calendario", "Profilo"] {
            XCTAssertTrue(tab(app, label).waitForExistence(timeout: 5), label)
        }
        tab(app, "Profilo").tap()
        XCTAssertTrue(tab(app, "Profilo").isSelected)
        tab(app, "Aggiungi").tap()
        let sheet = app.otherElements["add-sheet"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 3))
        closeSheet(app, sheet)
        XCTAssertTrue(waitForDisappearance(of: sheet))
        XCTAssertTrue(tab(app, "Profilo").isSelected)
        tab(app, "Aggiungi").tap()
        XCTAssertTrue(sheet.waitForExistence(timeout: 3))
    }
    func testInIngleseLeTabSonoTradotte() {
        XCTAssertTrue(tab(launch(language: "en"), "Wardrobe").waitForExistence(timeout: 5))
    }
    func testIlTemaSiCambiaDalProfilo() {
        let app = launch(language: "it")
        tab(app, "Profilo").tap()
        let picker = app.segmentedControls["theme-picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.buttons["Scuro"].tap()
        XCTAssertTrue(picker.buttons["Scuro"].isSelected)
    }
    private func launch(language: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-SVMemoryStore", "-AppleLanguages", "(\(language))"]
        app.launch()
        return app
    }
    /// Su iPhone le tab stanno in `tabBars`; su iPad (iOS 18+) sono nella barra in alto e non sempre lì.
    private func tab(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        let inBar = app.tabBars.buttons[label]
        if inBar.exists { return inBar }
        return app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }
    /// iPhone: si trascina il foglio verso il basso. iPad: il foglio è al centro e si tocca fuori.
    private func closeSheet(_ app: XCUIApplication, _ sheet: XCUIElement) {
        if UIDevice.current.userInterfaceIdiom == .pad {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.03)).tap()
        } else {
            sheet.swipeDown(velocity: .fast)
        }
    }
    private func waitForDisappearance(of element: XCUIElement) -> Bool {
        let p = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter().wait(for: [p], timeout: 4) == .completed
    }
}
