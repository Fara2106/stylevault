import StyleVaultCore
import XCTest
@testable import StyleVaultNative

private struct StubLoader: ForecastLoading {
    var result: Result<ForecastResult, Error>
    func load(place: ForecastPlace) async throws -> ForecastResult { try result.get() }
}

private struct Offline: Error {}

@MainActor final class OutfitPageModelTests: XCTestCase {
    private let defaults = UserDefaults(suiteName: "OutfitPageModelTests")!
    private let milano = ForecastPlace(name: "Milano", latitude: 45.46, longitude: 9.19, isPosition: false)

    override func setUp() { defaults.removePersistentDomain(forName: "OutfitPageModelTests") }

    private func day(_ date: String, temperature: Double = 20, rain: Bool = false) -> DayForecast {
        DayForecast(city: "Milano", date: date, tMin: 10, tMax: 22, temperature: temperature, windSpeed: 5, uvIndex: 2,
                    precipProb: 0, icon: .sun, descriptionKey: "weather.clear", rain: rain, snow: false)
    }

    private func forecast(stale: Bool = false) -> ForecastResult {
        ForecastResult(days: [day("2026-11-06"), day("2026-11-07", temperature: 5)], stale: stale, fetchedAt: .now)
    }

    private let wardrobe = [OutfitPiece(id: "t", category: "tops", colors: ["black"]),
                            OutfitPiece(id: "t2", category: "tops", colors: ["white"]),
                            OutfitPiece(id: "b", category: "bottoms", colors: ["navy"]),
                            OutfitPiece(id: "s", category: "shoes", colors: ["black"])]

    private func model() -> OutfitPageModel { OutfitPageModel(defaults: defaults) }

    func testIlMeteoArrivaEGeneraDaSolo() async {
        let m = model()
        await m.loadForecast(for: milano, using: StubLoader(result: .success(forecast())))
        XCTAssertEqual(m.dayWeather(city: "Milano", today: "2026-11-06")?.date, "2026-11-06")
        m.generateIfNeeded(items: wardrobe, recentWear: [])
        XCTAssertFalse(m.outfits.isEmpty)
        let first = m.outfits
        m.generateIfNeeded(items: wardrobe, recentWear: [])
        XCTAssertEqual(m.outfits, first)
    }

    func testCambiandoGiornoRifaGliOutfitConQuelMeteo() async {
        let m = model()
        await m.loadForecast(for: milano, using: StubLoader(result: .success(forecast())))
        m.generateIfNeeded(items: wardrobe, recentWear: [])
        m.select(day: 1)
        XCTAssertTrue(m.outfits.isEmpty)
        XCTAssertEqual(m.dayWeather(city: "Milano", today: "2026-11-06")?.temperature, 5)
    }

    func testSenzaReteSiImpostaAMano() async {
        let m = model()
        await m.loadForecast(for: milano, using: StubLoader(result: .failure(Offline())))
        XCTAssertTrue(m.weatherError)
        m.manualTemperature = 7
        m.manualRain = true
        let weather = m.dayWeather(city: "Milano", today: "2026-11-06")
        XCTAssertEqual(weather?.temperature, 7)
        XCTAssertEqual(weather?.rain, true)
        XCTAssertEqual(weather?.date, "2026-11-06")
        m.generate(items: wardrobe, recentWear: [])
        XCTAssertFalse(m.outfits.isEmpty)
    }

    func testIlMeteoManualeSegueIlGiornoScelto() async {
        let m = model()
        await m.loadForecast(for: milano, using: StubLoader(result: .failure(Offline())))
        m.select(day: 3)
        XCTAssertEqual(m.dayWeather(city: "Milano", today: "2026-11-06")?.date, "2026-11-09")
    }

    func testCapoBloccatoRestaRigenerando() async {
        let m = model()
        await m.loadForecast(for: milano, using: StubLoader(result: .success(forecast())))
        m.toggleLock("t2")
        for _ in 0..<5 {
            m.generate(items: wardrobe, recentWear: [])
            XCTAssertTrue(m.outfits.allSatisfy { $0.top?.id == "t2" })
        }
        m.toggleLock("t2")
        XCTAssertTrue(m.lockedIDs.isEmpty)
    }

    func testRigenerareAzzeraSalvatiEMessaggio() async throws {
        let m = model()
        await m.loadForecast(for: milano, using: StubLoader(result: .success(forecast())))
        m.generate(items: wardrobe, recentWear: [])
        let outfit = try XCTUnwrap(m.outfits.first)
        m.markSaved(outfit)
        m.wornDay = "2026-11-06"
        XCTAssertTrue(m.isSaved(outfit))
        m.generate(items: wardrobe, recentWear: [])
        XCTAssertFalse(m.isSaved(outfit))
        XCTAssertNil(m.wornDay)
    }

