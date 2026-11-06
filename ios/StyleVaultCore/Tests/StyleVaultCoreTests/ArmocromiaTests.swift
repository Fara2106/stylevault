import XCTest
@testable import StyleVaultCore

/// Gli stessi casi di `armocromiaClassifier.test.js`, `armocromiaWardrobe.test.js`,
/// `colorSampling.test.js` e `shopLinks.test.js` del sito.
final class ArmocromiaTests: XCTestCase {
    private let fixtures: [String: FaceColors] = [
        "light-spring": .init(skin: "#f7dcc9", hair: "#e9c98f", eyes: "#8fb6a8"),
        "light-summer": .init(skin: "#f0d9d2", hair: "#cfc4b0", eyes: "#a9c1cf"),
        "true-spring": .init(skin: "#edc39e", hair: "#a9752e", eyes: "#6f8f55"),
        "true-summer": .init(skin: "#e6c4bd", hair: "#7e7468", eyes: "#6f8dad"),
        "true-autumn": .init(skin: "#cf9c6b", hair: "#6b4423", eyes: "#63512c"),
        "true-winter": .init(skin: "#e3c0b8", hair: "#2e2a28", eyes: "#4f6b8f"),
        "bright-spring": .init(skin: "#f4cdb0", hair: "#a86f2f", eyes: "#2e8b74"),
        "bright-winter": .init(skin: "#f0cabe", hair: "#221d1c", eyes: "#1e63c8"),
        "soft-autumn": .init(skin: "#ddb394", hair: "#8a6b4a", eyes: "#84805f"),
        "soft-summer": .init(skin: "#e5c6bf", hair: "#9a8f83", eyes: "#8496a0"),
        "deep-autumn": .init(skin: "#b97f4e", hair: "#4a2d17", eyes: "#5a3d20"),
        "deep-winter": .init(skin: "#a9765c", hair: "#1d1a19", eyes: "#3a4a63"),
    ]

    func testRiconosceLeDodiciStagioni() {
        for (season, input) in fixtures {
            XCTAssertEqual(ArmocromiaClassifier.classify(input)?.season, season)
        }
    }

    func testEsponeAssiEConfidenza() throws {
        let result = try XCTUnwrap(ArmocromiaClassifier.classify(fixtures["deep-winter"]!))
        XCTAssertLessThan(result.axes.lightDeep, 0)
        XCTAssertGreaterThan(result.confidence, 0)
        XCTAssertLessThanOrEqual(result.confidence, 1)
    }

    func testSenzaOcchiLeStagioniScureRestanoCorrette() {
        var deep = fixtures["deep-winter"]!; deep.eyes = nil
        var autumn = fixtures["true-autumn"]!; autumn.eyes = nil
        XCTAssertEqual(ArmocromiaClassifier.classify(deep)?.season, "deep-winter")
        XCTAssertEqual(ArmocromiaClassifier.classify(autumn)?.season, "true-autumn")
    }

    func testSenzaCapelliLaConfidenzaCrolla() throws {
        var input = fixtures["light-spring"]!; input.hair = nil
        XCTAssertLessThan(try XCTUnwrap(ArmocromiaClassifier.classify(input)).confidence, 0.3)
    }

    func testSenzaPelleECapelliNessunVerdetto() {
        XCTAssertNil(ArmocromiaClassifier.classify(.init(skin: nil, hair: nil, eyes: "#4f6b8f")))
    }

    func testLeStagioniSonoDodiciConTuttiIDati() {
        XCTAssertEqual(ArmocromiaSeasons.all.map(\.id).sorted(), fixtures.keys.sorted())
        for season in ArmocromiaSeasons.all {
            XCTAssertEqual(season.palette.count, 6, season.id)
            XCTAssertEqual(season.avoid.count, 3, season.id)
            XCTAssertEqual(season.neutrals.count, 3, season.id)
            XCTAssertFalse(season.makeup.lips.isEmpty, season.id)
        }
    }

    func testHexRgb() {
        XCTAssertEqual(ColorLab.rgb(hex: "#ff8000"), RGB(r: 255, g: 128, b: 0))
        XCTAssertNil(ColorLab.rgb(hex: "zzz"))
        XCTAssertEqual(ColorLab.hex(RGB(r: 255, g: 128, b: 0)), "#ff8000")
    }

    func testLabSuValoriNoti() {
        let white = ColorLab.lab(RGB(r: 255, g: 255, b: 255))
        XCTAssertEqual(white.L, 100, accuracy: 0.5)
        XCTAssertLessThan(abs(white.a), 0.5)
        XCTAssertEqual(ColorLab.lab(RGB(r: 0, g: 0, b: 0)).L, 0, accuracy: 0.5)
        let red = ColorLab.lab(RGB(r: 255, g: 0, b: 0))
        XCTAssertEqual(red.L, 53.2, accuracy: 0.5)
        XCTAssertGreaterThan(red.a, 70)
    }

