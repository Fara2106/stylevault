import XCTest
@testable import StyleVaultCore

/// Stessi casi di src/utils/outfitAdvice.test.js.
final class OutfitAdviceTests: XCTestCase {
    private func outfitOf(top: OutfitPiece? = mk("top1", "tops"), bottom: OutfitPiece? = mk("bottom1", "bottoms"),
                          shoes: OutfitPiece? = mk("shoes1", "shoes"), outerwear: OutfitPiece? = nil,
                          colorHarmony: Int = 85) -> GeneratedOutfit {
        GeneratedOutfit(top: top, bottom: bottom, shoes: shoes, outerwear: outerwear, accessories: [], score: 80,
                        weatherMatch: 80, colorHarmony: colorHarmony, repetitionPenalty: 0)
    }

    private func partsOf(_ temps: [Double?], past: [Bool] = [false, false, false]) -> [DayPart] {
        [DayPartKey.morning, .afternoon, .evening].enumerated().map { i, key in
            DayPart(key: key, temperature: temps[i], code: 0, precipProb: 0, past: past[i], icon: .sun, descriptionKey: "weather.clear")
        }
    }

    private func advice(_ outfit: GeneratedOutfit, _ weather: DayForecast = weatherOf(), recentWear: [RecentWear] = [], occasion: String? = nil) -> [OutfitAdvice] {
        OutfitAdvisor.advice(for: outfit, weather: weather, recentWear: recentWear, occasion: occasion)
    }

    func testColoriArmonici() {
        let o = outfitOf(top: mk("t", "tops", colors: ["white"]), bottom: mk("b", "bottoms", colors: ["navy"]), colorHarmony: 88)
        XCTAssertTrue(advice(o).contains(.colorsHarmonious))
    }

    func testMonocromatico() { XCTAssertTrue(advice(outfitOf(colorHarmony: 88)).contains(.monochrome)) }

    func testColoriCheStridono() { XCTAssertTrue(advice(outfitOf(colorHarmony: 40)).contains(.colorsClash)) }

    func testTroppiColori() {
        let o = outfitOf(top: mk("t", "tops", colors: ["red"]), bottom: mk("b", "bottoms", colors: ["green"]),
                         shoes: mk("s", "shoes", colors: ["purple"]), outerwear: mk("o", "outerwear", colors: ["orange"]), colorHarmony: 55)
        XCTAssertTrue(advice(o).contains(.tooManyColors))
    }

    func testTroppoLeggero() {
        let o = outfitOf(top: mk("t", "tops", warmth: 1), bottom: mk("b", "bottoms", warmth: 1), shoes: mk("s", "shoes", warmth: 1))
        XCTAssertTrue(advice(o, weatherOf(temperature: 2)).contains(.tooLight(temp: 2)))
    }

    func testTroppoCaldo() {
        let o = outfitOf(top: mk("t", "tops", warmth: 5), bottom: mk("b", "bottoms", warmth: 5), shoes: mk("s", "shoes", warmth: 5))
        XCTAssertTrue(advice(o, weatherOf(temperature: 32)).contains(.tooWarm(temp: 32)))
    }

    func testPioggiaESandali() {
        let o = outfitOf(shoes: mk("s", "shoes", subcategory: "sandals"), outerwear: mk("o", "outerwear", subcategory: "raincoat"))
        XCTAssertTrue(advice(o, weatherOf(rain: true)).contains(.rainShoes))
    }

    func testPioggiaSenzaCapospalla() {
        XCTAssertTrue(advice(outfitOf(), weatherOf(temperature: 15, rain: true)).contains(.rainOuter))
    }

    func testIndossatoDiRecente() {
        let a = advice(outfitOf(), recentWear: [RecentWear(itemID: "top1", date: "2026-07-06")])
        XCTAssertTrue(a.contains(.wornRecently(date: "2026-07-06")))
    }

    func testBlazerSuCasual() {
        let o = outfitOf(outerwear: mk("o", "outerwear", subcategory: "blazer"))
        XCTAssertTrue(advice(o, occasion: "casual").contains(.elevated))
    }

    func testStrati() {
        let a = advice(outfitOf(), weatherOf(parts: partsOf([9.2, 19.4, 15])))
        XCTAssertTrue(a.contains(.layers(cold: 9, coldPart: .morning, warm: 19, warmPart: .afternoon)))
    }

    func testNienteStratiSottoOttoGradi() {
        XCTAssertFalse(advice(outfitOf(), weatherOf(parts: partsOf([12, 19.9, 15]))).contains { if case .layers = $0 { true } else { false } })
    }

    func testLeFascePassateNonContano() {
        let a = advice(outfitOf(), weatherOf(parts: partsOf([2, 15, 12], past: [true, false, false])))
        XCTAssertFalse(a.contains { if case .layers = $0 { true } else { false } })
    }

    func testPioggiaDalleDiciotto() {
        let a = advice(outfitOf(), weatherOf(parts: partsOf([15, 18, 16]), rainFrom: 18, rainFromStart: false))
        XCTAssertTrue(a.contains(.rainLater(hour: "18:00")))
    }

    func testPioggiaDalMattino() {
        let a = advice(outfitOf(), weatherOf(parts: partsOf([15, 18, 16]), rainFrom: 8, rainFromStart: true))
        XCTAssertFalse(a.contains { if case .rainLater = $0 { true } else { false } })
    }

    func testGiornoSenzaFasce() {
        let a = advice(outfitOf(), weatherOf(rainFrom: 18))
        XCTAssertFalse(a.contains { if case .rainLater = $0 { true } else { false } })
    }
}
