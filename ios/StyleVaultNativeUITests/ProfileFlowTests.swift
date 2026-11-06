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
        XCTAssertTrue(waitForDisappearance(of: app.buttons["login-forgot"]))
        waitForStillness(of: app.buttons["login-toggle"])
        app.buttons["login-toggle"].tap()
        XCTAssertTrue(app.buttons["login-forgot"].waitForExistence(timeout: 5))
        waitForStillness(of: app.buttons["login-skip"])

        app.buttons["login-skip"].tap()
        XCTAssertTrue(tab(app, "Profilo").waitForExistence(timeout: 5))
        tab(app, "Profilo").tap()
        // L'uscita si vede appena si apre il Profilo, senza scorrere, e dice dove porta.
        let exit = app.buttons["account-login"]
        XCTAssertTrue(exit.waitForExistence(timeout: 5))
        XCTAssertTrue(exit.isHittable)
        XCTAssertEqual(exit.label, "Esci e vai all'accesso")
        exit.tap()
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

    private func isDark(at offset: CGVector, in app: XCUIApplication) -> Bool {
        guard let image = XCUIScreen.main.screenshot().image.cgImage else { return false }
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        let x = CGFloat(image.width) * offset.dx, y = CGFloat(image.height) * offset.dy
        context?.draw(image, in: CGRect(x: -x, y: y - CGFloat(image.height), width: CGFloat(image.width),
                                        height: CGFloat(image.height)))
        return Int(pixel[0]) + Int(pixel[1]) + Int(pixel[2]) < 300
    }

    /// Il simulatore resta chiaro: lo scuro può venire solo dal tema scelto nel Profilo.
    func testIlLoginSegueIlTemaScelto() {
        let app = launch(language: "it", extra: ["-SVShowLogin"])
        let skip = app.buttons["login-skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 10))
        skip.tap()
        tab(app, "Profilo").tap()
        let picker = app.segmentedControls["theme-picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.buttons.element(boundBy: 1).tap()
        let login = app.buttons["account-login"]
        XCTAssertTrue(login.waitForExistence(timeout: 5))
        login.tap()
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        XCTAssertTrue(isDark(at: CGVector(dx: 0.5, dy: 0.95), in: app))
    }

    func testTuttoIlRiquadroDelLoginApreLaTastiera() {
        let app = launch(language: "it", extra: ["-SVShowLogin"])
        let email = app.textFields["login-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        // Subito dopo il lancio, sotto carico, la tastiera dell'iPad può metterci più del campo a prendere il fuoco.
        waitForStillness(of: email)
        tapTopEdge(email)
        XCTAssertTrue(waitForFocus(of: email))
        let password = app.secureTextFields["login-password"]
        tapTopEdge(password)
        XCTAssertTrue(waitForFocus(of: password))
    }

    /// Nessuna credenziale parte: la password resta vuota e l'errore nasce sul telefono.
    func testInvioPassaAllaPasswordEPoiAccede() {
        let app = launch(language: "it", extra: ["-SVShowLogin"])
        let email = app.textFields["login-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        email.tap()
        email.typeText("nessuno\n")
        let password = app.secureTextFields["login-password"]
        let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: password)
        XCTAssertEqual(XCTWaiter().wait(for: [focused], timeout: 5), .completed)
        password.typeText("\n")
        XCTAssertTrue(anyText(app, "Compila tutti i campi.").waitForExistence(timeout: 5))
    }
}
