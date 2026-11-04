import XCTest
@testable import RealisticBench

final class BenchEstimateTests: XCTestCase {
    func testStimaVistaDavanti() {
        let t = BenchTimes(textEncoder: 0.2, textEncoder2: 0.5, imageEncoder: 0.3, vaeEncoder: 0.4,
                           denoiserGarment: 1.0, denoiser: 2.0, vaeDecoder: 0.6)
        // 2 codifiche VAE (persona e capo), 10 passi ognuno con UNet capo + UNet prova
        XCTAssertEqual(BenchEstimate.frontView(t, steps: 10),
                       0.2 + 0.5 + 0.3 + 2 * 0.4 + 10 * (1.0 + 2.0) + 0.6, accuracy: 1e-9)
        XCTAssertTrue(BenchEstimate.passes(seconds: 59, device: .iPhone18ProMax))
        XCTAssertFalse(BenchEstimate.passes(seconds: 61, device: .iPhone18ProMax))
        XCTAssertTrue(BenchEstimate.passes(seconds: 90, device: .iPhone15Pro))
        XCTAssertFalse(BenchEstimate.passes(seconds: 91, device: .iPhone15Pro))
        XCTAssertTrue(BenchEstimate.passes(seconds: 60, device: .iPad))
        XCTAssertFalse(BenchEstimate.passes(seconds: 61, device: .iPad))
    }

    func testPreparazionePrimoAvvio() {
        let steady = BenchTimes(textEncoder: 0.2, textEncoder2: 0.5, imageEncoder: 0.3, vaeEncoder: 0.4,
                                denoiserGarment: 1.0, denoiser: 2.0, vaeDecoder: 0.6)
        var first = steady
        first.denoiser = 40
        first.vaeDecoder = 0.1   // più veloce alla prima: non conta come preparazione
        XCTAssertEqual(BenchEstimate.firstRunExtra(first: first, steady: steady), 38, accuracy: 1e-9)
    }
}