    func testAndataERitornoLabEntroDue() {
        for c in [RGB(r: 12, g: 200, b: 99), RGB(r: 240, g: 219, b: 200)] {
            let back = ColorLab.rgb(ColorLab.lab(c))
            XCTAssertLessThanOrEqual(abs(back.r - c.r), 2)
            XCTAssertLessThanOrEqual(abs(back.g - c.g), 2)
            XCTAssertLessThanOrEqual(abs(back.b - c.b), 2)
        }
    }

    func testColoreRappresentativoScartaGliEstremi() throws {
        var pixels = Array(repeating: RGB(r: 200, g: 150, b: 120), count: 80)
        pixels += Array(repeating: RGB(r: 0, g: 0, b: 0), count: 10)
        pixels += Array(repeating: RGB(r: 255, g: 255, b: 255), count: 10)
        let hex = try XCTUnwrap(ColorLab.representative(pixels))
        let rgb = try XCTUnwrap(ColorLab.rgb(hex: hex))
        XCTAssertLessThanOrEqual(abs(rgb.r - 200), 2)
        XCTAssertLessThanOrEqual(abs(rgb.g - 150), 2)
        XCTAssertNil(ColorLab.representative([]))
    }

    func testBordeauxEntraInPaletteDeepWinterArancioNo() {
        let matches = ArmocromiaWardrobe.match([("a", ["burgundy"]), ("b", ["orange"])], season: "deep-winter")
        XCTAssertEqual(matches.map(\.id), ["a"])
        XCTAssertLessThanOrEqual(matches[0].distance, ArmocromiaWardrobe.inPaletteMax)
    }

    func testGuardarobaOrdinatoPerDistanza() {
        let matches = ArmocromiaWardrobe.match([("lontano", ["navy"]), ("vicino", ["burgundy"])], season: "deep-winter")
        XCTAssertEqual(matches.count, 2)
        XCTAssertLessThanOrEqual(matches[0].distance, matches[1].distance)
    }

    func testGuardarobaSaltaCapiSenzaColoriEStagioniIgnote() {
        XCTAssertTrue(ArmocromiaWardrobe.match([("x", []), ("y", ["inventato"])], season: "deep-winter").isEmpty)
        XCTAssertTrue(ArmocromiaWardrobe.match([("a", ["burgundy"])], season: "finta").isEmpty)
    }

    func testVerdettoSopravviveAlSalvataggio() throws {
        let verdict = ArmocromiaVerdict(season: "deep-winter", detected: fixtures["deep-winter"]!, confidence: 0.4,
                                        chosenByHand: false, updatedAt: Date(timeIntervalSince1970: 100))
        let back = try ArmocromiaVerdict.decode(verdict.encoded())
        XCTAssertEqual(back, verdict)
        XCTAssertNil(ArmocromiaVerdict.decode(nil))
    }

    func testIlVerdettoDelSitoSiLegge() throws {
        let json = ##"{"season":"true-autumn","detected":{"skin":"#cf9c6b","hair":"#6b4423","eyes":null},"axes":{"lightDeep":-0.2},"confidence":0.31,"updatedAt":"2026-07-19T10:00:00.000Z"}"##
        let verdict = try XCTUnwrap(ArmocromiaVerdict.decode(Data(json.utf8)))
        XCTAssertEqual(verdict.season, "true-autumn")
        XCTAssertEqual(verdict.detected.hair, "#6b4423")
        XCTAssertNil(verdict.detected.eyes)
        XCTAssertFalse(verdict.chosenByHand)
    }

    func testLinkDeiNegozi() throws {
        let links = ShopLinks.search(kind: .clothing, query: "blu navy", language: "it")
        XCTAssertEqual(links.map(\.label), ["Zalando", "ASOS", "Amazon"])
        XCTAssertEqual(links[0].url.absoluteString, "https://www.zalando.it/catalogo/?q=blu%20navy")
        XCTAssertEqual(ShopLinks.search(kind: .makeup, query: "rossetto", language: "en")[0].url.absoluteString,
                       "https://www.notino.co.uk/search.asp?exps=rossetto")
        XCTAssertEqual(ShopLinks.one(shop: "hm", query: "scarpe & co", language: "it")?.url.absoluteString,
                       "https://www2.hm.com/it_it/search-results.html?q=scarpe%20%26%20co")
        XCTAssertNil(ShopLinks.one(shop: "boh", query: "x", language: "it"))
        XCTAssertEqual(ShopLinks.home(kind: .makeup, language: "it").map(\.label), ["Sephora", "Douglas"])
    }
}
