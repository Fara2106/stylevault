import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import StyleVault

final class TryOnInputsTests: XCTestCase {
    private var fixtures: URL {
        Bundle(for: TryOnInputsTests.self).resourceURL!.appendingPathComponent("realistic")
    }

    private func solid(_ w: Int, _ h: Int, r: UInt8 = 200, g: UInt8 = 30, b: UInt8 = 30) -> CGImage {
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.setFillColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()!
    }

    // Valori di tools/avatar-realistico/out/bench-inputs/manifest.json (diffusers, 10 passi, shift 3).
    func testScheduleMatchesDiffusers() {
        let timesteps: [Double] = [1000.0, 960.1293334960938, 913.3489990234375, 857.6923217773438,
                                   790.3682861328125, 707.2785034179688, 602.1505737304688,
                                   464.87603759765625, 278.0487976074219, 8.928571701049805]
        let sigmas: [Double] = [1.0, 0.9601293206214905, 0.9133489727973938, 0.857692301273346,
                                0.7903682589530945, 0.7072784900665283, 0.602150559425354,
                                0.4648760259151459, 0.2780487835407257, 0.008928571827709675, 0.0]
        let s = TryOnInputs.schedule(steps: 10, shift: 3)
        XCTAssertEqual(s.timesteps.count, 10)
        XCTAssertEqual(s.sigmas.count, 11)
        for (a, b) in zip(s.timesteps, timesteps) { XCTAssertEqual(a, b, accuracy: 1e-4) }
        for (a, b) in zip(s.sigmas, sigmas) { XCTAssertEqual(a, b, accuracy: 1e-4) }
    }

    func testDinoPixelsCloseToPython() throws {
        let data = try Data(contentsOf: fixtures.appendingPathComponent("cloth.jpg"))
        let image = try XCTUnwrap(TryOnInputs.image(from: data))
        XCTAssertEqual(image.width, 768)
        XCTAssertEqual(image.height, 1024)
        let mine = TryOnInputs.dinoPixels(image)
        let bin = try Data(contentsOf: fixtures.appendingPathComponent("cloth-pixels.bin"))
        let ref: [Float] = bin.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        XCTAssertEqual(mine.count, 3 * 224 * 224)
        XCTAssertEqual(ref.count, mine.count)
        var sum = 0.0
        for (a, b) in zip(mine, ref) { sum += Double(abs(a - b)) }
        XCTAssertLessThan(sum / Double(mine.count), 0.03)
    }

    func testPadRoundTrip() {
        // (larghezza, altezza, rect atteso)
        let cases: [(Int, Int, CGRect)] = [
            (600, 1200, CGRect(x: 128, y: 0, width: 512, height: 1024)),
            (1200, 600, CGRect(x: 0, y: 320, width: 768, height: 384)),
            (768, 1024, CGRect(x: 0, y: 0, width: 768, height: 1024)),
        ]
        for (w, h, expected) in cases {
            let padded = TryOnInputs.pad3x4(solid(w, h))
            XCTAssertEqual(padded.image.width, 768)
            XCTAssertEqual(padded.image.height, 1024)
            XCTAssertEqual(padded.content, expected, "\(w)x\(h)")
            let back = TryOnInputs.unpad(padded.image, content: padded.content, to: CGSize(width: w, height: h))
            XCTAssertEqual(back.width, w)
            XCTAssertEqual(back.height, h)
        }
    }

    func testPadFillsWhiteAndKeepsPhoto() {
        let padded = TryOnInputs.pad3x4(solid(1200, 600))
        let t = TryOnInputs.modelTensor(padded.image)
        let plane = 768 * 1024
        // riga 0 = bordo bianco, riga centrale = foto rossa
        XCTAssertEqual(t[0], 1, accuracy: 0.02)
        XCTAssertEqual(t[plane], 1, accuracy: 0.02)
        let mid = 512 * 768 + 384
        XCTAssertEqual(t[mid], 200 / 127.5 - 1, accuracy: 0.03)
        XCTAssertEqual(t[plane + mid], 30 / 127.5 - 1, accuracy: 0.03)
    }

    func testModelTensorLayoutAndRange() {
        let t = TryOnInputs.modelTensor(solid(768, 1024, r: 255, g: 0, b: 51))
        XCTAssertEqual(t.count, 3 * 1024 * 768)
        XCTAssertEqual(t[0], 1, accuracy: 1e-5)
        XCTAssertEqual(t[1024 * 768], -1, accuracy: 1e-5)
        XCTAssertEqual(t[2 * 1024 * 768 + 5], 51 / 127.5 - 1, accuracy: 1e-5)
    }

    func testNoiseIsGaussianAndStable() {
        let a = TryOnInputs.noise(count: 1_000_000, seed: 42)
        let b = TryOnInputs.noise(count: 1_000_000, seed: 42)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, TryOnInputs.noise(count: 1_000_000, seed: 43))
        XCTAssertEqual(TryOnInputs.noise(count: 7, seed: 1).count, 7)
        var sum = 0.0
        for x in a { sum += Double(x) }
        let mean = sum / Double(a.count)
        var v = 0.0
        for x in a { v += (Double(x) - mean) * (Double(x) - mean) }
        XCTAssertEqual(mean, 0, accuracy: 0.01)
        XCTAssertEqual(v / Double(a.count), 1, accuracy: 0.01)
    }

    func testImageFromDataHonoursExifOrientation() throws {
        // JPEG 40 larghi x 20 alti con orientamento 6 (ruotato di 90°): diventa 20x40.
        let src = solid(40, 20)
        let out = NSMutableData()
        let dest = try XCTUnwrap(CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(dest, src, [kCGImagePropertyOrientation: 6] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
        let image = try XCTUnwrap(TryOnInputs.image(from: out as Data))
        XCTAssertEqual(image.width, 20)
        XCTAssertEqual(image.height, 40)
        XCTAssertNil(TryOnInputs.image(from: Data([1, 2, 3])))
    }
}
