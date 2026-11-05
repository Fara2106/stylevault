import XCTest

extension XCTestCase {
    func launch(language: String, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-SVMemoryStore", "-AppleLanguages", "(\(language))"] + extra
        app.launch()
        return app
    }

    /// Su iPhone le tab stanno in `tabBars`; su iPad (iOS 18+) sono nella barra in alto e non sempre lì.
    func tab(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        let inBar = app.tabBars.buttons[label]
        if inBar.exists { return inBar }
        return app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    /// iPhone: si trascina il foglio verso il basso. iPad: il foglio è al centro e si tocca fuori.
    func closeSheet(_ app: XCUIApplication, _ sheet: XCUIElement) {
        if UIDevice.current.userInterfaceIdiom == .pad {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.03)).tap()
        } else {
            sheet.swipeDown(velocity: .fast)
        }
    }

    func waitForDisappearance(of element: XCUIElement) -> Bool {
        let p = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter().wait(for: [p], timeout: 4) == .completed
    }

    /// Un elemento con quel testo, qualunque sia il suo tipo.
    func anyText(_ app: XCUIApplication, _ text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", text)).firstMatch
    }
}
