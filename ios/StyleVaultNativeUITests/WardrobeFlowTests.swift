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

    func testDaLinkRiempieIlModulo() {
        let app = launch(language: "it", extra: ["-SVFakeLink"])
        _ = openForm(app)
        app.buttons["mode-link"].tap()
        let link = app.textFields["item-link"]
        XCTAssertTrue(link.waitForExistence(timeout: 3))
        link.tap()
        link.typeText("https://zara.com/p")
        app.buttons["link-analyze"].tap()
        XCTAssertTrue(anyText(app, "Dati estratti: controlla e completa").waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["item-name"].value as? String, "Camicia in lino")
    }

    // MARK: Lista e dettaglio

    private func scroll(_ app: XCUIApplication, to element: XCUIElement, down: Bool = true) {
        var tries = 0
        while !element.isHittable, tries < 12 {
            if down { app.swipeUp() } else { app.swipeDown() }
            tries += 1
        }
    }

    private func addItem(_ app: XCUIApplication, name: String, category: String, wishlist: Bool = false) {
        let sheet = openForm(app)
        let field = app.textFields["item-name"]
        scroll(app, to: field)
        field.tap()
        field.typeText(name)
        let chip = app.buttons["category-\(category)"]
        scroll(app, to: chip)
        chip.tap()
        if wishlist {
            let destination = app.buttons["destination-wishlist"]
            scroll(app, to: destination)
            destination.tap()
        }
        let save = app.buttons["item-save"]
        scroll(app, to: save)
        save.tap()
        XCTAssertTrue(waitForDisappearance(of: sheet))
    }

    private func cards(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(identifier: "item-card")
    }

    private func waitForCount(_ query: XCUIElementQuery, _ count: Int) -> Bool {
        let p = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count == %d", count), object: query)
        return XCTWaiter().wait(for: [p], timeout: 5) == .completed
    }

    func testGiroCompleto() {
        let app = launch(language: "it")
        XCTAssertTrue(anyText(app, "Il tuo guardaroba è vuoto").waitForExistence(timeout: 5))
        app.buttons["wardrobe-empty-add"].tap()
        XCTAssertTrue(app.otherElements["add-sheet"].waitForExistence(timeout: 3))
        app.buttons["item-close"].tap()
        XCTAssertTrue(waitForDisappearance(of: app.otherElements["add-sheet"]))

        addItem(app, name: "Giacca blu", category: "outerwear")
        XCTAssertTrue(waitForCount(cards(app), 1))
        XCTAssertTrue(anyText(app, "1 capo").exists)

        cards(app).firstMatch.tap()
        XCTAssertTrue(anyText(app, "Giacca blu").waitForExistence(timeout: 3))
        XCTAssertTrue(anyText(app, "Capispalla").exists)

        let edit = app.buttons["detail-edit"]
        scroll(app, to: edit)
        edit.tap()
        let field = app.textFields["item-name"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        scroll(app, to: field)
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3) + "nera")
        let save = app.buttons["item-save"]
        scroll(app, to: save)
        save.tap()
        scroll(app, to: anyText(app, "Giacca nera"), down: false)
        XCTAssertTrue(anyText(app, "Giacca nera").waitForExistence(timeout: 3))

        let delete = app.buttons["detail-delete"]
        scroll(app, to: delete)
        delete.tap()
        let confirm = app.alerts.buttons["Elimina"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()
        XCTAssertTrue(anyText(app, "Il tuo guardaroba è vuoto").waitForExistence(timeout: 5))
    }

    func testFiltriERicerca() {
        let app = launch(language: "it")
        addItem(app, name: "Giacca", category: "outerwear")
        addItem(app, name: "Scarpe", category: "shoes")
        XCTAssertTrue(waitForCount(cards(app), 2))
        app.buttons["filter-shoes"].tap()
        XCTAssertTrue(waitForCount(cards(app), 1))
        app.buttons["filter-all"].tap()
        XCTAssertTrue(waitForCount(cards(app), 2))
        let search = app.textFields["wardrobe-search"]
        search.tap()
        search.typeText("giac")
        XCTAssertTrue(waitForCount(cards(app), 1))
        search.typeText("xyz")
        XCTAssertTrue(anyText(app, "Nessun risultato").waitForExistence(timeout: 3))
    }

    func testPreferiti() {
        let app = launch(language: "it")
        addItem(app, name: "Giacca", category: "outerwear")
        addItem(app, name: "Scarpe", category: "shoes")
        XCTAssertTrue(waitForCount(cards(app), 2))
        app.buttons.matching(identifier: "item-card-favorite").element(boundBy: 1).tap()
        app.buttons["wardrobe-favorites"].tap()
        XCTAssertTrue(waitForCount(cards(app), 1))
        XCTAssertTrue(anyText(app, "Scarpe").exists)
    }

    // MARK: Wishlist e categorie

    private func fillAndSave(_ app: XCUIApplication, name: String, category: String) {
        let sheet = app.otherElements["add-sheet"]
        let field = app.textFields["item-name"]
        scroll(app, to: field)
        field.tap()
        field.typeText(name)
        let chip = app.buttons["category-\(category)"]
        scroll(app, to: chip)
        chip.tap()
        let save = app.buttons["item-save"]
        scroll(app, to: save)
        save.tap()
        XCTAssertTrue(waitForDisappearance(of: sheet))
    }

    func testDesiderioComprato() {
        let app = launch(language: "it")
        XCTAssertTrue(app.buttons["wardrobe-section-wishlist"].waitForExistence(timeout: 5))
        app.buttons["wardrobe-section-wishlist"].tap()
        XCTAssertTrue(anyText(app, "La tua wishlist è vuota").waitForExistence(timeout: 3))
        app.buttons["wishlist-empty-add"].tap()
        XCTAssertTrue(app.otherElements["add-sheet"].waitForExistence(timeout: 3))
        let destination = app.buttons["destination-wishlist"]
        scroll(app, to: destination)
        XCTAssertTrue(destination.isSelected)
        fillAndSave(app, name: "Borsa", category: "accessories")

        let bought = app.buttons["wish-bought"]
        XCTAssertTrue(bought.waitForExistence(timeout: 5))
        app.buttons["wardrobe-section-wardrobe"].tap()
        XCTAssertTrue(anyText(app, "Il tuo guardaroba è vuoto").waitForExistence(timeout: 3))
        app.buttons["wardrobe-section-wishlist"].tap()
        XCTAssertTrue(bought.waitForExistence(timeout: 3))
        bought.tap()
        XCTAssertTrue(anyText(app, "La tua wishlist è vuota").waitForExistence(timeout: 3))
        app.buttons["wardrobe-section-wardrobe"].tap()
        XCTAssertTrue(waitForCount(cards(app), 1))
    }

    func testCancellaUnDesiderio() {
        let app = launch(language: "it")
        addItem(app, name: "Borsa", category: "accessories", wishlist: true)
        app.buttons["wardrobe-section-wishlist"].tap()
        let delete = app.buttons["wish-delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 3))
        delete.tap()
        XCTAssertTrue(anyText(app, "La tua wishlist è vuota").waitForExistence(timeout: 3))
    }

    private func createCategory(_ app: XCUIApplication, _ name: String) {
        let new = app.buttons["category-new"]
        scroll(app, to: new)
        new.tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText(name)
        // Per coordinate: a volte XCUITest prende l'avviso per un'interruzione e preme Annulla da solo.
        app.alerts.buttons["Salva"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func addItemInNewCategory(_ app: XCUIApplication, item: String, category: String) {
        let sheet = openForm(app)
        let field = app.textFields["item-name"]
        scroll(app, to: field)
        field.tap()
        field.typeText(item)
        createCategory(app, category)
        let save = app.buttons["item-save"]
        scroll(app, to: save)
        save.tap()
        XCTAssertTrue(waitForDisappearance(of: sheet))
    }

    func testNuovaCategoria() {
        let app = launch(language: "it")
        addItemInNewCategory(app, item: "Costume", category: "Mare")
        XCTAssertTrue(waitForCount(cards(app), 1))
        addItem(app, name: "Scarpe", category: "shoes")
        XCTAssertTrue(waitForCount(cards(app), 2))
        let chip = app.buttons["Mare"]
        XCTAssertTrue(chip.waitForExistence(timeout: 3))
        chip.tap()
        XCTAssertTrue(waitForCount(cards(app), 1))
        cards(app).firstMatch.tap()
        XCTAssertTrue(anyText(app, "Mare").waitForExistence(timeout: 3))
    }

    func testCategoriaUsataNonSiCancella() {
        let app = launch(language: "it")
        addItemInNewCategory(app, item: "Costume", category: "Mare")
        let chip = app.buttons["Mare"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        chip.press(forDuration: 1.2)
        let delete = app.buttons["Elimina categoria"]
        XCTAssertTrue(delete.waitForExistence(timeout: 3))
        delete.tap()
        XCTAssertTrue(anyText(app, "Prima sposta i capi in un'altra categoria").waitForExistence(timeout: 3))
        app.alerts.buttons["Chiudi"].tap()
        XCTAssertTrue(chip.waitForExistence(timeout: 3))

        cards(app).firstMatch.tap()
        let remove = app.buttons["detail-delete"]
        XCTAssertTrue(remove.waitForExistence(timeout: 3))
        scroll(app, to: remove)
        remove.tap()
        app.alerts.buttons["Elimina"].tap()
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        chip.press(forDuration: 1.2)
        XCTAssertTrue(delete.waitForExistence(timeout: 3))
        delete.tap()
        XCTAssertTrue(waitForDisappearance(of: chip))
    }
}