    func testTornandoSullaSchedaGliOutfitRestano() async {
        let m = model()
        let start = Date(timeIntervalSince1970: 1_000_000)
        let loader = StubLoader(result: .success(ForecastResult(days: forecast().days, stale: false, fetchedAt: start)))
        await m.loadForecast(for: milano, using: loader, now: start)
        m.toggleLock("t2")
        m.generateIfNeeded(items: wardrobe, recentWear: [])
        let shown = m.outfits
        await m.loadForecast(for: milano, using: loader, now: start.addingTimeInterval(600))
        XCTAssertEqual(m.outfits, shown)
        XCTAssertEqual(m.lockedIDs, ["t2"])
    }

    func testDopoUnOraIlMeteoSiAggiorna() async {
        let m = model()
        let start = Date(timeIntervalSince1970: 1_000_000)
        let loader = StubLoader(result: .success(ForecastResult(days: forecast().days, stale: false, fetchedAt: start)))
        await m.loadForecast(for: milano, using: loader, now: start)
        m.generateIfNeeded(items: wardrobe, recentWear: [])
        await m.loadForecast(for: milano, using: loader, now: start.addingTimeInterval(3700))
        XCTAssertTrue(m.outfits.isEmpty)
    }

    func testIlMeteoVecchioDellaCacheSiRiprova() async {
        let m = model()
        await m.loadForecast(for: milano, using: StubLoader(result: .success(forecast(stale: true))))
        m.generateIfNeeded(items: wardrobe, recentWear: [])
        await m.loadForecast(for: milano, using: StubLoader(result: .success(forecast())))
        XCTAssertEqual(m.forecast?.stale, false)
    }

    func testUnOutfitSiRegistraUnaVolta() async throws {
        let m = model()
        await m.loadForecast(for: milano, using: StubLoader(result: .success(forecast())))
        m.generate(items: wardrobe, recentWear: [])
        let outfit = try XCTUnwrap(m.outfits.first)
        XCTAssertFalse(m.isWorn(outfit))
        m.markWorn(outfit, day: "2026-11-06")
        XCTAssertTrue(m.isWorn(outfit))
        XCTAssertEqual(m.wornDay, "2026-11-06")
        m.generate(items: wardrobe, recentWear: [])
        XCTAssertFalse(m.isWorn(outfit))
    }

    func testLaPosizioneSiPuoSpegnere() {
        let m = model()
        m.chooseMyPosition()
        m.positionUnavailable = true
        m.useDefaultCity()
        XCTAssertEqual(m.choice, .defaultCity)
        XCTAssertFalse(m.positionUnavailable)
        XCTAssertEqual(model().choice, .defaultCity)
    }

    func testLaSceltaDelLuogoSiRicorda() {
        let m = model()
        // Niente permesso finché non lo si chiede: si parte dalla città del Profilo.
        XCTAssertEqual(m.choice, .defaultCity)
        let city = SavedCity(name: "Lisbona", latitude: 38.72, longitude: -9.14)
        m.choose(city)
        XCTAssertEqual(model().choice, .city(city))
        m.chooseMyPosition()
        XCTAssertEqual(model().choice, .position)
    }

    func testLuogoScegliTraManualePosizioneEPredefinita() {
        let m = model()
        XCTAssertEqual(m.place(defaultCity: milano), milano)
        XCTAssertEqual(m.placeKind, .fallback)
        let roma = ForecastPlace(name: "Roma", latitude: 41.9, longitude: 12.5, isPosition: true)
        m.receive(position: roma)
        XCTAssertEqual(m.place(defaultCity: milano), milano, "senza consenso la posizione non conta")
        m.chooseMyPosition()
        m.receive(position: roma)
        XCTAssertEqual(m.place(defaultCity: milano).name, "Roma")
        XCTAssertEqual(m.placeKind, .position)
        m.choose(SavedCity(name: "Lisbona", latitude: 38.72, longitude: -9.14))
        XCTAssertEqual(m.place(defaultCity: milano).name, "Lisbona")
        XCTAssertEqual(m.placeKind, .manual)
    }

    func testUnaPosizioneQuasiUgualeNonCambiaLuogo() {
        let m = model()
        m.chooseMyPosition()
        let first = ForecastPlace(name: "Roma", latitude: 41.9, longitude: 12.5, isPosition: true)
        m.receive(position: first)
        m.receive(position: ForecastPlace(name: "Roma Nord", latitude: 41.93, longitude: 12.52, isPosition: true))
        XCTAssertEqual(m.place(defaultCity: milano), first)
    }

    func testLaCacheVienePresaSenzaRete() async throws {
        let store = ForecastCache(defaults: defaults)
        let place = ForecastPlace(name: "Roma", latitude: 41.9, longitude: 12.5, isPosition: true)
        let saved = forecast()
        store.save(saved.days, for: place, at: saved.fetchedAt)
        XCTAssertEqual(store.read(for: place)?.days, saved.days)
        XCTAssertEqual(store.read(for: place)?.stale, true)
        XCTAssertNil(store.read(for: milano))
        // Una sola chiave per la posizione: niente storico dei posti sul dispositivo.
        let other = ForecastPlace(name: "Napoli", latitude: 40.85, longitude: 14.27, isPosition: true)
        XCTAssertNotNil(store.read(for: other))
    }
}
