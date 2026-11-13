import CoreGraphics
import ImageIO
import XCTest
@testable import StyleVaultCore

// Vision non ha i modelli nel simulatore iOS: questi test girano sul Mac con `swift test`.

final class VisionTests: XCTestCase {
    private func fixture(_ name: String) throws -> CGImage {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "jpg", subdirectory: "Fixtures"))
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

    // Foto di Unsplash (licenza Unsplash), ridotte a 1024: per strada un passante piccolo dietro non è una seconda persona,
    // due persone vicine sì.
    func testUnPassantePiccoloSulloSfondoNonConta() async throws {
        let people = try await PersonCutout.peopleCount(try fixture("persona-passante"))
        XCTAssertEqual(people, 1)
    }

    func testDuePersoneVicineContano() async throws {
        let people = try await PersonCutout.peopleCount(try fixture("persona-coppia"))
        XCTAssertEqual(people, 2)
    }

    // Altezze misurate sulle foto di prova del 08/11: passante 0,30 accanto a 0,93; coppia 0,53 accanto a 0,61.
    func testContaSoloLePersoneAlteAlmenoMetaDellaPrincipale() {
        XCTAssertEqual(PersonCutout.countedPeople(heights: []), 0)
        XCTAssertEqual(PersonCutout.countedPeople(heights: [0.4]), 1)
        XCTAssertEqual(PersonCutout.countedPeople(heights: [0.93, 0.30]), 1)
        XCTAssertEqual(PersonCutout.countedPeople(heights: [0.30, 0.93]), 1, "l'ordine non conta")
        XCTAssertEqual(PersonCutout.countedPeople(heights: [0.61, 0.53]), 2)
        XCTAssertEqual(PersonCutout.countedPeople(heights: [0.8, 0.4]), 2, "a metà esatta conta ancora")
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

    // Foto Unsplash ridotta a 1024: occhiali sul tavolo, tazzina e tazza tagliate dal bordo. Prima l'app teneva anche le tazze.
    func testCapoSenzaGliOggettiTagliatiDalBordo() async throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "capo-occhiali-tazza", withExtension: "jpg",
                                                  subdirectory: "Fixtures"))
        let png = await GarmentImage.cutout(try Data(contentsOf: url))
        let data = try XCTUnwrap(png, "gli occhiali sono un soggetto")
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let bounds = PersonCutout.opaqueBounds(image)
        // Gli occhiali stanno a destra (centro a 0,77), la tazzina a sinistra (0,23).
        XCTAssertGreaterThan(bounds.minX, CGFloat(image.width) * 0.5, "la tazzina doveva sparire: \(bounds)")
        XCTAssertGreaterThan(PersonCutout.transparentFraction(image), 0.8)
    }

    // Lati toccati misurati sulle foto di prova del 08/11.
    func testQualiSoggettiTieneUnCapo() {
        typealias Box = PersonCutout.InstanceBox
        // Tazzina (sinistra, sopra, sotto) e occhiali tutti dentro: restano gli occhiali.
        XCTAssertEqual(PersonCutout.keptGarmentLabels([Box(label: 1, pixels: 900, edges: 3),
                                                       Box(label: 2, pixels: 300, edges: 0)]), [2])
        // Un paio di stivali, tutti e due dentro: restano tutti e due.
        XCTAssertEqual(PersonCutout.keptGarmentLabels([Box(label: 1, pixels: 500, edges: 0),
                                                       Box(label: 2, pixels: 400, edges: 0)]), [1, 2])
        // Collana a tre fili, tutti tagliati in alto: nessuno sta tutto dentro, restano tutti.
        XCTAssertEqual(PersonCutout.keptGarmentLabels([Box(label: 1, pixels: 130, edges: 1),
                                                       Box(label: 2, pixels: 50, edges: 1),
                                                       Box(label: 3, pixels: 45, edges: 1)]), [1, 2, 3])
        // Scarpa inquadrata stretta (tocca un lato) accanto all'altra: restano tutte e due.
        XCTAssertEqual(PersonCutout.keptGarmentLabels([Box(label: 1, pixels: 500, edges: 1),
                                                       Box(label: 2, pixels: 450, edges: 0)]), [1, 2])
        // Un solo soggetto che riempie la foto: resta.
        XCTAssertEqual(PersonCutout.keptGarmentLabels([Box(label: 1, pixels: 5000, edges: 3)]), [1])
    }

    // Foto Unsplash ridotte a 768: la maglia da negozio tagliata sotto il mento e i pantaloni di una foto a figura intera.
    // Prima l'avatar riceveva tutta la modella, con pancia, braccia e scarpe.
    func testDallaFotoDaNegozioRestaSoloLaMaglia() async throws {
        let photo = try fixture("capo-indossato-negozio")
        let cutout = try await PersonCutout.cutout(photo, allInstances: true)
        let piece = try await XCTUnwrapAsync(await WornGarment.piece(from: cutout, photo: photo, slot: "top"))
        XCTAssertNil(piece.pose, "senza testa Vision non dà la posa: vale il riquadro")
        // La maglia finisce sopra l'ombelico: in basso restano pancia e jeans, tolti
        XCTAssertLessThan(Double(piece.image.height), 0.7 * Double(photo.height))
        XCTAssertGreaterThan(Double(piece.image.height), 0.45 * Double(photo.height))
    }

    func testDallaFotoPerStradaRestanoSoloIPantaloni() async throws {
        let photo = try fixture("capo-indossato-strada")
        let cutout = try await PersonCutout.cutout(photo, allInstances: true)
        let piece = try await XCTUnwrapAsync(await WornGarment.piece(from: cutout, photo: photo, slot: "bottom"))
        let pose = try XCTUnwrap(piece.pose)
        XCTAssertNotNil(pose.points[.leftHip])
        XCTAssertLessThan(Double(piece.image.height), 0.7 * Double(cutout.bounds.height), "niente testa e busto")
    }

    func testIlCapoDaSoloResta() async throws {
        for name in ["maglione", "jeans", "sneakers"] {
            let photo = try fixture(name)
            let cutout = try await PersonCutout.cutout(photo, allInstances: true)
            let piece = await WornGarment.piece(from: cutout, photo: photo, slot: "top")
            XCTAssertNil(piece, "\(name): nessuna persona, il capo si usa intero")
        }
    }

    func testAvatarConCapiIndossati() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cache = CutoutCache(folder: folder)
        func data(_ name: String) throws -> Data {
            try Data(contentsOf: XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "jpg", subdirectory: "Fixtures")))
        }
        let garments = [AvatarGarment(slot: "top", photo: try data("capo-indossato-negozio"), key: "negozio"),
                        AvatarGarment(slot: "bottom", photo: try data("capo-indossato-strada"), key: "strada")]
        let result = try await AvatarRenderer.render(body: try data("persona"), bodyKey: "persona", garments: garments,
                                                     view: .front, cache: cache)
        XCTAssertEqual(result.unavailable, 0)
        dump(result.image, "avatar-capi-indossati")
        // La seconda volta il ritaglio viene dal disco
        let again = try await AvatarRenderer.render(body: try data("persona"), bodyKey: "persona", garments: garments,
                                                    view: .front, cache: CutoutCache(folder: folder))
        XCTAssertEqual(again.unavailable, 0)
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

// Armocromia: l'analisi del viso con Vision al posto di MediaPipe.
extension VisionTests {
    func testLeggeColoriDaUnaFotoConIlViso() async throws {
        let colors = try await FaceColorAnalyzer.analyze(try fixture("persona"))
        let skin = try XCTUnwrap(ColorLab.lab(hex: try XCTUnwrap(colors.skin)))
        // Una pelle ha sempre a e b positivi e non è né nera né bianca.
        XCTAssertGreaterThan(skin.a, 2)
        XCTAssertGreaterThan(skin.b, 2)
        XCTAssertTrue((30...92).contains(skin.L), "L \(skin.L)")
        XCTAssertNotNil(ArmocromiaClassifier.classify(colors))
    }

    func testSenzaVisoNessunColore() async throws {
        let colors = try await FaceColorAnalyzer.analyze(solidImage(width: 400, height: 600))
        XCTAssertEqual(colors, FaceColors())
    }
}
