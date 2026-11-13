import CoreGraphics
import XCTest
@testable import StyleVaultCore

// Capi fotografati addosso a qualcuno: solo il capo, allineato al corpo. Senza Vision (le parti con Vision sono in VisionTests).
final class WornGarmentTests: XCTestCase {
    // Persona sintetica come in GarmentLayoutTests: spalle a y=300 larghe 200 px, fianchi y=600, caviglie y=1100
    private let pose = Pose(points: [
        .nose: CGPoint(x: 300, y: 200), .neck: CGPoint(x: 300, y: 260),
        .leftShoulder: CGPoint(x: 200, y: 300), .rightShoulder: CGPoint(x: 400, y: 300),
        .leftHip: CGPoint(x: 240, y: 600), .rightHip: CGPoint(x: 360, y: 600),
        .leftKnee: CGPoint(x: 250, y: 850), .rightKnee: CGPoint(x: 350, y: 850),
        .leftAnkle: CGPoint(x: 260, y: 1100), .rightAnkle: CGPoint(x: 340, y: 1100),
    ])
    private let subject = CGRect(x: 180, y: 120, width: 240, height: 1020)
    private let chest = CGPoint(x: 300, y: 435)

    func testMagliaDalColletto() throws {
        let r = try XCTUnwrap(WornGarment.regions(slot: "top", pose: pose, subject: subject))
        XCTAssertEqual(r.rows.lowerBound, 264, accuracy: 1, "poco sopra le spalle: più su c'è il collo")
        XCTAssertGreaterThan(r.rows.upperBound, 600, "scende sotto i fianchi")
        XCTAssertLessThan(r.rows.upperBound, 850, "non arriva alle ginocchia")
        XCTAssertTrue(r.seeds.contains { $0.contains(chest) }, "i colori si prendono sul petto")
        XCTAssertNotNil(r.face)
    }

    func testGiaccaApertaPrendeIColoriDalleManiche() throws {
        let r = try XCTUnwrap(WornGarment.regions(slot: "outerwear", pose: pose, subject: subject))
        XCTAssertFalse(r.seeds.contains { $0.contains(chest) }, "sul petto di una giacca aperta c'è la maglia sotto")
        XCTAssertEqual(r.seeds.count, 2)
        XCTAssertTrue(r.seeds.allSatisfy { abs($0.midX - 200) < 30 || abs($0.midX - 400) < 30 })
    }

    func testUnaSpallaNascostaSiRicavaDalCollo() throws {
        let partial = Pose(points: [.neck: CGPoint(x: 300, y: 260), .leftShoulder: CGPoint(x: 200, y: 300)])
        let r = try XCTUnwrap(WornGarment.regions(slot: "top", pose: partial, subject: subject))
        XCTAssertEqual(try XCTUnwrap(r.seeds.first).midX, 300, accuracy: 1)
    }

    func testPantaloniFinoAMetaTraCavigliaEPianta() throws {
        let r = try XCTUnwrap(WornGarment.regions(slot: "bottom", pose: pose, subject: subject))
        XCTAssertEqual(r.rows.upperBound, 1120, accuracy: 1)
        XCTAssertLessThan(r.rows.lowerBound, 600, "la vita sta sopra il giunto dell'anca")
        XCTAssertEqual(r.seeds.count, 2, "una zona per coscia")
    }

    func testSenzaPosaSoloLaFotoTagliataSottoIlMento() {
        let cropped = CGRect(x: 0, y: 0, width: 500, height: 700)
        XCTAssertNotNil(WornGarment.regions(slot: "top", pose: nil, subject: cropped))
        XCTAssertNil(WornGarment.regions(slot: "top", pose: nil, subject: cropped.offsetBy(dx: 0, dy: 40)),
                     "una mano che tiene la gruccia: il capo resta intero")
        XCTAssertNil(WornGarment.regions(slot: "shoes", pose: nil, subject: cropped))
    }

    // MARK: - Ritaglio su una persona disegnata

