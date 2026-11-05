import XCTest
import StyleVaultCore
@testable import StyleVaultNative

@MainActor final class CitySearchModelTests: XCTestCase {
    private let milano = City(id: 1, name: "Milano", latitude: 45.46, longitude: 9.19, country: "Italia", region: nil)

    func testUnaLetteraNonCerca() async {
        var called = false
        let m = CitySearchModel(search: { _ in called = true; return [] })
        await m.run(query: " m ")
        XCTAssertEqual(m.phase, .idle)
        XCTAssertFalse(called)
    }
    func testMostraIRisultati() async {
        let m = CitySearchModel(search: { [milano] _ in [milano] })
        await m.run(query: "mila")
        XCTAssertEqual(m.phase, .results([milano]))
    }
    func testReteAssenteComeNessunRisultato() async {
        let m = CitySearchModel(search: { _ in throw URLError(.notConnectedToInternet) })
        await m.run(query: "mila")
        XCTAssertEqual(m.phase, .empty)
    }
    func testLAnnullamentoLasciaLaFaseCom() async {
        let m = CitySearchModel(search: { [milano] _ in [milano] })
        await m.run(query: "mila")
        let cancelling = CitySearchModel(search: { _ in throw CancellationError() })
        await cancelling.run(query: "mila")
        XCTAssertEqual(cancelling.phase, .searching)
        let urlCancelled = CitySearchModel(search: { _ in throw URLError(.cancelled) })
        await urlCancelled.run(query: "mila")
        XCTAssertEqual(urlCancelled.phase, .searching)
        XCTAssertEqual(m.phase, .results([milano]))
    }
    func testQueryBrevePortaAIdle() async {
        let m = CitySearchModel(search: { [milano] _ in [milano] })
        await m.run(query: "mila")
        await m.run(query: "m")
        XCTAssertEqual(m.phase, .idle)
    }
    func testLaCittaSceltaAggiornaIlProfilo() {
        let p = Profile(); let before = p.updatedAt
        p.apply(city: milano)
        XCTAssertEqual(p.cityLatitude, 45.46)
        XCTAssertGreaterThanOrEqual(p.updatedAt, before)
    }
    func testIlTemaAggiornaIlProfilo() {
        let p = Profile(); let before = p.updatedAt
        p.setTheme("dark")
        XCTAssertEqual(p.theme, "dark")
        XCTAssertGreaterThanOrEqual(p.updatedAt, before)
    }
}
