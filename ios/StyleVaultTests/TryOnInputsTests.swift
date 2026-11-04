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

    // MARK: - Trasparenza e allineamento

    private func transparent(_ w: Int, _ h: Int) -> CGImage {
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.clear(CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()!
    }

    func testTransparentImageBecomesWhite() {
        let img = transparent(768, 1024)
        let t = TryOnInputs.modelTensor(img)
        for i in stride(from: 0, to: t.count, by: 997) { XCTAssertEqual(t[i], 1, accuracy: 0.01) }
        let d = TryOnInputs.dinoPixels(img)
        let mean: [Float] = [0.485, 0.456, 0.406], std: [Float] = [0.229, 0.224, 0.225]
        for ch in 0..<3 {
            XCTAssertEqual(d[ch * 224 * 224 + 5000], (1 - mean[ch]) / std[ch], accuracy: 0.02)
        }
        let p = TryOnInputs.pad3x4(transparent(600, 1200))
        XCTAssertEqual(TryOnInputs.modelTensor(p.image)[512 * 768 + 384], 1, accuracy: 0.01)
    }

    /// Foto grigia con un quadrato rosso; ritorna il baricentro del rosso.
    private func markerCentroid(_ image: CGImage) -> (Double, Double)? {
        let w = image.width, h = image.height
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        let p = ctx.data!.assumingMemoryBound(to: UInt8.self)
        var sx = 0.0, sy = 0.0, n = 0.0
        for y in 0..<h { for x in 0..<w {
            let o = y * w * 4 + x * 4
            if p[o] > 190 && p[o + 1] < 100 { sx += Double(x); sy += Double(y); n += 1 }
        } }
        return n > 0 ? (sx / n, sy / n) : nil
    }

    private func checkAlignment(w: Int, h: Int, marker: CGRect, file: StaticString = #filePath, line: UInt = #line) throws {
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.setFillColor(gray: 0.5, alpha: 1); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        ctx.fill(CGRect(x: marker.minX, y: CGFloat(h) - marker.maxY, width: marker.width, height: marker.height))
        let padded = TryOnInputs.pad3x4(ctx.makeImage()!)
        let back = TryOnInputs.unpad(padded.image, content: padded.content, to: CGSize(width: w, height: h))
        XCTAssertEqual(back.width, w, file: file, line: line)
        XCTAssertEqual(back.height, h, file: file, line: line)
        let c = try XCTUnwrap(markerCentroid(back), file: file, line: line)
        XCTAssertEqual(c.0, Double(marker.midX), accuracy: 2, file: file, line: line)
        XCTAssertEqual(c.1, Double(marker.midY), accuracy: 2, file: file, line: line)
    }

    func testPadUnpadKeepsAlignment() throws {
        try checkAlignment(w: 1536, h: 2048, marker: CGRect(x: 1000, y: 300, width: 120, height: 120))
        try checkAlignment(w: 2048, h: 1024, marker: CGRect(x: 1500, y: 200, width: 120, height: 120))
    }
}
