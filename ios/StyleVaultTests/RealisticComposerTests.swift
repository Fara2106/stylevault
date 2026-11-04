import CoreGraphics
import ImageIO
import XCTest

// Gira nel target macOS StyleVaultVisionTests (scontorno e posa con Vision):
// il risultato realistico finto è la foto di prova col busto ricolorato.
final class RealisticComposerTests: XCTestCase {
    private var folder: URL!

    override func setUp() {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("composer-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: folder)
    }

    private func fixture(_ name: String) throws -> CGImage {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "jpg"))
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        return try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
    }

    /// Colore del pixel (origine in alto a sinistra).
    private func pixel(_ image: CGImage, _ x: CGFloat, _ y: CGFloat) -> (r: Int, g: Int, b: Int) {
        var px = [UInt8](repeating: 0, count: 4)
        let ctx = CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(image, in: CGRect(x: -x.rounded(.down), y: -(CGFloat(image.height) - 1 - y.rounded(.down)),
                                   width: CGFloat(image.width), height: CGFloat(image.height)))
        return (Int(px[0]), Int(px[1]), Int(px[2]))
    }

    private func isGreen(_ p: (r: Int, g: Int, b: Int)) -> Bool { p.g > p.r + 60 && p.g > p.b + 60 }

    func testPantaloniSottoLOrloEBustoSopraLaVita() async throws {
        let original = try fixture("persona")
        let detected = try await BodyPose.detect(original)
        let pose = try XCTUnwrap(detected)
        let p = pose.points
        let ls = try XCTUnwrap(p[.leftShoulder]), rs = try XCTUnwrap(p[.rightShoulder])
        let lh = try XCTUnwrap(p[.leftHip]), rh = try XCTUnwrap(p[.rightHip])
        let shoulderY = (ls.y + rs.y) / 2, hipY = (lh.y + rh.y) / 2, hipX = (lh.x + rh.x) / 2
        let torso = hipY - shoulderY
        let half = 0.35 * abs(rs.x - ls.x)
        // "Maglione nuovo": rettangolo verde dalle spalle a poco sotto i fianchi
        let hem = hipY + 0.1 * torso
        let sweater = CGRect(x: hipX - half, y: shoulderY + 0.05 * torso, width: 2 * half, height: hem - shoulderY - 0.05 * torso)
        let ctx = CGContext(data: nil, width: original.width, height: original.height, bitsPerComponent: 8,
                            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let H = CGFloat(original.height)
        ctx.draw(original, in: CGRect(x: 0, y: 0, width: original.width, height: original.height))
        ctx.setFillColor(CGColor(red: 0.1, green: 0.75, blue: 0.2, alpha: 1))
        ctx.fill(CGRect(x: sweater.minX, y: H - sweater.maxY, width: sweater.width, height: sweater.height))
        let realistic = try XCTUnwrap(ctx.makeImage())

        var garments = [AvatarComposer.Garment]()
        for (slot, name) in [("top", "maglione"), ("bottom", "jeans"), ("shoes", "sneakers")] {
            let cutout = try await PersonCutout.cutout(try fixture(name), allInstances: true)
            garments.append(.init(slot: slot, cutout: cutout))
        }
        XCTAssertEqual(RealisticComposer.collageGarments(garments).map(\.slot), ["bottom", "shoes"],
                       "top e capospalla non si disegnano più col collage")

        let cache = CutoutCache(folder: folder)
        let composed = try await RealisticComposer.compose(original: original, realistic: realistic, garments: garments,
                                                           view: .front, key: "realistic-test", cache: cache)
        let image = try XCTUnwrap(composed)
        XCTAssertEqual(image.width, original.width)
        XCTAssertEqual(image.height, original.height)

        // Lo stesso collage senza ridisegno: dove i pantaloni coprono il busto
        let person = try await cache.cutout(image: realistic, key: "realistic-test", allInstances: false)
        let personPose = try await BodyPose.detect(person.image) ?? pose
        let plain = try XCTUnwrap(AvatarComposer.render(person: person, pose: personPose,
                                                        garments: RealisticComposer.collageGarments(garments),
                                                        view: .front))

        // Sulla vita: senza ridisegno i jeans coprono il verde, col ridisegno il maglione sta sopra
        let waist = CGPoint(x: hipX, y: hipY)
        XCTAssertFalse(isGreen(pixel(plain, waist.x, waist.y)), "i jeans del collage arrivano sopra l'anca")
        XCTAssertTrue(isGreen(pixel(image, waist.x, waist.y)), "il busto realistico sta sopra l'orlo dei jeans")

        // Sotto l'orlo restano i jeans, identici al collage
        let thigh = CGPoint(x: hipX, y: hem + 0.4 * torso)
        let a = pixel(image, thigh.x, thigh.y), b = pixel(plain, thigh.x, thigh.y)
        XCTAssertFalse(isGreen(a))
        XCTAssertEqual(a.r, b.r, accuracy: 3); XCTAssertEqual(a.g, b.g, accuracy: 3); XCTAssertEqual(a.b, b.b, accuracy: 3)

        if let dir = ProcessInfo.processInfo.environment["SV_DUMP"] {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("avatar-realistico.png")
            let dest = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(dest, image, nil)
            CGImageDestinationFinalize(dest)
        }
    }
}
