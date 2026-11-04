import CoreGraphics
import XCTest
@testable import StyleVault

final class GarmentLayoutTests: XCTestCase {
    // Persona sintetica: spalle a y=300 larghe 200 px, fianchi y=600, caviglie y=1100
    private let pose = Pose(points: [
        .neck: CGPoint(x: 300, y: 260),
        .leftShoulder: CGPoint(x: 200, y: 300), .rightShoulder: CGPoint(x: 400, y: 300),
        .leftHip: CGPoint(x: 240, y: 600), .rightHip: CGPoint(x: 360, y: 600),
        .leftAnkle: CGPoint(x: 260, y: 1100), .rightAnkle: CGPoint(x: 340, y: 1100),
    ])
    private let body = CGRect(x: 180, y: 200, width: 240, height: 940)

    private func frame(_ slot: String, aspect: CGFloat = 0.75, view: BodyView = .front) -> CGRect? {
        GarmentLayout.frame(for: slot, pose: pose, bodyBounds: body, garmentAspect: aspect, view: view)
    }

    func testTopTraColloEFianchi() throws {
        let top = try XCTUnwrap(frame("top"))
        XCTAssertGreaterThanOrEqual(top.width, 240)
        XCTAssertLessThanOrEqual(top.width, 280)
        XCTAssertGreaterThanOrEqual(top.minY, 240, "non sale sopra il collo")
        XCTAssertLessThanOrEqual(top.minY, 300, "copre le spalle")
        XCTAssertGreaterThanOrEqual(top.maxY, 600, "arriva almeno ai fianchi")
        XCTAssertEqual(top.midX, 300, accuracy: 5)
    }

    func testPantaloniDaiFianchiAlleCaviglie() throws {
        let bottom = try XCTUnwrap(frame("bottom", aspect: 0.45))
        XCTAssertEqual(bottom.minY, 600, accuracy: 30)
        XCTAssertEqual(bottom.maxY, 1100, accuracy: 55)
        XCTAssertEqual(bottom.midX, 300, accuracy: 5)
    }

    func testScarpeAlleCaviglie() throws {
        let shoes = try XCTUnwrap(frame("shoes", aspect: 1.6))
        XCTAssertEqual(shoes.midX, 300, accuracy: 10)
        XCTAssertTrue(shoes.minY <= 1100 && shoes.maxY >= 1100, "contiene l'altezza delle caviglie")
    }

    func testCapospallaPiuLargoDelTop() throws {
        let top = try XCTUnwrap(frame("top"))
        let coat = try XCTUnwrap(frame("outerwear"))
        XCTAssertGreaterThan(coat.width, top.width)
        XCTAssertGreaterThan(coat.maxY, top.maxY)
    }

    // Review I8: di lato o di spalle Vision può non vedere spalle e fianchi:
    // il capo si posiziona sulla sagoma invece di sparire in silenzio
    func testSenzaSpalleEFianchiSiUsaLaSagoma() throws {
        let partial = Pose(points: [.leftAnkle: CGPoint(x: 280, y: 1100)])
        let top = try XCTUnwrap(GarmentLayout.frame(for: "top", pose: partial, bodyBounds: body,
                                                    garmentAspect: 0.75, view: .side))
        XCTAssertTrue(body.insetBy(dx: -60, dy: 0).contains(top))
        XCTAssertLessThan(top.minY, body.midY)
    }

    func testSlotSconosciuto() {
        XCTAssertNil(frame("accessories"))
    }

    func testDiLatoLaLarghezzaVieneDallaSagoma() throws {
        // Di lato le spalle quasi si sovrappongono: conta la sagoma (240 px)
        var points = pose.points
        points[.leftShoulder] = CGPoint(x: 295, y: 300)
        points[.rightShoulder] = CGPoint(x: 305, y: 300)
        let side = Pose(points: points)
        let top = try XCTUnwrap(GarmentLayout.frame(for: "top", pose: side, bodyBounds: body,
                                                    garmentAspect: 0.75, view: .side))
        XCTAssertGreaterThanOrEqual(top.width, 0.9 * 240)
        XCTAssertLessThanOrEqual(top.width, 1.3 * 240)
    }

    // Zona dove il realistico si ridisegna sopra i pantaloni: dal collo alle ginocchia
    func testRigheRealisticoDalColloAlleGinocchia() {
        let withKnees = Pose(points: pose.points.merging([.leftKnee: CGPoint(x: 250, y: 840),
                                                          .rightKnee: CGPoint(x: 350, y: 860)]) { a, _ in a })
        let rows = GarmentLayout.overlayRows(pose: withKnees, bodyBounds: body)
        XCTAssertEqual(rows.lowerBound, 264, accuracy: 1, "collo: spalle − 12% del busto")
        XCTAssertEqual(rows.upperBound, 850, accuracy: 1, "ginocchia: media dei due punti")
        XCTAssertGreaterThan(rows.lowerBound, 260, "il viso (sopra il collo) resta fuori")
        XCTAssertLessThan(rows.upperBound, 1100, "i piedi restano fuori")
    }

