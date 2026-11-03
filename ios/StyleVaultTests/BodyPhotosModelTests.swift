import CoreGraphics
import XCTest
@testable import StyleVault

final class BodyPhotosModelTests: XCTestCase {
    private let blank: CGImage = {
        let ctx = CGContext(data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return ctx.makeImage()!
    }()

    private func cutout(instances: Int) -> Cutout {
        Cutout(image: blank, bounds: CGRect(x: 0, y: 0, width: 2, height: 4), instanceCount: instances)
    }

    private let fullBody = Pose(points: [
        .nose: CGPoint(x: 50, y: 20), .leftShoulder: CGPoint(x: 40, y: 50),
        .rightShoulder: CGPoint(x: 60, y: 50), .leftAnkle: CGPoint(x: 45, y: 190),
        .rightAnkle: CGPoint(x: 55, y: 190),
    ])

    // Review Focus 1: mai salvare una foto senza persona o con più persone
    func testNessunaPersonaOPiuPersone() {
        XCTAssertEqual(BodyPhotosModel.validate(cutout(instances: 0), pose: fullBody, view: .front), .noPerson)
        XCTAssertEqual(BodyPhotosModel.validate(cutout(instances: 2), pose: fullBody, view: .front), .multiplePeople)
    }

    func testDavantiSenzaCavigliaNonEFiguraIntera() {
        var points = fullBody.points
        points[.leftAnkle] = nil
        points[.rightAnkle] = nil
        XCTAssertEqual(BodyPhotosModel.validate(cutout(instances: 1), pose: Pose(points: points), view: .front),
                       .notFullBody)
        XCTAssertEqual(BodyPhotosModel.validate(cutout(instances: 1), pose: nil, view: .front), .notFullBody)
    }

    func testDiSpalleIlVisoNonServe() {
        var points = fullBody.points
        points[.nose] = nil
        XCTAssertEqual(BodyPhotosModel.validate(cutout(instances: 1), pose: Pose(points: points), view: .back), .ok)
        XCTAssertEqual(BodyPhotosModel.validate(cutout(instances: 1), pose: fullBody, view: .front), .ok)
    }

    func testChiHaGiaLaFotoDavantiScattaSoloLatoESpalle() {
        let url = URL(string: "https://x/front.jpg")!
        XCTAssertEqual(BodyPhotosModel.needsOnboarding(existing: [.front: url]), [.side, .back])
        XCTAssertEqual(BodyPhotosModel.needsOnboarding(existing: [:]), [.front, .side, .back])
        XCTAssertEqual(BodyPhotosModel.needsOnboarding(existing: [.front: url, .side: url, .back: url]), [])
    }

    func testIlSitoChiedeDiRifareLeFoto() {
        XCTAssertEqual(BridgeMessage.parse(["type": "openBodyPhotos"]), .openBodyPhotos)
    }
}
