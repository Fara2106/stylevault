import XCTest

/// Le schermate arrivate per la bozza completa: Armocromia, Onboarding, segnalazioni, dati e prova.
/// Vision non gira nel simulatore: l'analisi del viso è finta, quella vera si prova sul Mac.
final class CompleteFlowTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func reveal(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        let target = element(app, id)
        for _ in 0..<10 where !(target.exists && target.isHittable) { app.swipeUp() }
        XCTAssertTrue(target.waitForExistence(timeout: 30), id)
        return target
    }

    func testArmocromiaDallaFotoAllaStagione() {
        let app = launch(language: "it", extra: ["-SVFakeBody", "-SVSeedBodyPhoto", "-SVSeedWardrobe"])
        tab(app, "Profilo").tap()
        reveal(app, "profile-armocromia").tap()
        element(app, "armocromia-use-photo").tap()
        XCTAssertTrue(element(app, "armocromia-compute").waitForExistence(timeout: 30))
        element(app, "armocromia-compute").tap()
        XCTAssertTrue(element(app, "armocromia-season-name").waitForExistence(timeout: 30))
        XCTAssertFalse(element(app, "armocromia-season-name").label.isEmpty)
        let save = reveal(app, "armocromia-save")
        save.tap()
        XCTAssertTrue(app.buttons["armocromia-save"].waitForExistence(timeout: 30))
        // Tornando indietro e riaprendo si ritrova il risultato salvato.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        reveal(app, "profile-armocromia").tap()
        XCTAssertTrue(element(app, "armocromia-season-name").waitForExistence(timeout: 30))
    }

    func testLaStagioneSiSceglieAncheAMano() {
        let app = launch(language: "it")
        tab(app, "Profilo").tap()
        reveal(app, "profile-armocromia").tap()
        XCTAssertFalse(element(app, "armocromia-use-photo").exists)
        element(app, "armocromia-by-hand").tap()
        app.buttons["Inverno Profondo"].tap()
        XCTAssertTrue(element(app, "armocromia-season-name").waitForExistence(timeout: 30))
        XCTAssertEqual(element(app, "armocromia-season-name").label, "Inverno Profondo")
    }

    func testIPrimiPassiSiPossonoSaltare() {
        let app = launch(language: "it", extra: ["-SVShowOnboarding"])
        XCTAssertTrue(element(app, "onboarding-step").waitForExistence(timeout: 30))
        XCTAssertTrue(element(app, "onboarding-notice").exists)
        element(app, "onboarding-next").tap()
        XCTAssertTrue(element(app, "onboarding-city").waitForExistence(timeout: 30))
        element(app, "onboarding-next").tap()
        XCTAssertTrue(tab(app, "Profilo").waitForExistence(timeout: 30))
    }

    func testLaSegnalazioneBloccaIDatiSensibiliEPoiParte() {
        let app = launch(language: "it", extra: ["-SVFakeFeedback"])
        tab(app, "Profilo").tap()
        reveal(app, "profile-feedback").tap()
        XCTAssertTrue(element(app, "feedback-warning").waitForExistence(timeout: 30))
        let field = element(app, "feedback-message")
        field.tap()
        field.typeText("Scrivimi a prova@esempio.it per favore")
        XCTAssertTrue(element(app, "feedback-sensitive").waitForExistence(timeout: 30))
        XCTAssertFalse(reveal(app, "feedback-send").isEnabled)
        app.swipeDown()
        app.swipeDown()
        field.tap()
        field.typeText(XCUIKeyboardKey.delete.rawValue.padding(toLength: 40, withPad: XCUIKeyboardKey.delete.rawValue, startingAt: 0))
        field.typeText("Il calendario non si apre")
        let send = reveal(app, "feedback-send")
        send.tap()
        XCTAssertTrue(element(app, "feedback-sent").waitForExistence(timeout: 30))
    }

    func testIDatiSiEsportanoInUnFile() {
        let app = launch(language: "it", extra: ["-SVSeedWardrobe"])
        tab(app, "Profilo").tap()
        reveal(app, "data-export").tap()
        XCTAssertTrue(reveal(app, "data-share").waitForExistence(timeout: 60))
    }

    func testIlProfiloHaPrivacySupportoEVersione() {
        let app = launch(language: "it")
        tab(app, "Profilo").tap()
        for id in ["profile-privacy", "profile-support", "profile-version"] {
            XCTAssertTrue(reveal(app, id).exists, id)
        }
    }

    func testPrivacyESupportoSiLeggonoNellApp() {
        let app = launch(language: "it")
        tab(app, "Profilo").tap()
        reveal(app, "profile-privacy").tap()
        XCTAssertTrue(element(app, "legal-title").waitForExistence(timeout: 30))
        XCTAssertEqual(element(app, "legal-title").label, "Informativa sulla privacy")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        reveal(app, "profile-support").tap()
        XCTAssertTrue(reveal(app, "legal-email").exists)
    }

    func testDallAccessoSiLeggeLaPrivacy() {
        let app = launch(language: "it", extra: ["-SVShowLogin"])
        let privacy = element(app, "login-privacy")
        XCTAssertTrue(privacy.waitForExistence(timeout: 30))
        privacy.tap()
        XCTAssertTrue(element(app, "legal-title").waitForExistence(timeout: 30))
        app.buttons["Chiudi"].firstMatch.tap()
        XCTAssertTrue(privacy.waitForExistence(timeout: 30))
    }

    func testDalDettaglioSiVedeIlCapoAddosso() {
        let app = launch(language: "it", extra: ["-SVFakeBody", "-SVSeedBodyPhoto", "-SVSeedWardrobe"])
        let card = app.descendants(matching: .any).matching(identifier: "item-card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30))
        card.tap()
        reveal(app, "detail-avatar").tap()
        XCTAssertTrue(element(app, "avatar-image-front").waitForExistence(timeout: 60))
    }

    func testIlPromptAIChiedePrimaIlConsenso() {
        let app = launch(language: "it", extra: ["-SVFakeBody", "-SVSeedBodyPhoto", "-SVSeedWardrobe", "-SVResetAIConsent"])
        let card = app.descendants(matching: .any).matching(identifier: "item-card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30))
        card.tap()
        reveal(app, "detail-avatar").tap()
        XCTAssertTrue(element(app, "avatar-prompt").waitForExistence(timeout: 60))
        element(app, "avatar-prompt").tap()
        XCTAssertTrue(element(app, "prompt-consent").waitForExistence(timeout: 30))
        XCTAssertTrue(element(app, "prompt-consent").label.contains("OpenAI"))
        XCTAssertFalse(element(app, "prompt-copy").exists)
        element(app, "prompt-accept").tap()
        XCTAssertTrue(element(app, "prompt-copy").waitForExistence(timeout: 30))
    }
}
