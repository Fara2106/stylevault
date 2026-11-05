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
    /// Il blocco resta acceso tra un lancio e l'altro: per questo `-SVFakeLock` usa una suite dedicata,
    /// azzerata solo dal primo lancio (`-SVFakeLockReset`). Gli altri test non vedono mai il blocco.
    func testBloccoConAutenticatoreFinto() {
        let first = XCUIApplication()
        first.launchArguments = ["-SVMemoryStore", "-SVFakeLock", "-SVFakeLockReset", "-AppleLanguages", "(it)"]
        first.launch()
        tab(first, "Profilo").tap()
        let toggle = first.switches["lock-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        // L'autenticazione è asincrona: l'interruttore passa a acceso solo dopo.
        let on = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '1'"), object: toggle)
        XCTAssertEqual(XCTWaiter().wait(for: [on], timeout: 5), .completed)
        first.terminate()

        let second = XCUIApplication()
        second.launchArguments = ["-SVMemoryStore", "-SVFakeLock", "-AppleLanguages", "(it)"]
        second.launch()
        XCTAssertTrue(second.descendants(matching: .any)["lock-screen"].waitForExistence(timeout: 5))
        second.buttons["Sblocca"].tap()
        XCTAssertTrue(tab(second, "Profilo").waitForExistence(timeout: 5))
        XCTAssertFalse(second.descendants(matching: .any)["lock-screen"].exists)
    }
    /// Il foglio Aggiungi sta sopra la finestra principale: il blocco deve coprirlo senza chiuderlo (le bozze restano).
    func testIlBloccoCopreIlFoglioAggiungi() {
        let app = XCUIApplication()
        app.launchArguments = ["-SVMemoryStore", "-SVFakeLock", "-SVFakeLockReset", "-AppleLanguages", "(it)"]
        app.launch()
        tab(app, "Profilo").tap()
        let toggle = app.switches["lock-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let on = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '1'"), object: toggle)
        XCTAssertEqual(XCTWaiter().wait(for: [on], timeout: 5), .completed)
        tab(app, "Aggiungi").tap()
        let sheet = app.otherElements["add-sheet"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 3))

        XCUIDevice.shared.press(.home)
        app.activate()
        let lock = app.descendants(matching: .any)["lock-screen"]
        XCTAssertTrue(lock.waitForExistence(timeout: 5))
        XCTAssertTrue(lock.isHittable)
        app.buttons["Sblocca"].tap()
        XCTAssertTrue(waitForDisappearance(of: lock))
        XCTAssertTrue(sheet.exists, "Il foglio non va chiuso dal blocco")
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
