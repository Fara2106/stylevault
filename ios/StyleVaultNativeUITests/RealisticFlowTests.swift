import XCTest

/// La versione realistica di "Vedilo addosso". Nel simulatore il modello non c'è e non gira: con `-SVFakeTryOn` un finto
/// generatore fa scorrere la barra. Il modello vero si prova sul Mac (`fashn-confronto`) e sul telefono.
final class RealisticFlowTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private let seeded = ["-SVFakeForecast", "-SVSeedWardrobe", "-SVSeedBodyPhoto", "-SVSeedGarmentPhotos", "-SVFakeBody"]

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func openAvatar(_ app: XCUIApplication) {
        tab(app, "Outfit").tap()
        let button = app.buttons["outfit-avatar"].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 30))
        for _ in 0..<6 where !button.isHittable { app.swipeUp() }
        button.tap()
        XCTAssertTrue(element(app, "avatar-prompt").waitForExistence(timeout: 60))
    }

    func testLaVersioneRealisticaHaBarraPercentualeEdEtichettaIA() {
        let app = launch(language: "it", extra: seeded + ["-SVFakeTryOn"])
        openAvatar(app)
        let open = element(app, "avatar-realistic")
        XCTAssertTrue(open.waitForExistence(timeout: 30))
        open.tap()

        // Prima di generare: quali capi entrano nell'immagine e quali no
        XCTAssertTrue(element(app, "realistic-pieces").waitForExistence(timeout: 30))
        XCTAssertTrue(element(app, "realistic-left-out").exists)
        XCTAssertFalse(element(app, "realistic-image").exists)
        element(app, "realistic-generate").tap()

        // Durante: la barra e la percentuale accanto
        XCTAssertTrue(element(app, "realistic-progress").waitForExistence(timeout: 15))
        let percent = element(app, "realistic-percent")
        XCTAssertTrue(percent.exists)
        XCTAssertTrue(percent.label.hasSuffix("%"), percent.label)
        XCTAssertTrue(element(app, "realistic-cancel").exists)

        // Dopo: l'immagine, sempre etichettata come generata con IA, e il modo di segnalarla
        XCTAssertTrue(element(app, "realistic-ai-label").waitForExistence(timeout: 60))
        XCTAssertTrue(element(app, "realistic-image").exists)
        XCTAssertTrue(element(app, "realistic-ai-label").label.contains("IA"))
        XCTAssertFalse(element(app, "realistic-progress").exists)
        let report = element(app, "realistic-report")
        for _ in 0..<4 where !(report.exists && report.isHittable) { app.swipeUp() }
        XCTAssertTrue(report.exists)

        // Riaprendo, l'immagine c'è già: non si rifanno minuti di lavoro
        element(app, "realistic-close").tap()
        XCTAssertTrue(element(app, "avatar-realistic").waitForExistence(timeout: 15))
        element(app, "avatar-realistic").tap()
        XCTAssertTrue(element(app, "realistic-image").waitForExistence(timeout: 15))
    }

    func testAnnullareFermaLaGenerazione() {
        let app = launch(language: "it", extra: seeded + ["-SVFakeTryOn", "-SVFakeTryOnSlow"])
        openAvatar(app)
        element(app, "avatar-realistic").tap()
        XCTAssertTrue(element(app, "realistic-generate").waitForExistence(timeout: 30))
        element(app, "realistic-generate").tap()
        XCTAssertTrue(element(app, "realistic-cancel").waitForExistence(timeout: 15))
        element(app, "realistic-cancel").tap()
        XCTAssertTrue(waitForDisappearance(of: element(app, "realistic-progress")))
        XCTAssertTrue(element(app, "realistic-generate").exists)
        XCTAssertFalse(element(app, "realistic-image").exists)
    }

    func testChiudereAMetaChiedeConferma() {
        let app = launch(language: "it", extra: seeded + ["-SVFakeTryOn", "-SVFakeTryOnSlow"])
        openAvatar(app)
        element(app, "avatar-realistic").tap()
        XCTAssertTrue(element(app, "realistic-generate").waitForExistence(timeout: 30))
        element(app, "realistic-generate").tap()
        XCTAssertTrue(element(app, "realistic-progress").waitForExistence(timeout: 15))
        element(app, "realistic-close").tap()
        let keep = app.alerts.buttons["Continua"].firstMatch
        XCTAssertTrue(app.alerts.buttons["Ferma e chiudi"].waitForExistence(timeout: 15))
        XCTAssertTrue(keep.waitForExistence(timeout: 15))
        keep.tap()
        // Si è scelto di continuare: la generazione arriva in fondo
        XCTAssertTrue(element(app, "realistic-ai-label").waitForExistence(timeout: 120))
    }

    func testDoveIlModelloNonCELaFunzioneNonSiVede() {
        // Senza il finto generatore vale quello vero: nel simulatore il modello non è nel pacchetto
        let app = launch(language: "it", extra: seeded)
        openAvatar(app)
        XCTAssertFalse(element(app, "avatar-realistic").exists)
    }

    func testSenzaFotoDeiCapiLaFunzioneNonSiVede() {
        let app = launch(language: "it", extra: ["-SVFakeForecast", "-SVSeedWardrobe", "-SVSeedBodyPhoto", "-SVFakeBody", "-SVFakeTryOn"])
        openAvatar(app)
        XCTAssertFalse(element(app, "avatar-realistic").exists)
    }
}
