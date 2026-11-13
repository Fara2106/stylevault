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

    /// Sugli schermi piccoli un controllo può stare più in basso: si scorre finché si può toccare.
    /// Con la tastiera aperta si trascina dalla parte alta, dove c'è ancora il contenuto.
    @discardableResult func reach(_ app: XCUIApplication, _ element: XCUIElement, tries: Int = 8) -> XCUIElement {
        // Sugli schermi grandi c'è già: prima di scorrere si lascia alla schermata il tempo di comparire
        _ = element.waitForExistence(timeout: 3)
        for _ in 0..<tries where !(element.exists && element.isHittable) {
            if app.keyboards.firstMatch.exists {
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.30))
                    .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)))
            } else {
                app.swipeUp(velocity: .slow)
            }
        }
        return element
    }

    func waitForDisappearance(of element: XCUIElement) -> Bool {
        let p = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        let gone = XCTWaiter().wait(for: [p], timeout: 4) == .completed
        if !gone {
            // Senza la schermata un fallimento raro non si può spiegare dopo.
            let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            shot.lifetime = .keepAlways
            add(shot)
        }
        return gone
    }

    /// Con il simulatore sotto carico un tocco dato mentre i controlli si spostano finisce su quello vicino.
    func waitForStillness(of element: XCUIElement) {
        var last = element.frame
        var still = 0
        for _ in 0..<40 where still < 3 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
            let now = element.frame
            still = now == last ? still + 1 : 0
            last = now
        }
    }

    func waitForFocus(of element: XCUIElement) -> Bool {
        let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: element)
        return XCTWaiter().wait(for: [focused], timeout: 15) == .completed
    }

    /// Tocca il bordo alto del riquadro: chi usa l'app non centra mai il testo.
    func tapTopEdge(_ element: XCUIElement) {
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
    }

    /// Un elemento con quel testo, qualunque sia il suo tipo.
    func anyText(_ app: XCUIApplication, _ text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", text)).firstMatch
    }
}
