import XCTest
@testable import StyleVaultCore

/// Stessi casi di `outfitAlgorithm.test.js` (tag `archivio-ibrida-e-sito`).
final class OutfitEngineTests: XCTestCase {
    private var rng = SeededGenerator()

    private var baseWardrobe: [OutfitPiece] {
        [mk("top1", "tops"), mk("top2", "tops"), mk("top3", "tops"), mk("bottom1", "bottoms"),
         mk("bottom2", "bottoms"), mk("shoes1", "shoes"), mk("shoes2", "shoes")]
    }

    private func generate(_ items: [OutfitPiece], _ weather: DayForecast = weatherOf(), occasion: String = "all", count: Int = 3,
                          locked: [OutfitPiece] = [], recentWear: [RecentWear] = [], referenceDate: String? = nil) -> [GeneratedOutfit] {
        OutfitEngine.generate(items: items, weather: weather, occasion: occasion, count: count, locked: locked,
                              recentWear: recentWear, referenceDate: referenceDate, using: &rng)
    }

    func testGeneraOutfitCompleti() {
        let outfits = generate(baseWardrobe)
        XCTAssertFalse(outfits.isEmpty)
        for o in outfits {
            XCTAssertNotNil(o.top)
            XCTAssertNotNil(o.bottom)
            XCTAssertNotNil(o.shoes)
            XCTAssertGreaterThan(o.score, 0)
        }
    }

    func testGuardarobaVuoto() { XCTAssertEqual(generate([]), []) }

    func testCapoBloccatoRestaNelSuoPosto() {
        let locked = baseWardrobe[1]
        for _ in 0..<5 {
            let outfits = generate(baseWardrobe, locked: [locked])
            XCTAssertFalse(outfits.isEmpty)
            for o in outfits { XCTAssertEqual(o.top?.id, "top2") }
        }
    }

    func testBloccaAncheBottomEScarpe() {
        let w = baseWardrobe
        for o in generate(w, locked: [w[3], w[5]]) {
            XCTAssertEqual(o.bottom?.id, "bottom1")
            XCTAssertEqual(o.shoes?.id, "shoes1")
        }
    }

    func testCapoRecenteAbbassaIlPunteggio() throws {
        let w = [mk("top1", "tops"), mk("bottom1", "bottoms"), mk("shoes1", "shoes")]
        let fresh = try XCTUnwrap(generate(w, count: 1).first)
        let worn = try XCTUnwrap(generate(w, count: 1, recentWear: [RecentWear(itemID: "top1", date: "2026-07-07")],
                                          referenceDate: "2026-07-08").first)
        XCTAssertLessThan(worn.score, fresh.score)
    }

    func testPiuDiSetteGiorniNonPenalizza() throws {
        let w = [mk("top1", "tops"), mk("bottom1", "bottoms"), mk("shoes1", "shoes")]
        let fresh = try XCTUnwrap(generate(w, count: 1).first)
        let old = try XCTUnwrap(generate(w, count: 1, recentWear: [RecentWear(itemID: "top1", date: "2026-06-20")],
                                         referenceDate: "2026-07-08").first)
        XCTAssertEqual(old.score, fresh.score)
    }

    func testStagioneDalGiornoScelto() throws {
        let w = [mk("topW", "tops", season: "winter", warmth: 4), mk("bottomW", "bottoms", season: "winter", warmth: 4),
                 mk("shoesW", "shoes", season: "winter", warmth: 4), mk("topS", "tops", season: "summer", warmth: 1),
                 mk("bottomS", "bottoms", season: "summer", warmth: 1), mk("shoesS", "shoes", season: "summer", warmth: 1)]
        let jan = try XCTUnwrap(generate(w, weatherOf(temperature: 2, date: "2027-01-15"), count: 1).first)
        XCTAssertEqual([jan.top?.id, jan.bottom?.id, jan.shoes?.id], ["topW", "bottomW", "shoesW"])
        let jul = try XCTUnwrap(generate(w, weatherOf(temperature: 2, date: "2026-07-08"), count: 1).first)
        XCTAssertEqual([jul.top?.id, jul.bottom?.id, jul.shoes?.id], ["topS", "bottomS", "shoesS"])
    }

    func testSenzaPantaloniNeScarpeGeneraESegna() {
        let outfits = generate([mk("top1", "tops")])
        XCTAssertEqual(outfits.count, 1)
        XCTAssertEqual(outfits[0].top?.id, "top1")
        XCTAssertNil(outfits[0].bottom)
        XCTAssertNil(outfits[0].shoes)
        XCTAssertEqual(outfits[0].missing, [.bottom, .shoes])
    }