    func testRigheRealisticoSenzaPosaUsanoLeProporzioni() {
        // Senza punti: spalle al 18%, fianchi al 50%, caviglie in fondo; ginocchia a metà fianchi-caviglie
        let rows = GarmentLayout.overlayRows(pose: Pose(points: [:]), bodyBounds: body)
        let shoulder = 200 + 0.18 * 940, hip = 200 + 0.5 * 940
        XCTAssertEqual(rows.lowerBound, shoulder - 0.12 * (hip - shoulder), accuracy: 1)
        let ankle = 200 + 940 - 0.03 * 940
        XCTAssertEqual(rows.upperBound, hip + 0.5 * (ankle - hip), accuracy: 1)
    }
}

final class AvatarModelTests: XCTestCase {
    private func item(back: String?) -> AvatarItem {
        AvatarItem(id: "1", category: "tops", slot: "top", photo: "https://x/front.jpg",
                   name: "Maglione", photoBack: back)
    }

    // Review Focus 3: senza retro la vista di spalle usa il davanti
    func testDiSpalleSenzaRetroUsaIlDavanti() {
        XCTAssertEqual(AvatarModel.garmentImageURL(item(back: nil), view: .back)?.absoluteString,
                       "https://x/front.jpg")
    }

    func testDiSpalleConRetro() {
        XCTAssertEqual(AvatarModel.garmentImageURL(item(back: "https://x/back.jpg"), view: .back)?.absoluteString,
                       "https://x/back.jpg")
        XCTAssertEqual(AvatarModel.garmentImageURL(item(back: "https://x/back.jpg"), view: .front)?.absoluteString,
                       "https://x/front.jpg")
    }

    func testFotoNonValida() {
        let broken = AvatarItem(id: "1", category: "tops", slot: "top", photo: "", name: "x", photoBack: nil)
        XCTAssertNil(AvatarModel.garmentImageURL(broken, view: .front))
    }
}

/// Sagome sintetiche: rettangoli pieni su una maschera alfa.
private func silhouette(width: Int, height: Int, blocks: [CGRect]) -> Silhouette {
    var alpha = [UInt8](repeating: 0, count: width * height)
    for block in blocks {
        for y in Int(block.minY)..<Int(block.maxY) {
            for x in Int(block.minX)..<Int(block.maxX) { alpha[y * width + x] = 255 }
        }
    }
    return Silhouette(width: width, height: height, alpha: alpha)
}

final class SilhouetteTests: XCTestCase {
    func testTrattoPienoDellaRiga() throws {
        let s = silhouette(width: 100, height: 10, blocks: [CGRect(x: 20, y: 0, width: 30, height: 10),
                                                             CGRect(x: 70, y: 0, width: 10, height: 10)])
        let run = try XCTUnwrap(s.run(row: 5, near: 30, mergingGaps: 0))
        XCTAssertEqual(run.lowerBound, 20)
        XCTAssertEqual(run.upperBound, 49)
        // Un braccio staccato di poco dal busto fa parte della sagoma da coprire
        let merged = try XCTUnwrap(s.run(row: 5, near: 30, mergingGaps: 25))
        XCTAssertEqual(merged.upperBound, 79)
    }

    func testPuntaDellaScarpa() {
        // Tallone alto a destra, punta bassa a sinistra
        let shoe = silhouette(width: 200, height: 100, blocks: [CGRect(x: 0, y: 60, width: 200, height: 40),
                                                                 CGRect(x: 120, y: 10, width: 80, height: 50)])
        XCTAssertTrue(shoe.toeOnLeft)
    }
}

final class ShoeAndSilhouetteLayoutTests: XCTestCase {
    // Persona alta 1000 px, caviglie distanti 120 px
    private let pose = Pose(points: [
        .nose: CGPoint(x: 300, y: 150), .neck: CGPoint(x: 300, y: 260),
        .leftShoulder: CGPoint(x: 360, y: 300), .rightShoulder: CGPoint(x: 240, y: 300),
        .leftHip: CGPoint(x: 340, y: 600), .rightHip: CGPoint(x: 260, y: 600),
        .leftAnkle: CGPoint(x: 360, y: 1050), .rightAnkle: CGPoint(x: 240, y: 1050),
    ])
    private let body = CGRect(x: 100, y: 100, width: 400, height: 1000)
    private let singleShoe = silhouette(width: 200, height: 100, blocks: [CGRect(x: 0, y: 60, width: 200, height: 40),
                                                                          CGRect(x: 120, y: 10, width: 80, height: 50)])

