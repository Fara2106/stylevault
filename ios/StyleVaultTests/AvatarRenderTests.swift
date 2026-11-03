import CoreGraphics
import ImageIO
import XCTest

// Gira nel target macOS (serve Vision): compone l'avatar vero con la persona
// e i capi di prova e, con SV_DUMP, salva il PNG per guardarlo.
final class AvatarRenderTests: XCTestCase {
    private func fixture(_ name: String) throws -> CGImage {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "jpg"))
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        return try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
    }

    func testAvatarDavantiConTreCapi() async throws {
        let photo = try fixture("persona")
        let person = try await PersonCutout.cutout(photo)
        let detected = try await BodyPose.detect(photo)
        let pose = try XCTUnwrap(detected)
        print("MISURE bounds=\(person.bounds) punti=\(pose.points.map { "\($0.key):\(Int($0.value.x)),\(Int($0.value.y))" }.sorted())")
        var garments = [AvatarComposer.Garment]()
        for (slot, name) in [("top", "maglione"), ("bottom", "jeans"), ("shoes", "sneakers")] {
            let cutout = try await PersonCutout.cutout(try fixture(name), allInstances: true)
            garments.append(.init(slot: slot, cutout: cutout))
        }
        let start = Date()
        let image = try XCTUnwrap(AvatarComposer.render(person: person, pose: pose, garments: garments, view: .front))
        print("composizione avatar: \(Date().timeIntervalSince(start)) s")
        XCTAssertEqual(image.width, photo.width)
        XCTAssertEqual(image.height, photo.height)

        if let dir = ProcessInfo.processInfo.environment["SV_DUMP"] {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("avatar-davanti.png")
            let dest = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(dest, image, nil)
            CGImageDestinationFinalize(dest)
        }
    }
}
