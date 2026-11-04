import CoreGraphics
import XCTest
@testable import StyleVault

/// La maschera della parte di sopra nuova: CoreGraphics puro, gira nel simulatore.
final class GarmentMaskTests: XCTestCase {
    private let srgb = CGColorSpace(name: CGColorSpace.sRGB)!

    /// Fondo sfumato con rumore ±`noise` e, se c'è, un rettangolo pieno (pixel, origine in alto).
    private func image(width: Int, height: Int, rect: CGRect? = nil, noise: Int = 10, seed: UInt64) -> CGImage {
        var rng = seed
        func next() -> Int {
            rng = rng &* 6364136223846793005 &+ 1442695040888963407
            return Int((rng >> 33) % UInt64(2 * noise + 1)) - noise
        }
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 4
                var rgb = [120 + 60 * x / width, 110 + 50 * y / height, 100]
                if let rect, rect.contains(CGPoint(x: Double(x) + 0.5, y: Double(y) + 0.5)) { rgb = [30, 60, 200] }
                for c in 0..<3 { pixels[i + c] = UInt8(clamping: rgb[c] + next()) }
            }
        }
        let ctx = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                            space: srgb, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        return ctx.makeImage()!
    }

    private func gray(_ mask: CGImage) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: mask.width * mask.height)
        let ctx = CGContext(data: &out, width: mask.width, height: mask.height, bitsPerComponent: 8,
                            bytesPerRow: mask.width, space: CGColorSpaceCreateDeviceGray(),
                            bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        ctx.draw(mask, in: CGRect(x: 0, y: 0, width: mask.width, height: mask.height))
        return out
    }

    /// Riquadro dei pixel bianchi (≥ 128), origine in alto.
    private func whiteBounds(_ mask: CGImage) -> CGRect {
        let px = gray(mask)
        var minX = Int.max, minY = Int.max, maxX = -1, maxY = -1
        for y in 0..<mask.height {
            for x in 0..<mask.width where px[y * mask.width + x] >= 128 {
                minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= 0 else { return .zero }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    func testMaskFindsChangedArea() {
        let rect = CGRect(x: 150, y: 200, width: 240, height: 300)
        let original = image(width: 600, height: 800, seed: 1)
        let result = image(width: 600, height: 800, rect: rect, seed: 2)   // rumore diverso: ±10 ovunque
        let mask = GarmentMask.make(original: original, result: result)
        XCTAssertEqual(mask.width, 600)
        XCTAssertEqual(mask.height, 800)
        let px = gray(mask)
        var inside = 0, insideWhite = 0, outside = 0, outsideBlack = 0
        for y in 0..<800 {
            for x in 0..<600 {
                let v = px[y * 600 + x]
                if rect.contains(CGPoint(x: Double(x) + 0.5, y: Double(y) + 0.5)) {
                    inside += 1; if v >= 128 { insideWhite += 1 }
                } else {
                    outside += 1; if v < 128 { outsideBlack += 1 }
                }
            }
        }
        XCTAssertGreaterThanOrEqual(Double(insideWhite) / Double(inside), 0.95)
        XCTAssertGreaterThanOrEqual(Double(outsideBlack) / Double(outside), 0.99)
    }

    func testMaskAlignsWithNon3x4Photo() {
        // Come nell'app: foto non 3:4 → bordo → risultato 768×1024 → si toglie il bordo
        let photo = image(width: 600, height: 1200, noise: 3, seed: 3)
        let padded = TryOnInputs.pad3x4(photo)
        let changedInModel = CGRect(x: 250, y: 300, width: 200, height: 260)
        let ctx = CGContext(data: nil, width: 768, height: 1024, bitsPerComponent: 8, bytesPerRow: 0, space: srgb,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.draw(padded.image, in: CGRect(x: 0, y: 0, width: 768, height: 1024))
        ctx.setFillColor(red: 0.1, green: 0.2, blue: 0.8, alpha: 1)
        ctx.fill(CGRect(x: changedInModel.minX, y: 1024 - changedInModel.maxY,
                        width: changedInModel.width, height: changedInModel.height))
        let result = TryOnInputs.unpad(ctx.makeImage()!, content: padded.content, to: CGSize(width: 600, height: 1200))

        let mask = GarmentMask.make(original: photo, result: result)
        let scale = 600 / padded.content.width
        let expected = CGRect(x: (changedInModel.minX - padded.content.minX) * scale,
                              y: (changedInModel.minY - padded.content.minY) * scale,
                              width: changedInModel.width * scale, height: changedInModel.height * scale)
        let found = whiteBounds(mask)
        XCTAssertEqual(found.minX, expected.minX, accuracy: 2)
        XCTAssertEqual(found.minY, expected.minY, accuracy: 2)
        XCTAssertEqual(found.maxX, expected.maxX, accuracy: 2)
        XCTAssertEqual(found.maxY, expected.maxY, accuracy: 2)
    }

    func testMaskLimitedToRows() {
        // Cambiato tutto il centro, ma la maschera resta tra le righe chieste (collo → ginocchia)
        let original = image(width: 400, height: 800, seed: 4)
        let result = image(width: 400, height: 800, rect: CGRect(x: 100, y: 50, width: 200, height: 700), seed: 5)
        let mask = GarmentMask.make(original: original, result: result, rows: 200...600)
        let found = whiteBounds(mask)
        XCTAssertEqual(found.minY, 200, accuracy: 2)
        XCTAssertEqual(found.maxY, 600, accuracy: 2)
        XCTAssertEqual(found.minX, 100, accuracy: 2)
    }
}
