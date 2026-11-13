import XCTest
@testable import StyleVaultCore

/// Gli stessi casi di `feedback.test.js` del sito.
final class FeedbackRulesTests: XCTestCase {
    func testTrovaEmailNumeriLunghiEIban() {
        XCTAssertEqual(FeedbackRules.sensitive(in: "scrivimi a mario@gmail.com"), [.email])
        XCTAssertEqual(FeedbackRules.sensitive(in: "chiamami al 333 123 4567"), [.number])
        XCTAssertEqual(FeedbackRules.sensitive(in: "carta 4111-1111-1111-1111"), [.number])
        XCTAssertTrue(FeedbackRules.sensitive(in: "IBAN IT60X0542811101000000123456").contains(.iban))
    }

    func testLasciaPassareTaglieAnniPrezziETestoNormale() {
        XCTAssertEqual(FeedbackRules.sensitive(in: "La taglia 42 nel 2026 costava 49,90 €: il pulsante non va"), [])
        XCTAssertEqual(FeedbackRules.sensitive(in: ""), [])
    }

    func testServeUnTestoTraDieciEDuemilaCaratteriSenzaDatiSensibili() {
        XCTAssertFalse(FeedbackRules.canSend("  corto  "))
        XCTAssertTrue(FeedbackRules.canSend("Il calendario non si apre"))
        XCTAssertFalse(FeedbackRules.canSend(String(repeating: "x", count: FeedbackRules.maximum + 1)))
        XCTAssertFalse(FeedbackRules.canSend("Non va, scrivimi a a@b.it"))
    }

    func testLeInfoTecnicheNonHannoCampiVuoti() {
        let info = FeedbackRules.deviceInfo(appVersion: "1.0 (5)", osVersion: "iOS 27.2", model: "", language: "it")
        XCTAssertEqual(info, ["source": "app iOS", "appVersion": "1.0 (5)", "osVersion": "iOS 27.2", "language": "it"])
    }
}
