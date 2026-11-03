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
