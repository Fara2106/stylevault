import XCTest
import SwiftData
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
    func testUnaRicercaAnnullataNonCambiaLaFase() async {
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
    func testUnaRicercaVecchiaAnnullataNonSovrascriveLaNuova() async {
        let roma = City(id: 2, name: "Roma", latitude: 41.9, longitude: 12.5, country: "Italia", region: nil)
        let m = CitySearchModel(search: { [milano, roma] query in
            if query == "mila" {
                // Lenta: finisce dopo la nuova, con un errore di rete (timeout).
                try? await Task.sleep(for: .milliseconds(300))
                throw URLError(.timedOut)
            }
            return [roma]
        })
        let old = Task { await m.run(query: "mila") }
        try? await Task.sleep(for: .milliseconds(50))
        await m.run(query: "roma")
        XCTAssertEqual(m.phase, .results([roma]))
        old.cancel()
        await old.value
        XCTAssertEqual(m.phase, .results([roma]))
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

    private var container: ModelContainer?
    private func twoProfiles() throws -> (ModelContext, old: Profile, keeper: Profile) {
        let built = try StoreFactory.build(.memory)
        container = built
        let c = built.mainContext
        let old = Profile(); old.updatedAt = .distantPast
        let keeper = Profile(); keeper.updatedAt = .now
        c.insert(old); c.insert(keeper); try c.save()
        return (c, old, keeper)
    }
    func testLaCittaVaSulProfiloCheSopravvive() throws {
        let (c, old, keeper) = try twoProfiles()
        let all = try c.fetch(FetchDescriptor<Profile>())
        ProfileStore.update(all, in: c) { $0.apply(city: milano.renamed("Roma")) }
        XCTAssertEqual(old.cityName, "Milano")
        XCTAssertEqual(keeper.cityName, "Roma")
        XCTAssertEqual(try ProfileStore.current(in: c).cityName, "Roma")
    }
    func testIlTemaVaSulProfiloCheSopravvive() throws {
        let (c, old, keeper) = try twoProfiles()
        let all = try c.fetch(FetchDescriptor<Profile>())
        ProfileStore.update(all, in: c) { $0.setTheme("dark") }
        XCTAssertEqual(old.theme, "system")
        XCTAssertEqual(keeper.theme, "dark")
        XCTAssertEqual(try ProfileStore.current(in: c).theme, "dark")
    }
}

private extension City {
    func renamed(_ name: String) -> City {
        City(id: id, name: name, latitude: latitude, longitude: longitude, country: country, region: region)
    }
}