    /// 200×400: testa color pelle, busto rosso, braccia color pelle, gambe blu, fondo trasparente.
    private func person() -> (CGImage, Pose) {
        let ctx = CGContext(data: nil, width: 200, height: 400, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        // CoreGraphics ha l'origine in basso: y_cg = 400 - y - h
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

    /// Frazione dei pixel visibili del colore dato (canale dominante).
    private func share(_ image: CGImage, channel: Int) -> Double {
        let pixels = RGBAPixels(image)
        var visible = 0, matching = 0
        for i in 0..<(pixels.width * pixels.height) where pixels.alpha(i) >= 200 {
            visible += 1
            let rgb = (0..<3).map { Int(pixels.data[i * 4 + $0]) }
            if rgb.indices.allSatisfy({ $0 == channel || rgb[$0] < rgb[channel] - 60 }) { matching += 1 }
        }
        return Double(matching) / Double(max(visible, 1))
    }

    func testDellaMagliaRestaSoloIlBusto() throws {
        let (image, pose) = person()
        let piece = try XCTUnwrap(WornGarment.extract(image, pose: pose, slot: "top"))
        XCTAssertGreaterThan(share(piece.image, channel: 0), 0.97, "niente testa, braccia o gambe")
        XCTAssertEqual(Double(piece.image.width), 100, accuracy: 4)
        XCTAssertEqual(Double(piece.image.height), 110, accuracy: 6)
        let shoulder = try XCTUnwrap(piece.pose?.points[.leftShoulder])
        XCTAssertEqual(shoulder.x, 10, accuracy: 4, "la posa segue il ritaglio")
    }

    func testDeiPantaloniRestanoSoloLeGambe() throws {
        let (image, pose) = person()
        let piece = try XCTUnwrap(WornGarment.extract(image, pose: pose, slot: "bottom"))
        XCTAssertGreaterThan(share(piece.image, channel: 2), 0.97)
        XCTAssertEqual(Double(piece.image.height), 176, accuracy: 4, "dai fianchi a metà tra caviglia e pianta")
    }

    // MARK: - Allineamento al corpo

    func testSpalleSuSpalleEFianchiSuFianchi() throws {
        // Il capo viene da una foto con la persona più piccola e spostata
        let garment = Pose(points: [
            .leftShoulder: CGPoint(x: 50, y: 40), .rightShoulder: CGPoint(x: 150, y: 40),
            .leftHip: CGPoint(x: 70, y: 190), .rightHip: CGPoint(x: 130, y: 190),
        ])
        let t = try XCTUnwrap(GarmentLayout.wornTransform(slot: "top", garment: garment, body: pose, view: .front))
        let shoulders = CGPoint(x: 100, y: 40).applying(t), hips = CGPoint(x: 100, y: 190).applying(t)
        XCTAssertEqual(shoulders.x, 300, accuracy: 0.5)
        XCTAssertEqual(shoulders.y, 300, accuracy: 0.5)
        XCTAssertEqual(hips.x, 300, accuracy: 0.5)
        XCTAssertEqual(hips.y, 600, accuracy: 0.5)
        XCTAssertEqual(CGPoint(x: 150, y: 40).applying(t).x, 400, accuracy: 0.5, "larghezza delle spalle")
    }

    func testPantaloniDaiFianchiAlleCaviglie() throws {
        let garment = Pose(points: [
            .leftHip: CGPoint(x: 40, y: 20), .rightHip: CGPoint(x: 100, y: 20),
            .leftAnkle: CGPoint(x: 45, y: 270), .rightAnkle: CGPoint(x: 95, y: 270),
        ])
        let t = try XCTUnwrap(GarmentLayout.wornTransform(slot: "bottom", garment: garment, body: pose, view: .front))
        XCTAssertEqual(CGPoint(x: 70, y: 20).applying(t).y, 600, accuracy: 0.5)
        XCTAssertEqual(CGPoint(x: 70, y: 270).applying(t).y, 1100, accuracy: 0.5)
        XCTAssertEqual(CGPoint(x: 70, y: 270).applying(t).x, 300, accuracy: 0.5)
    }

    func testFotoDiTreQuartiNonAllargaIlCapo() throws {
        // Spalle strette (persona girata): la larghezza non segue il rapporto delle spalle oltre un terzo dell'altezza
        let garment = Pose(points: [
            .leftShoulder: CGPoint(x: 90, y: 40), .rightShoulder: CGPoint(x: 110, y: 40),
            .leftHip: CGPoint(x: 92, y: 190), .rightHip: CGPoint(x: 108, y: 190),
        ])
        let t = try XCTUnwrap(GarmentLayout.wornTransform(slot: "top", garment: garment, body: pose, view: .front))
        XCTAssertLessThanOrEqual(t.a, 1.33 * t.d + 0.001)
        XCTAssertNil(GarmentLayout.wornTransform(slot: "top", garment: garment, body: pose, view: .side), "di lato vale il riquadro")
        XCTAssertNil(GarmentLayout.wornTransform(slot: "shoes", garment: garment, body: pose, view: .front))
    }

    // MARK: - Maschere e cache

    func testBuchiChiusiMaNonLeRientranze() {
        // 5×5: anello pieno con un buco al centro, e una rientranza aperta sul bordo in basso
        let rows = ["#####",
                    "#.###",
                    "##.##",
                    "#####",
                    "##.##"]
        let mask = rows.joined().map { $0 == "#" }
        let filled = Morphology.fillingHoles(mask, width: 5, height: 5)
        XCTAssertTrue(filled[2 * 5 + 2], "il buco al centro si chiude")
        XCTAssertTrue(filled[1 * 5 + 1], "anche quello chiuso dal resto")
        XCTAssertFalse(filled[4 * 5 + 2], "la rientranza sul bordo resta")
    }

    func testRestaSoloLaParteCollegata() {
        let mask = "##..#".map { $0 == "#" }
        XCTAssertEqual(Morphology.connected(mask, width: 5, height: 1, to: [0]), [true, true, false, false, false])
    }

    func testPosaSalvataERiletta() throws {
        let decoded = try XCTUnwrap(CutoutCache.decodePose(CutoutCache.encodePose(pose)))
        XCTAssertEqual(decoded.points, pose.points)
    }
}