    func testSenzaTopSegnaIlTop() {
        let outfits = generate([mk("bottom1", "bottoms"), mk("shoes1", "shoes")])
        XCTAssertEqual(outfits.count, 1)
        XCTAssertNil(outfits[0].top)
        XCTAssertEqual(outfits[0].missing, [.top])
    }

    func testOutfitCompletoSenzaMancanze() {
        for o in generate(baseWardrobe) { XCTAssertEqual(o.missing, []) }
    }

    func testConAbitoNonServeIlPantalone() {
        let outfits = generate([mk("dress1", "dresses", occasion: "formal"), mk("shoes1", "shoes", occasion: "formal")], occasion: "formal")
        XCTAssertFalse(outfits.isEmpty)
        XCTAssertEqual(outfits[0].top?.id, "dress1")
        XCTAssertEqual(outfits[0].missing, [])
    }

    func testRipiegaSuCapiDiAltraStagione() {
        let outfits = generate([mk("top1", "tops"), mk("bottom1", "bottoms"), mk("boots", "shoes", season: "winter")])
        XCTAssertEqual(outfits[0].shoes?.id, "boots")
        XCTAssertEqual(outfits[0].bottom?.id, "bottom1")
        XCTAssertEqual(outfits[0].missing, [])
    }

    func testSoliAccessoriNonGeneranoNiente() {
        XCTAssertEqual(generate([mk("bag", "accessories")]), [])
    }

    func testLIntimoNonDiventaUnOutfit() {
        XCTAssertEqual(generate([mk("calze", "underwear")]), [])
    }

    func testSoliCapispallaGeneranoAncheColCaldo() throws {
        let outfit = try XCTUnwrap(generate([mk("coat", "outerwear", season: "winter")], weatherOf(temperature: 28)).first)
        XCTAssertEqual(outfit.outerwear?.id, "coat")
        XCTAssertEqual(outfit.missing, [.top, .bottom, .shoes])
    }

    func testSoloCapospallaDiAltraOccasioneGeneraComunque() throws {
        let outfit = try XCTUnwrap(generate([mk("blazer", "outerwear", occasion: "formal")], occasion: "sport").first)
        XCTAssertEqual(outfit.outerwear?.id, "blazer")
    }

    func testCapoInCategoriaPersonaleDiventaIlPezzoSopra() throws {
        let outfit = try XCTUnwrap(generate([mk("tuta", "6F9619FF-8B86-D011-B42D-00C04FC964FF")]).first)
        XCTAssertEqual(outfit.top?.id, "tuta")
        XCTAssertEqual(outfit.missing, [.bottom, .shoes])
    }

    func testCategoriaPersonaleNonPrendeIlPostoDeiTop() {
        let wardrobe = [mk("top1", "tops"), mk("tuta", "6F9619FF-8B86-D011-B42D-00C04FC964FF")]
        for outfit in generate(wardrobe, count: 3) { XCTAssertEqual(outfit.top?.id, "top1") }
    }

    func testCapoBloccatoInCategoriaPersonaleRestaNellOutfit() {
        let tuta = mk("tuta", "6F9619FF-8B86-D011-B42D-00C04FC964FF")
        for outfit in generate(baseWardrobe + [tuta], locked: [tuta]) { XCTAssertEqual(outfit.top?.id, "tuta") }
    }

    func testOmbrelloConLaPioggia() {
        let w = baseWardrobe + [mk("u", "accessories", subcategory: "umbrella")]
        for o in generate(w, weatherOf(rain: true)) { XCTAssertTrue(o.accessories.contains { $0.id == "u" }) }
    }

    func testCapospallaSottoIDiciottoGradi() {
        let w = baseWardrobe + [mk("coat", "outerwear", warmth: 3)]
        for o in generate(w, weatherOf(temperature: 12)) { XCTAssertEqual(o.outerwear?.id, "coat") }
        for o in generate(w, weatherOf(temperature: 25)) { XCTAssertNil(o.outerwear) }
    }

    func testPunteggioOrdinatoEDueOutfitMaiUguali() {
        let outfits = generate(baseWardrobe)
        XCTAssertEqual(outfits.map(\.score), outfits.map(\.score).sorted(by: >))
        let keys = outfits.map { [$0.top?.id, $0.bottom?.id, $0.shoes?.id, $0.outerwear?.id] }
        XCTAssertEqual(Set(keys).count, keys.count)
    }
}
