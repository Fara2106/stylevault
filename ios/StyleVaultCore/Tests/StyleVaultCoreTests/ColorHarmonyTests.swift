import XCTest
@testable import StyleVaultCore

/// I risultati attesi vengono da `colorHarmony.js` e `weatherMapper.js` (tag `archivio-ibrida-e-sito`): vedi harmony-parity.json.
private struct Parity: Decodable {
    struct HSLCase: Decodable { let hex: String; let h: Int; let s: Int; let l: Int }
    struct Pair: Decodable { let a: String; let b: String; let compatible: Bool; let score: Int }
    struct ColorSet: Decodable { let colors: [String]; let score: Int }
    struct Warmth: Decodable { let t: Double; let w: Double; let target: Int }
    let hsl: [HSLCase]
    let pairs: [Pair]
    let sets: [ColorSet]
    let warmth: [Warmth]
}

final class ColorHarmonyTests: XCTestCase {
    private func parity() throws -> Parity {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "harmony-parity", withExtension: "json", subdirectory: "Fixtures"))
        return try JSONDecoder().decode(Parity.self, from: Data(contentsOf: url))
    }

    func testHSLComeIlSito() throws {
        for c in try parity().hsl {
            XCTAssertEqual(ColorHarmony.hsl(hex: c.hex), ColorHarmony.HSL(h: c.h, s: c.s, l: c.l), c.hex)
        }
    }

    func testCoppieComeIlSito() throws {
        for p in try parity().pairs {
            XCTAssertEqual(ColorHarmony.areCompatible(p.a, p.b), p.compatible, "\(p.a) \(p.b)")
            XCTAssertEqual(ColorHarmony.score([p.a, p.b]), p.score, "\(p.a) \(p.b)")
        }
    }

    func testGruppiComeIlSito() throws {
        for s in try parity().sets {
            XCTAssertEqual(ColorHarmony.score(s.colors), s.score, "\(s.colors)")
        }
    }

    func testCasiLimite() {
        XCTAssertEqual(ColorHarmony.score([]), 100)
        XCTAssertEqual(ColorHarmony.score(["#FF0000"]), 100)
        XCTAssertEqual(ColorHarmony.score(["#FF0000", "#FF0000"]), 100)
    }

    func testCaloreComeIlSito() throws {
        for w in try parity().warmth {
            XCTAssertEqual(OutfitEngine.warmthTarget(temperature: w.t, windSpeed: w.w), w.target, "\(w.t) \(w.w)")
        }
    }

    func testArrotondamentoComeJavaScript() {
        XCTAssertEqual(jsRound(2.5), 3)
        XCTAssertEqual(jsRound(-2.5), -2)
        XCTAssertEqual(jsRound(-2.6), -3)
    }
}
