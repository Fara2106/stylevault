import CoreGraphics
import ImageIO
import XCTest
@testable import StyleVaultCore

// Gira sul Mac (serve Vision): compone l'avatar vero con la persona
// e i capi di prova e, con SV_DUMP, salva il PNG per guardarlo.
final class AvatarRenderTests: XCTestCase {
    private func fixture(_ name: String) throws -> CGImage {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "jpg", subdirectory: "Fixtures"))
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

    private func fixtureData(_ name: String) throws -> Data {
        try Data(contentsOf: XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "jpg", subdirectory: "Fixtures")))
    }

    private func temporaryCache() -> CutoutCache {
        CutoutCache(folder: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    }

    func testFotoDiProvaApprovataPerLaVistaDavanti() async throws {
        let result = try await BodyPhotoAnalyzer.analyze(fixtureData("persona"), view: .front)
        XCTAssertEqual(result.check, .ok)
        XCTAssertNotNil(result.preview)
        let jpeg = try XCTUnwrap(result.jpeg)
        XCTAssertLessThanOrEqual(try XCTUnwrap(ImagePrep.decodedForAnalysis(jpeg)).width, 2048)
    }

    func testFotoDiUnCapoNonEUnaPersona() async throws {
        let result = try await BodyPhotoAnalyzer.analyze(fixtureData("maglione"), view: .front)
        XCTAssertNotEqual(result.check, .ok)
    }

    func testDatiCheNonSonoUnaFoto() async {
        do {
            _ = try await BodyPhotoAnalyzer.analyze(Data([1, 2, 3]), view: .front)
            XCTFail("doveva fallire")
        } catch {
            XCTAssertEqual(error as? BodyPhotoError, .unreadable)
        }
    }

    func testAvatarDaiDatiSalvati() async throws {
        let garments = [AvatarGarment(slot: "top", photo: try fixtureData("maglione"), key: "maglione"),
                        AvatarGarment(slot: "bottom", photo: try fixtureData("jeans"), key: "jeans"),
                        AvatarGarment(slot: "shoes", photo: try fixtureData("sneakers"), key: "sneakers")]
        let result = try await AvatarRenderer.render(body: fixtureData("persona"), bodyKey: "persona", garments: garments,
                                                     view: .front, cache: temporaryCache())
        XCTAssertEqual(result.unavailable, 0)
        let photo = try fixture("persona")
        XCTAssertLessThan(result.image.height, photo.height, "ritagliata attorno alla persona")
        XCTAssertGreaterThan(result.image.height, result.image.width)
    }

    func testCapoSenzaSoggettoVieneContatoENonFermaLAvatar() async throws {
        let blank = try XCTUnwrap(GarmentImage.prepared(solidJPEG()))
        let result = try await AvatarRenderer.render(body: fixtureData("persona"), bodyKey: "persona",
                                                     garments: [AvatarGarment(slot: "top", photo: blank, key: "vuoto")],
                                                     view: .front, cache: temporaryCache())
        XCTAssertEqual(result.unavailable, 1)
    }

    func testLaCacheInMemoriaNonCresceOltreIlLimite() async throws {
        let cache = CutoutCache(folder: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
                                memoryLimit: 1)
        let photo = try fixture("maglione")
        _ = try await cache.cutout(image: photo, key: "item-1", allInstances: true)
        _ = try await cache.cutout(image: photo, key: "item-2", allInstances: true)
        let kept = await cache.keysInMemory
        XCTAssertEqual(kept, ["item-2"], "resta solo l'ultimo")
        // Quello uscito dalla memoria si ritrova su disco.
        _ = try await cache.cutout(image: photo, key: "item-1", allInstances: true)
        let again = await cache.keysInMemory
        XCTAssertEqual(again, ["item-1"])
    }

    func testLaCacheCancellaSoloLeFotoDelCorpo() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cache = CutoutCache(folder: folder)
        let photo = try fixture("maglione")
        _ = try await cache.cutout(image: photo, key: "body-front-1", allInstances: false)
        _ = try await cache.cutout(image: photo, key: "item-1", allInstances: true)
        await cache.removeAll(prefix: "body-")
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        XCTAssertFalse(names.contains { $0.hasPrefix("body-") })
        XCTAssertTrue(names.contains { $0.hasPrefix("item-") })
    }

    func testRestanoSoloGliScontorniDelleFotoDelCorpoCheEsistono() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cache = CutoutCache(folder: folder)
        let photo = try fixture("maglione")
        _ = try await cache.cutout(image: photo, key: "body-front-A-1", allInstances: false)
        _ = try await cache.cutout(image: photo, key: "body-front-A-2", allInstances: false)
        _ = try await cache.cutout(image: photo, key: "item-1", allInstances: true)
        // La foto è stata cambiata su un altro dispositivo: vale solo la chiave nuova
        await cache.keepBodyCutouts(for: ["body-front-A-2"])
        var names = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        XCTAssertFalse(names.contains { $0.hasPrefix("body-front-A-1") })
        XCTAssertTrue(names.contains { $0.hasPrefix("body-front-A-2") })
        XCTAssertTrue(names.contains { $0.hasPrefix("item-") })
        let kept = await cache.keysInMemory
        XCTAssertFalse(kept.contains("body-front-A-1"))
        // Cancellata: non resta nessuno scontorno del corpo
        await cache.keepBodyCutouts(for: [])
        names = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        XCTAssertFalse(names.contains { $0.hasPrefix("body-") })
        XCTAssertTrue(names.contains { $0.hasPrefix("item-") })
    }

    private func solidJPEG() throws -> Data {
        let ctx = try XCTUnwrap(CGContext(data: nil, width: 300, height: 300, bitsPerComponent: 8, bytesPerRow: 0,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.setFillColor(CGColor(red: 0.8, green: 0.75, blue: 0.7, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 300, height: 300))
        let data = NSMutableData()
        let dest = try XCTUnwrap(CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil))
        CGImageDestinationAddImage(dest, try XCTUnwrap(ctx.makeImage()), nil)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
        return data as Data
    }
}
