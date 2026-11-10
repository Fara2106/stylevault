import CoreGraphics
import XCTest
@testable import StyleVaultCore

/// Il corpo sotto i capi: i vestiti della foto non devono spuntare attorno al capo nuovo.
final class BodyBaseTests: XCTestCase {
    /// 200×400: testa e braccia color pelle, busto rosso, gambe blu, fondo trasparente.
    private func person() -> (CGImage, Pose) {
        let ctx = CGContext(data: nil, width: 200, height: 400, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        func fill(_ r: CGRect, _ c: (CGFloat, CGFloat, CGFloat)) {
            ctx.setFillColor(CGColor(red: c.0, green: c.1, blue: c.2, alpha: 1))
            ctx.fill(CGRect(x: r.minX, y: 400 - r.maxY, width: r.width, height: r.height))
        }
        let skin: (CGFloat, CGFloat, CGFloat) = (0.87, 0.70, 0.58)
        fill(CGRect(x: 75, y: 20, width: 50, height: 70), skin)
        fill(CGRect(x: 50, y: 90, width: 100, height: 110), (CGFloat(0.85), 0.1, 0.1))
        fill(CGRect(x: 30, y: 90, width: 20, height: 110), skin)
        fill(CGRect(x: 150, y: 90, width: 20, height: 110), skin)
        fill(CGRect(x: 55, y: 200, width: 90, height: 180), (CGFloat(0.1), 0.2, 0.7))
        let pose = Pose(points: [
            .nose: CGPoint(x: 100, y: 55), .neck: CGPoint(x: 100, y: 92),
            .leftShoulder: CGPoint(x: 60, y: 100), .rightShoulder: CGPoint(x: 140, y: 100),
            .leftHip: CGPoint(x: 75, y: 200), .rightHip: CGPoint(x: 125, y: 200),
            .leftKnee: CGPoint(x: 78, y: 290), .rightKnee: CGPoint(x: 122, y: 290),
            .leftAnkle: CGPoint(x: 80, y: 370), .rightAnkle: CGPoint(x: 120, y: 370),
        ])
        return (ctx.makeImage()!, pose)
    }

    /// Colore (0-255) e alfa del pixel, origine in alto.
    private func pixel(_ image: CGImage, _ x: Int, _ y: Int) -> (r: Int, g: Int, b: Int, a: Int) {
        let pixels = RGBAPixels(image)
        let i = y * pixels.width + x
        let c = pixels.color(i)
        return (Int(c.0), Int(c.1), Int(c.2), Int(pixels.alpha(i)))
    }

    func testSenzaUnCapoSottoIlCorpoRestaComE() {
        let (image, pose) = person()
        XCTAssertTrue(BodyBase.prepared(image, pose: pose, slots: []) === image)
        XCTAssertTrue(BodyBase.prepared(image, pose: pose, slots: ["top", "outerwear", "shoes", "dress"]) === image,
                      "il sopra della foto non si tocca: resterebbero le mani staccate")
    }

    func testSottoIPantaloniQuelliDellaFotoSpariscono() {
        let (image, pose) = person()
        let base = BodyBase.prepared(image, pose: pose, slots: ["top", "bottom"])
        XCTAssertLessThan(pixel(base, 100, 300).a, 10, "dietro i pantaloni nuovi non resta niente")
        XCTAssertLessThan(pixel(base, 55, 300).a, 10, "nemmeno il filo del bordo")
        let chest = pixel(base, 100, 150)
        XCTAssertEqual(chest.a, 255)
        XCTAssertGreaterThan(chest.r, chest.b + 60, "la maglia della foto resta")
        XCTAssertEqual(pixel(base, 100, 50).a, 255, "il viso resta")
        XCTAssertEqual(pixel(base, 35, 150).a, 255, "le braccia restano")
    }

    /// I pantaloni nuovi partono dalla vita (fianchi meno un decimo del busto): più su quelli della foto restano,
    /// o tra maglia e pantaloni si vedrebbe il fondo.
    func testSopraLaVitaIPantaloniDellaFotoRestano() {
        let (image, pose) = person()
        // Pantaloni a vita alta: il blu sale di 30 pixel sopra i fianchi
        let ctx = CGContext(data: nil, width: 200, height: 400, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: 200, height: 400))
        ctx.setFillColor(CGColor(red: 0.1, green: 0.2, blue: 0.7, alpha: 1))
        ctx.fill(CGRect(x: 55, y: 400 - 200, width: 90, height: 30))
        let base = BodyBase.prepared(ctx.makeImage()!, pose: pose, slots: ["bottom"])
        // Vita a 200 - 0,1 × 100 = 190
        XCTAssertEqual(pixel(base, 100, 180).a, 255, "sopra la vita resta")
        XCTAssertLessThan(pixel(base, 100, 200).a, 10, "sotto sparisce")
    }

    func testGambeNudeRestano() {
        // Gambe color pelle: non c'è un capo sotto da togliere
        let (image, pose) = person()
        let ctx = CGContext(data: nil, width: 200, height: 400, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: 200, height: 400))
        ctx.setFillColor(CGColor(red: 0.87, green: 0.70, blue: 0.58, alpha: 1))
        ctx.fill(CGRect(x: 55, y: 400 - 380, width: 90, height: 180))
        let base = BodyBase.prepared(ctx.makeImage()!, pose: pose, slots: ["bottom"])
        XCTAssertEqual(pixel(base, 100, 300).a, 255)
    }

    // MARK: - Bordo arrotondato

    func testIlBordoADentiDiSegaSiArrotonda() {
        // Un quadrato pieno con denti di un pixel sul lato destro e una tacca su quello sinistro
        let w = 60, h = 60
        var mask = [Bool](repeating: false, count: w * h)
        for y in 10..<50 { for x in 10..<40 { mask[y * w + x] = true } }
        for y in stride(from: 10, to: 50, by: 2) { for x in 40..<46 { mask[y * w + x] = true } }
        for y in 28..<31 { for x in 10..<16 { mask[y * w + x] = false } }
        let smooth = Morphology.smoothed(mask, width: w, height: h, radius: 3)
        for y in 14..<46 {
            XCTAssertFalse(smooth[y * w + 45], "il dente a riga \(y) va via")
            XCTAssertTrue(smooth[y * w + 37], "il pieno resta")
        }
        XCTAssertTrue(smooth[29 * w + 13], "la tacca si riempie")
        XCTAssertFalse(smooth[30 * w + 5], "fuori resta vuoto")
    }

    func testLaMediaContaSoloIPesi() {
        let values: [Double] = [10, 0, 0, 30]
        let out = Morphology.average(values, weights: [true, false, false, true], width: 4, height: 1, radius: 1)
        XCTAssertEqual(out[0], 10)
        XCTAssertEqual(out[1], 10)
        XCTAssertEqual(out[2], 30)
        XCTAssertEqual(out[3], 30)
    }
}
