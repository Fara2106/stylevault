import XCTest

/// Il giro Outfit → Calendario → Statistiche, senza rete e senza permessi veri.
final class OutfitFlowTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private let seeded = ["-SVFakeForecast", "-SVFakePosition", "-SVSeedWardrobe"]

    private func openOutfit(_ app: XCUIApplication) {
        let outfit = tab(app, "Outfit")
        XCTAssertTrue(outfit.waitForExistence(timeout: 20))
        outfit.tap()
    }

    func testOutfitNascoDaSoliConMeteoEConsigli() {
        let app = launch(language: "it", extra: seeded)
        openOutfit(app)
        XCTAssertTrue(app.descendants(matching: .any)["weather-card"].firstMatch.waitForExistence(timeout: 15))
        XCTAssertTrue(app.descendants(matching: .any)["outfit-card"].firstMatch.waitForExistence(timeout: 15))
        XCTAssertTrue(app.descendants(matching: .any)["outfit-score"].firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any)["outfit-advice"].firstMatch.exists)
        // Le chiavi non devono mai arrivare sullo schermo.
        XCTAssertTrue(app.staticTexts["Mattina"].exists)
        XCTAssertTrue(app.staticTexts["Pomeriggio"].exists)
        XCTAssertTrue(app.staticTexts["Sera"].exists)
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'weather.'")).firstMatch.exists)
    }

    func testSalvaIndossaEVedeTuttoNelCalendarioENelleStatistiche() {
        let app = launch(language: "it", extra: seeded)
        openOutfit(app)
        let save = app.buttons["outfit-save"].firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 15))
        save.tap()
        XCTAssertTrue(app.buttons["Salvato"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["outfit-wear"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["outfit-worn-message"].waitForExistence(timeout: 5))
        // La conferma sta sul tasto, che non si può toccare due volte.
        let worn = app.buttons["outfit-worn"].firstMatch
        XCTAssertTrue(worn.waitForExistence(timeout: 5))
        XCTAssertFalse(worn.isEnabled)

        tab(app, "Calendario").tap()
        let status = app.staticTexts["calendar-status"].firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertEqual(status.label, "Indossato")

        tab(app, "Profilo").tap()
        let stats = app.buttons["profile-stats"]
        XCTAssertTrue(stats.waitForExistence(timeout: 10))
        stats.tap()
        XCTAssertTrue(app.staticTexts["Per categoria"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["stats-item"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["stats-no-data"].exists)
    }

    func testTornandoSullaSchedaGliOutfitNonCambiano() {
        let app = launch(language: "it", extra: seeded)
        openOutfit(app)
        let score = app.descendants(matching: .any)["outfit-score"].firstMatch
        XCTAssertTrue(score.waitForExistence(timeout: 15))
        let lock = app.buttons["outfit-lock"].firstMatch
        XCTAssertTrue(lock.waitForExistence(timeout: 5))
        lock.tap()
        XCTAssertTrue(app.staticTexts["I capi bloccati restano, il resto cambia"].waitForExistence(timeout: 5))
        tab(app, "Calendario").tap()
        XCTAssertTrue(app.buttons["calendar-assign"].waitForExistence(timeout: 10))
        tab(app, "Outfit").tap()
        XCTAssertTrue(app.staticTexts["I capi bloccati restano, il resto cambia"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["outfit-lock"].firstMatch.isSelected, "il capo bloccato resta bloccato")
    }

    func testLaRicercaDellaCittaNonSpostaLaPagina() {
        let app = launch(language: "it", extra: seeded)
        openOutfit(app)
        let title = app.staticTexts["outfit-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 15))
        let top = title.frame.minY
        app.buttons["outfit-city"].tap()
        let close = app.buttons["city-close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        XCTAssertTrue(waitForDisappearance(of: close))
        waitForStillness(of: title)
        XCTAssertEqual(title.frame.minY, top, accuracy: 1)
    }

    func testOutfitSalvatiSiVedonoESiCancellano() {
        let app = launch(language: "it", extra: seeded)
        openOutfit(app)
        let save = app.buttons["outfit-save"].firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 15))
        save.tap()
        let link = app.buttons["outfit-saved-link"]
        for _ in 0..<8 where !link.exists { app.swipeUp() }
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        link.tap()
        let row = app.descendants(matching: .any)["saved-outfit"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft()
        app.buttons["Elimina"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Nessun outfit salvato"].waitForExistence(timeout: 5))
    }

    func testPianificaUnGiornoFuturoESegnaIndossato() {
        let app = launch(language: "it", extra: seeded)
        openOutfit(app)
        let save = app.buttons["outfit-save"].firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 15))
        save.tap()

        tab(app, "Calendario").tap()
        // Il mese dopo non contiene oggi: il primo giorno è sempre futuro.
        let next = app.buttons["calendar-next"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        next.tap()
        let future = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'calendar-day-'")).firstMatch
        XCTAssertTrue(future.waitForExistence(timeout: 5))
        future.tap()
        XCTAssertTrue(app.staticTexts["calendar-empty"].waitForExistence(timeout: 5))
        app.buttons["calendar-assign"].tap()
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Punteggio'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let status = app.staticTexts["calendar-status"].firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertEqual(status.label, "Pianificato")
        app.buttons["calendar-mark-worn"].tap()
        XCTAssertTrue(app.staticTexts["Indossato"].waitForExistence(timeout: 5))
        app.buttons["calendar-remove"].tap()
        XCTAssertTrue(app.staticTexts["calendar-empty"].waitForExistence(timeout: 5))
    }

    func testSenzaMeteoSiImpostaAManoESiGeneraLoStesso() {
        let app = launch(language: "it", extra: ["-SVFakeForecastFail", "-SVFakePosition", "-SVSeedWardrobe"])
        openOutfit(app)
        XCTAssertTrue(app.staticTexts["outfit-manual"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.descendants(matching: .any)["outfit-card"].firstMatch.waitForExistence(timeout: 15))
    }

    func testGuardarobaVuotoPortaAdAggiungereUnCapo() {
        let app = launch(language: "it", extra: ["-SVFakeForecast", "-SVFakePosition"])
        openOutfit(app)
        let add = app.buttons["outfit-empty-add"]
        XCTAssertTrue(add.waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["outfit-generate"].exists)
        XCTAssertTrue(add.isHittable, "il tasto per aggiungere non deve finire sotto la barra")
        add.tap()
        XCTAssertTrue(app.otherElements["add-sheet"].waitForExistence(timeout: 5))
    }

    func testLaPosizioneSiChiedeSoloDopoAverSpiegatoPerche() {
        let app = launch(language: "it", extra: seeded)
        openOutfit(app)
        let position = app.buttons["outfit-position"]
        XCTAssertTrue(position.waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["Roma"].exists, "la posizione non si usa senza un tocco")
        position.tap()
        let cancel = app.alerts.buttons["Annulla"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.tap()
        XCTAssertFalse(app.staticTexts["Roma"].exists)
        position.tap()
        let proceed = app.alerts.buttons["Continua"]
        XCTAssertTrue(proceed.waitForExistence(timeout: 5))
        proceed.tap()
        XCTAssertTrue(app.staticTexts["Roma"].firstMatch.waitForExistence(timeout: 10))
    }

    func testPosizioneNegataRestaSullaCitta() {
        let app = launch(language: "it", extra: ["-SVFakeForecast", "-SVFakePositionDenied", "-SVSeedWardrobe"])
        openOutfit(app)
        let position = app.buttons["outfit-position"]
        XCTAssertTrue(position.waitForExistence(timeout: 15))
        position.tap()
        let proceed = app.alerts.buttons["Continua"]
        XCTAssertTrue(proceed.waitForExistence(timeout: 5))
        proceed.tap()
        XCTAssertTrue(app.descendants(matching: .any)["outfit-position-note"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["outfit-card"].firstMatch.waitForExistence(timeout: 15))
        // Si può tornare indietro: il tasto si spegne e l'avviso sparisce.
        position.tap()
        XCTAssertTrue(waitForDisappearance(of: app.descendants(matching: .any)["outfit-position-note"].firstMatch))
    }
}
