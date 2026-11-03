import CoreGraphics
import ImageIO
import XCTest
#if os(iOS)
@testable import StyleVault
#endif

// Vision non ha i modelli nel simulatore iOS: questi test girano nel
// target macOS StyleVaultVisionTests, che compila gli stessi file Vision.

final class VisionTests: XCTestCase {
    private func fixture(_ name: String) throws -> CGImage {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "jpg"))
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        return try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
    }

    private func solidImage(width: Int, height: Int) -> CGImage {
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.8, green: 0.75, blue: 0.7, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()!
    }

    // Review Focus 2: le foto da 48 MP vanno ridotte prima di Vision e upload
    func testRiduzioneA2048MantieneLeProporzioni() {
        let big = solidImage(width: 8000, height: 6000)
        let small = ImagePrep.downscaled(big)
        XCTAssertEqual(small.width, 2048)
        XCTAssertEqual(small.height, 1536)
        let tiny = solidImage(width: 300, height: 400)
        XCTAssertEqual(ImagePrep.downscaled(tiny).width, 300, "le immagini piccole restano com'erano")
    }

    // Review I6: le foto da 48 MP si decodificano già ridotte e dritte
    func testDecodificaRidottaDaJPEG() throws {
        let big = solidImage(width: 6000, height: 4000)
        let data = NSMutableData()
        let dest = try XCTUnwrap(CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil))
        CGImageDestinationAddImage(dest, big, nil)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
        let decoded = try XCTUnwrap(ImagePrep.decodedForAnalysis(data as Data))
        XCTAssertEqual(max(decoded.width, decoded.height), 2048)
    }

    // Review I5: conta le persone, non gli oggetti in primo piano
    func testUnaSolaPersonaNellaFotoDiProva() async throws {
        let people = try await PersonCutout.peopleCount(try fixture("persona"))
        XCTAssertEqual(people, 1)
    }

    func testScontornoDellaPersona() async throws {
        let start = Date()
        let cutout = try await PersonCutout.cutout(try fixture("persona"))
        print("scontorno persona: \(Date().timeIntervalSince(start)) s")
        dump(cutout.image, "persona-scontornata")
        XCTAssertGreaterThanOrEqual(cutout.instanceCount, 1)
        let transparent = PersonCutout.transparentFraction(cutout.image)
        // Nella foto di prova la ragazza occupa ~9% del fotogramma (verificato
        // a occhio sul PNG): trasparente ~91%. Vuoto (100%) o niente tolto (<40%) = errore.
        XCTAssertGreaterThan(transparent, 0.4)
        XCTAssertLessThan(transparent, 0.97)
        let frame = CGRect(x: 0, y: 0, width: cutout.image.width, height: cutout.image.height)
        XCTAssertTrue(frame.contains(cutout.bounds))
        XCTAssertGreaterThan(cutout.bounds.height, cutout.bounds.width, "una persona in piedi è più alta che larga")
    }

    func testTintaUnitaSenzaSoggetto() async {
        do {
            _ = try await PersonCutout.cutout(solidImage(width: 600, height: 800))
            XCTFail("doveva lanciare noSubject")
        } catch {
            XCTAssertEqual(error as? CutoutError, .noSubject)
        }
    }

    func testScontornoDelCapoSuFondoChiaro() async throws {
        let cutout = try await PersonCutout.cutout(try fixture("maglione"), allInstances: true)
        XCTAssertGreaterThanOrEqual(cutout.instanceCount, 1)
        XCTAssertLessThan(PersonCutout.transparentFraction(cutout.image), 0.9)
    }

    func testPosaDellaPersona() async throws {
        let pose = try await XCTUnwrapAsync(await BodyPose.detect(try fixture("persona")))
        for joint in [Joint.leftShoulder, .rightShoulder, .leftHip, .rightHip, .leftAnkle, .rightAnkle] {
            XCTAssertNotNil(pose.points[joint], "manca \(joint)")
        }
        XCTAssertGreaterThan(pose.points[.leftAnkle]!.y, pose.points[.leftHip]!.y, "caviglie sotto i fianchi")
        XCTAssertGreaterThan(pose.points[.leftHip]!.y, pose.points[.leftShoulder]!.y, "fianchi sotto le spalle")
    }

    /// Con SV_DUMP=<cartella> (TEST_RUNNER_SV_DUMP da xcodebuild) salva il PNG per guardarlo.
    private func dump(_ image: CGImage, _ name: String) {
        guard let dir = ProcessInfo.processInfo.environment["SV_DUMP"] else { return }
        let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).png")
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }

    private func XCTUnwrapAsync<T>(_ value: T?) async throws -> T { try XCTUnwrap(value) }
}
