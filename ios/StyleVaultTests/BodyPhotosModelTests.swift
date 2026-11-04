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
        XCTAssertEqual(BodyPhotosModel.validate(cutout(instances: 0), pose: fullBody, view: .front, people: 1), .noPerson)
        XCTAssertEqual(BodyPhotosModel.validate(cutout(instances: 1), pose: fullBody, view: .front, people: 0), .noPerson)
        XCTAssertEqual(BodyPhotosModel.validate(cutout(instances: 2), pose: fullBody, view: .front, people: 2), .multiplePeople)
    }

    // Review I5: una borsa o una sedia in primo piano sono "soggetti", non persone
    func testUnOggettoInPiuNonEUnaSecondaPersona() {
        XCTAssertEqual(BodyPhotosModel.validate(cutout(instances: 2), pose: fullBody, view: .front, people: 1), .ok)
    }

    func testDavantiSenzaCavigliaNonEFiguraIntera() {
        var points = fullBody.points
        points[.leftAnkle] = nil
        points[.rightAnkle] = nil
        XCTAssertEqual(BodyPhotosModel.validate(cutout(instances: 1), pose: Pose(points: points), view: .front, people: 1),
                       .notFullBody)
        XCTAssertEqual(BodyPhotosModel.validate(cutout(instances: 1), pose: nil, view: .front, people: 1), .notFullBody)
    }

    func testDiSpalleIlVisoNonServe() {
        var points = fullBody.points
        points[.nose] = nil
        XCTAssertEqual(BodyPhotosModel.validate(cutout(instances: 1), pose: Pose(points: points), view: .back, people: 1), .ok)
        XCTAssertEqual(BodyPhotosModel.validate(cutout(instances: 1), pose: fullBody, view: .front, people: 1), .ok)
    }

    // Prova sull'iPhone (2026-11-03): foto di spalle salvata come "lato" e
    // foto davanti come "spalle". Di lato le spalle si sovrappongono; davanti
    // Vision mette la spalla sinistra a destra nell'immagine, di spalle a sinistra.
    private func pose(leftShoulderX: CGFloat, rightShoulderX: CGFloat) -> Pose {
        Pose(points: [
            .nose: CGPoint(x: 50, y: 20),
            .leftShoulder: CGPoint(x: leftShoulderX, y: 100), .rightShoulder: CGPoint(x: rightShoulderX, y: 100),
            .leftHip: CGPoint(x: 50, y: 400), .rightHip: CGPoint(x: 60, y: 400),
            .leftAnkle: CGPoint(x: 45, y: 900), .rightAnkle: CGPoint(x: 55, y: 900),
        ])
    }

    func testFotoDellaVistaSbagliata() {
        let front = pose(leftShoulderX: 150, rightShoulderX: -40)
        let back = pose(leftShoulderX: -40, rightShoulderX: 150)
        let side = pose(leftShoulderX: 60, rightShoulderX: 40)
        func check(_ p: Pose, _ view: BodyView) -> PhotoCheck {
            BodyPhotosModel.validate(cutout(instances: 1), pose: p, view: view, people: 1)
        }
        XCTAssertEqual(check(front, .front), .ok)
        XCTAssertEqual(check(side, .side), .ok)
        XCTAssertEqual(check(back, .back), .ok)
        XCTAssertEqual(check(back, .side), .wrongView(seen: .back, wanted: .side))
        XCTAssertEqual(check(front, .back), .wrongView(seen: .front, wanted: .back))
        XCTAssertEqual(check(side, .back), .wrongView(seen: .side, wanted: .back))
        XCTAssertEqual(check(back, .front), .wrongView(seen: .back, wanted: .front))
        XCTAssertEqual(PhotoCheck.wrongView(seen: .side, wanted: .back).message,
                       "Questa foto sembra fatta di lato, ma qui serve quella di spalle.")
    }

    func testChiHaGiaLaFotoDavantiScattaSoloLatoESpalle() {
        let url = URL(string: "https://x/front.jpg")!
        XCTAssertEqual(BodyPhotosModel.needsOnboarding(existing: [.front: url]), [.side, .back])
        XCTAssertEqual(BodyPhotosModel.needsOnboarding(existing: [:]), [.front, .side, .back])
        XCTAssertEqual(BodyPhotosModel.needsOnboarding(existing: [.front: url, .side: url, .back: url]), [])
    }

    func testIlSitoChiedeDiRifareLeFoto() {
        // Senza vista (sito vecchio o pulsante generale): tutte e tre
        XCTAssertEqual(BridgeMessage.parse(["type": "openBodyPhotos"]), .openBodyPhotos(nil))
        XCTAssertEqual(BridgeMessage.parse(["type": "openBodyPhotos", "payload": ["view": "boh"]]),
                       .openBodyPhotos(nil))
    }

    func testIlSitoChiedeDiRifareUnaFotoSola() {
        XCTAssertEqual(BridgeMessage.parse(["type": "openBodyPhotos", "payload": ["view": "side"]]),
                       .openBodyPhotos(.side))
        XCTAssertEqual(BridgeMessage.parse(["type": "openBodyPhotos", "payload": ["view": "front"]]),
                       .openBodyPhotos(.front))
    }

    func testDopoLeFotoIlSitoRicaricaIlProfilo() {
        XCTAssertEqual(WebViewStore.bodyPhotosChangedScript,
                       "window.svNative && window.svNative.bodyPhotosChanged && window.svNative.bodyPhotosChanged({})")
    }
}
