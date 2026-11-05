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
    /// Tutti i metodi sono sullo schermo e si può entrare senza account, poi tornare ad accedere dal Profilo.
    /// Nessun tocco invia dati: il servizio vero qui non si contatta con credenziali.
    func testAccessoConTuttiIMetodiESenzaAccount() {
        let app = launch(language: "it", extra: ["-SVShowLogin"])
        let email = app.textFields["login-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["login-apple"].exists)
        XCTAssertTrue(app.secureTextFields["login-password"].exists)

        app.buttons["login-submit"].tap()
        XCTAssertTrue(anyText(app, "Compila tutti i campi.").waitForExistence(timeout: 3))
        app.buttons["login-forgot"].tap()
        XCTAssertTrue(anyText(app, "Scrivi la tua email qui sopra, poi tocca «Password dimenticata?».")
            .waitForExistence(timeout: 3))

        app.buttons["login-toggle"].tap()
        XCTAssertFalse(app.buttons["login-forgot"].exists)
        app.buttons["login-toggle"].tap()

        app.buttons["login-skip"].tap()
        XCTAssertTrue(tab(app, "Profilo").waitForExistence(timeout: 5))
        tab(app, "Profilo").tap()
        let signIn = app.buttons["account-login"]
        var tries = 0
        while !signIn.exists, tries < 6 {
            app.swipeUp()
            tries += 1
        }
        signIn.tap()
        XCTAssertTrue(email.waitForExistence(timeout: 5))
    }

    /// Un link di reset senza codice fallisce sul telefono, senza chiamare il servizio.
    func testLinkDiResetNonValidoSpiegaCosaFare() {
        let app = launch(language: "it", extra: ["-SVShowLogin"])
        XCTAssertTrue(app.textFields["login-email"].waitForExistence(timeout: 10))
        app.open(URL(string: "svnativa://reset-password")!)
        XCTAssertTrue(anyText(app, "Il link non è valido o è scaduto: chiedine un altro.")
            .waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["login-email"].exists)
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
}
