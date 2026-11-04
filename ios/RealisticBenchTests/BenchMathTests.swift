import XCTest
@testable import RealisticBench

final class BenchMathTests: XCTestCase {
    func testTestiAffiancatiAllargatiEConTokenAZero() {
        // 2 token: CLIP-L da 2 valori, CLIP-G da 3, larghezza 6, 1 token T5 a zero
        let out = BenchMath.textEmbedding([1, 2, 3, 4], lDim: 2, [5, 6, 7, 8, 9, 10], gDim: 3,
                                          tokens: 2, width: 6, zeroTokens: 1)
        XCTAssertEqual(out, [1, 2, 5, 6, 7, 0,
                             3, 4, 8, 9, 10, 0,
                             0, 0, 0, 0, 0, 0])
    }

    func testLatenteVAEDallaMedia() {
        // momenti [2 canali media + 2 log-varianza] su piani da 2: solo la media, normalizzata
        let m: [Float] = [1, 2, 3, 4, 9, 9, 9, 9]
        let out = BenchMath.vaeLatent(moments: m, channels: 2, plane: 2)
        let expected = [1, 2, 3, 4].map { (Float($0) - BenchMath.vaeShift) * BenchMath.vaeScale }
        XCTAssertEqual(out, expected)
    }

    func testImpilaInAltezzaPerCanale() {
        // 2 canali, piani 1×2: per canale prima la persona poi il capo
        let out = BenchMath.stackHeight(top: [1, 2, 3, 4], bottom: [5, 6, 7, 8], channels: 2, plane: 2)
        XCTAssertEqual(out, [1, 2, 5, 6, 3, 4, 7, 8])
    }

    func testPassoEuleroConGuida() {
        var latents: [Float] = [1, 1]
        // ramo incondizionato [0, 1], condizionato [2, 1]; guida 2.5, dt -0.1
        BenchMath.eulerStep(&latents, noisePred: [0, 1, 2, 1], guidance: 2.5, dt: -0.1)
        XCTAssertEqual(latents[0], 1 - 0.1 * (0 + 2.5 * 2), accuracy: 1e-6)
        XCTAssertEqual(latents[1], 1 - 0.1 * 1, accuracy: 1e-6)
    }

    func testDecodificaPrendeLaMetaDiSopra() {
        // 1 canale, 2 righe impilate (persona sopra, capo sotto) da 2 colonne
        let out = BenchMath.personLatent([1, 2, 3, 4], channels: 1, rows: 1, cols: 2)
        XCTAssertEqual(out[0], 1 / BenchMath.vaeScale + BenchMath.vaeShift, accuracy: 1e-6)
        XCTAssertEqual(out.count, 2)
    }

    func testFeatureDelCapoDuplicateERamoIncondizionatoAZero() {
        var dst = [Float](repeating: -1, count: 2 * 2 * 2 * 3)   // [2, 2·rows, cols], rows 2, cols 3
        let d: [Float] = [1, 2, 3, 4, 5, 6]
        dst.withUnsafeMutableBufferPointer { BenchMath.garmentFeature(d, rows: 2, cols: 3, into: $0.baseAddress!) }
        XCTAssertEqual(Array(dst[0..<12]), [Float](repeating: 0, count: 12))
        XCTAssertEqual(Array(dst[12..<24]), d + d)
    }

    func testImmagineRGBA() {
        // 1×2 pixel: canali in [-1, 1] → 0…255, alfa pieno
        let px = BenchMath.rgba([-1, 1, 0, 0, 1, -1], width: 2, height: 1)
        XCTAssertEqual(px, [0, 128, 255, 255, 255, 128, 0, 255])
    }
}