    func testUnaScarpaSolaVaSuOgniPiede() {
        let shoes = GarmentLayout.shoeFrames(pose: pose, bodyBounds: body, shoe: singleShoe, pair: false,
                                             view: .front, silhouette: nil)
        XCTAssertEqual(shoes.count, 2)
        let left = shoes.min { $0.frame.midX < $1.frame.midX }!
        let right = shoes.max { $0.frame.midX < $1.frame.midX }!
        // Ognuna lunga quanto un piede (~15% dell'altezza), non quanto i due piedi insieme
        XCTAssertLessThan(left.frame.width, 0.2 * body.height)
        XCTAssertLessThan(left.frame.midX, 300)
        XCTAssertGreaterThan(right.frame.midX, 300)
        // Punte verso fuori: la scarpa ha la punta a sinistra, quella di destra va specchiata
        XCTAssertFalse(left.mirrored)
        XCTAssertTrue(right.mirrored)
        XCTAssertEqual(left.frame.maxY, body.maxY, accuracy: 10, "poggia a terra")
    }

    func testDiLatoLePuntaVersoDoveGuarda() {
        var points = pose.points
        points[.nose] = CGPoint(x: 340, y: 150) // guarda a destra
        let shoes = GarmentLayout.shoeFrames(pose: Pose(points: points), bodyBounds: body, shoe: singleShoe,
                                             pair: false, view: .side, silhouette: nil)
        XCTAssertEqual(shoes.count, 2)
        XCTAssertTrue(shoes.allSatisfy(\.mirrored), "punta a sinistra nella foto → specchiata per guardare a destra")
    }

    func testUnPaioRestaUnaSolaImmagine() {
        let shoes = GarmentLayout.shoeFrames(pose: pose, bodyBounds: body, shoe: singleShoe, pair: true,
                                             view: .front, silhouette: nil)
        XCTAssertEqual(shoes.count, 1)
        XCTAssertEqual(shoes[0].frame.midX, 300, accuracy: 10)
    }

    func testIlTopSiMisuraSulPettoNonSulPasso() throws {
        // Di lato: il passo allarga il riquadro a 400 px, ma il busto è largo 160
        let s = silhouette(width: 600, height: 1200, blocks: [
            CGRect(x: 220, y: 100, width: 160, height: 550), // testa e busto
            CGRect(x: 100, y: 650, width: 400, height: 450), // gambe divaricate
        ])
        let top = try XCTUnwrap(GarmentLayout.frame(for: "top", pose: pose, bodyBounds: body, garmentAspect: 0.75,
                                                    view: .side, silhouette: s))
        XCTAssertEqual(top.midX, 300, accuracy: 5)
        XCTAssertGreaterThanOrEqual(top.width, 160)
        XCTAssertLessThanOrEqual(top.width, 200)
    }

    func testGambeDivaricateDentroIPantaloni() throws {
        // Caviglie a 260 px l'una dall'altra: i jeans (gambe unite) devono coprirle
        var points = pose.points
        points[.leftAnkle] = CGPoint(x: 430, y: 1050)
        points[.rightAnkle] = CGPoint(x: 170, y: 1050)
        let bottom = try XCTUnwrap(GarmentLayout.frame(for: "bottom", pose: Pose(points: points), bodyBounds: body,
                                                       garmentAspect: 0.45, view: .front))
        XCTAssertLessThan(bottom.minX, 170 - 20)
        XCTAssertGreaterThan(bottom.maxX, 430 + 20)
    }

    func testPantaloniMaiGiganti() throws {
        // Una falcata enorme non deve allargare i jeans oltre il corpo
        var points = pose.points
        points[.leftAnkle] = CGPoint(x: 900, y: 1050)
        points[.rightAnkle] = CGPoint(x: 0, y: 1050)
        let bottom = try XCTUnwrap(GarmentLayout.frame(for: "bottom", pose: Pose(points: points), bodyBounds: body,
                                                       garmentAspect: 0.45, view: .back))
        XCTAssertLessThanOrEqual(bottom.width, 0.35 * body.height)
    }

    func testLaVitaDeiPantaloniSopraLeAnche() throws {
        // Il giunto dell'anca di Vision è sotto la cintura: la vita sale, così
        // non resta scoperta la maglia tra top e pantaloni
        let bottom = try XCTUnwrap(GarmentLayout.frame(for: "bottom", pose: pose, bodyBounds: body,
                                                       garmentAspect: 0.45, view: .front))
        XCTAssertLessThanOrEqual(bottom.minY, 600 - 0.08 * 300)
    }

    func testIPantaloniDiLatoSiMisuranoSuiFianchi() throws {
        let s = silhouette(width: 600, height: 1200, blocks: [
            CGRect(x: 220, y: 100, width: 160, height: 650),
            CGRect(x: 100, y: 750, width: 400, height: 350),
        ])
        let bottom = try XCTUnwrap(GarmentLayout.frame(for: "bottom", pose: pose, bodyBounds: body,
                                                       garmentAspect: 0.45, view: .side, silhouette: s))
        XCTAssertLessThanOrEqual(bottom.width, 1.5 * 160)
    }
}
