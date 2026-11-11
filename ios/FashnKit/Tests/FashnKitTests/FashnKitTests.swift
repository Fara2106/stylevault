import CoreGraphics
import XCTest
@testable import FashnKit
import FashnWorn

final class FashnKitTests: XCTestCase {
    func testUnaFotoDueTerziRiempieIlRiquadro() {
        let frame = Frame(sourceWidth: 576, sourceHeight: 864)
        XCTAssertEqual([frame.width, frame.height, frame.left, frame.top, frame.right, frame.bottom], [576, 864, 0, 0, 0, 0])
    }

    func testUnaFotoQuadrataHaBordiSopraESotto() {
        let frame = Frame(sourceWidth: 864, sourceHeight: 864)
        XCTAssertEqual([frame.width, frame.height, frame.left, frame.top, frame.bottom], [576, 576, 0, 144, 144])
    }

    func testIlBordoInPiuVaADestra() {
        // 500×864 non si ridimensiona: 76 pixel di bordo, 38 per parte; con 501 quello in più va a destra
        let even = Frame(sourceWidth: 500, sourceHeight: 864)
        XCTAssertEqual([even.width, even.left, even.right], [500, 38, 38])
        let odd = Frame(sourceWidth: 501, sourceHeight: 864)
        XCTAssertEqual([odd.width, odd.left, odd.right], [501, 37, 38])
    }

    func testUnaFotoPiccolaSiIngrandisceNelRiquadroMaNonPrima() {
        XCTAssertTrue(Frame.preResized(width: 300, height: 450) == (300, 450))
        XCTAssertTrue(Frame.preResized(width: 3000, height: 4000) == (648, 864))
        let frame = Frame(sourceWidth: 300, sourceHeight: 450)
        XCTAssertEqual([frame.width, frame.height], [576, 864])
    }

    func testLaSchedulePartedaZeroEArrivaAUno() {
        let schedule = rectifiedFlowSchedule(steps: 20)
        XCTAssertEqual(schedule.count, 21)
        XCTAssertEqual(schedule.first ?? -1, 0, accuracy: 1e-12)
        XCTAssertEqual(schedule.last ?? -1, 1, accuracy: 1e-12)
        XCTAssertEqual(schedule, schedule.sorted())
    }

    func testLaPercentualeContaIPassaggi() {
        XCTAssertEqual(FashnProgress.passes(steps: 20), 39)
        XCTAssertEqual(FashnProgress(step: 0, steps: 20, passesDone: 0, passesTotal: 39).percent, 0)
        XCTAssertEqual(FashnProgress(step: 10, steps: 20, passesDone: 20, passesTotal: 39).percent, 51)
        XCTAssertEqual(FashnProgress(step: 20, steps: 20, passesDone: 38, passesTotal: 39).percent, 97)
        XCTAssertEqual(FashnProgress(step: 20, steps: 20, passesDone: 39, passesTotal: 39).percent, 100)
    }

    func testIlRumoreERipetibileEGaussiano() {
        var a = GaussianNoise(seed: 7), b = GaussianNoise(seed: 7), c = GaussianNoise(seed: 8)
        let first = a.fill(count: 20_001)
        XCTAssertEqual(first, b.fill(count: 20_001))
        XCTAssertNotEqual(first, c.fill(count: 20_001))
        let mean = first.reduce(0, +) / Float(first.count)
        let variance = first.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Float(first.count)
        XCTAssertEqual(mean, 0, accuracy: 0.03)
        XCTAssertEqual(variance, 1, accuracy: 0.05)
    }

    func testIGrigiDegliArtiSonoQuelliDellOriginale() {
        // np.linspace(20, 240, 18).astype(np.uint8)
        XCTAssertEqual(PoseSketch.limbGrays, [20, 32, 45, 58, 71, 84, 97, 110, 123, 136, 149, 162, 175, 188, 201, 214, 227, 240])
        XCTAssertEqual(PoseSketch.handGrays.first, 160)
        XCTAssertEqual(PoseSketch.handGrays.last, 220)
    }

    func testSenzaPersonaIlDisegnoENero() {
        let canvas = PoseSketch.draw(.none, width: 40, height: 60)
        XCTAssertEqual(canvas.pixels.max(), 0)
    }

    func testUnArtoHaIlSuoGrigioAttenuatoEIGiuntiPiuChiari() {
        var pose = PoseKeypoints()
        pose.body[1] = CGPoint(x: 50, y: 20)   // collo
        pose.body[2] = CGPoint(x: 20, y: 20)   // spalla destra
        let canvas = PoseSketch.draw(pose, width: 100, height: 40)
        // Primo arto (collo-spalla destra): grigio 20, attenuato a 12; giunti a 26
        XCTAssertEqual(canvas[35, 20], 12)
        XCTAssertEqual(canvas[35, 23], 12)
        XCTAssertEqual(canvas[35, 26], 0)
        XCTAssertEqual(canvas[50, 20], 26)
        XCTAssertEqual(canvas[20, 20], 26)
        XCTAssertEqual(canvas[80, 20], 0)
    }

    func testUnPuntoMancanteToglieIlSuoArto() {
        var pose = PoseKeypoints()
        pose.body[1] = CGPoint(x: 50, y: 20)
        let canvas = PoseSketch.draw(pose, width: 100, height: 40)
        XCTAssertEqual(canvas[35, 20], 0)
        XCTAssertEqual(canvas[50, 20], 26)
    }

    func testManiEVisoHannoIGrigiDellOriginale() {
        var pose = PoseKeypoints()
        var hand = [CGPoint?](repeating: nil, count: 21)
        hand[0] = CGPoint(x: 10, y: 30)
        hand[1] = CGPoint(x: 30, y: 30)
        pose.hands = [hand]
        pose.face = [CGPoint(x: 60, y: 10)]
        let canvas = PoseSketch.draw(pose, width: 80, height: 40)
        XCTAssertEqual(canvas[20, 30], 160)   // primo tratto della mano
        XCTAssertEqual(canvas[10, 30], 240)   // punto della mano
        XCTAssertEqual(canvas[60, 10], 200)   // punto del viso
    }

    func testIlRidimensionamentoNonMescolaIGrigi() {
        var canvas = GrayCanvas(width: 4, height: 4)
        canvas[0, 0] = 200
        canvas[3, 3] = 100
        let big = canvas.resizedNearest(width: 8, height: 8)
        XCTAssertEqual(Set(big.pixels), [0, 100, 200])
        XCTAssertEqual(big[1, 1], 200)
        XCTAssertEqual(big[7, 7], 100)
    }

    func testIlTensoreDiUnaFotoRossaConIBordi() throws {
        let image = try XCTUnwrap(Self.solid(width: 200, height: 200, red: 255, green: 0, blue: 0))
        let frame = Frame(sourceWidth: 200, sourceHeight: 200)
        let tensor = try FashnPrepare.colorTensor(image, frame: frame)
        let plane = FashnModel.width * FashnModel.height
        XCTAssertEqual(tensor.count, 3 * plane)
        let center = (FashnModel.height / 2) * FashnModel.width + FashnModel.width / 2
        XCTAssertEqual(tensor[center], 1, accuracy: 0.02)
        XCTAssertEqual(tensor[plane + center], -1, accuracy: 0.02)
        // In alto c'è il bordo nero
        XCTAssertEqual(tensor[10], -1, accuracy: 0.001)
        XCTAssertEqual(frame.top, 144)
    }

    func testLUscitaTornaImmagineSenzaBordi() throws {
        let frame = Frame(sourceWidth: 864, sourceHeight: 864)
        let plane = FashnModel.width * FashnModel.height
        let image = try XCTUnwrap(FashnPrepare.image(fromOutput: [Float](repeating: 1, count: 3 * plane), frame: frame))
        XCTAssertEqual([image.width, image.height], [576, 576])
    }

    // MARK: - Outfit di più capi

    /// Finto modello: segna cosa riceve e restituisce un'immagine a tinta unita, diversa per ogni categoria.
    private final class FakeSampler: TryOnSampling, @unchecked Sendable {
        private let lock = NSLock()
        private(set) var categories: [GarmentCategory] = []
        private(set) var personValues: [Float] = []
        var failAt: Int?

        func generate(_ inputs: FashnInputs, steps: Int, seed: UInt64, progress: (FashnProgress) -> Void) throws -> [Float] {
            let call = lock.withLock { () -> Int in
                categories.append(inputs.category)
                personValues.append(inputs.person.first ?? 0)
                return categories.count
            }
            if failAt == call { throw FashnError.model("finto errore") }
            let total = FashnProgress.passes(steps: steps)
            for pass in 0...total { progress(FashnProgress(step: (pass + 1) / 2, steps: steps, passesDone: pass, passesTotal: total)) }
            return [Float](repeating: Float(inputs.category.rawValue) / 4, count: 3 * FashnModel.width * FashnModel.height)
        }
    }

    private static let fakePrepare: OutfitTryOn.Prepare = { person, garment in
        let frame = Frame(sourceWidth: person.width, sourceHeight: person.height)
        let plane = FashnModel.width * FashnModel.height
        return FashnInputs(person: try FashnPrepare.colorTensor(person, frame: frame), garment: [], personPose: [], garmentPose: [],
                           category: garment.category, personFrame: frame,
                           personPoseSketch: GrayCanvas(width: FashnModel.width, height: FashnModel.height), bodyPointsFound: plane > 0 ? 18 : 0)
    }

    private final class Collected: @unchecked Sendable {
        private let lock = NSLock()
        private var values: [OutfitProgress] = []
        private var count = 0
        func add(_ value: OutfitProgress) { lock.withLock { values.append(value) } }
        func tick() { lock.withLock { count += 1 } }
        var all: [OutfitProgress] { lock.withLock { values } }
        var ticks: Int { lock.withLock { count } }
    }

    func testDueCapiUnoDopoLAltroConUnaSolaBarra() async throws {
        let person = try XCTUnwrap(Self.solid(width: 576, height: 864, red: 10, green: 10, blue: 10))
        let photo = try XCTUnwrap(Self.solid(width: 100, height: 100, red: 200, green: 0, blue: 0))
        let sampler = FakeSampler()
        let seen = Collected()
        let result = try await OutfitTryOn.generate(person: person, garments: [TryOnGarment(photo: photo, category: .tops),
                                                                                TryOnGarment(photo: photo, category: .bottoms)],
                                                    steps: 4, seed: 1, sampler: sampler, prepare: Self.fakePrepare,
                                                    betweenPasses: { seen.tick() }, progress: { seen.add($0) })
        XCTAssertEqual(sampler.categories, [.tops, .bottoms])
        // Il secondo capo parte dal risultato del primo, non dalla foto di partenza
        XCTAssertEqual(sampler.personValues[1], Float(UInt8((0.25 + 1) * 127.5)) / 127.5 - 1, accuracy: 0.02)
        XCTAssertNotEqual(sampler.personValues[0], sampler.personValues[1])
        XCTAssertEqual([result.width, result.height], [576, 864])

        let all = seen.all
        XCTAssertEqual(all.first, OutfitProgress(garment: 1, garments: 2, passesDone: 0, passesTotal: 14))
        XCTAssertEqual(all.last, OutfitProgress(garment: 2, garments: 2, passesDone: 14, passesTotal: 14))
        XCTAssertEqual(all.last?.percent, 100)
        // La barra non torna mai indietro, nemmeno quando comincia il secondo capo
        XCTAssertEqual(all.map(\.passesDone), all.map(\.passesDone).sorted())
        XCTAssertTrue(all.contains(OutfitProgress(garment: 2, garments: 2, passesDone: 7, passesTotal: 14)))
        XCTAssertEqual(seen.ticks, 16)
    }

    func testSenzaCapiRestaLaPersona() async throws {
        let person = try XCTUnwrap(Self.solid(width: 40, height: 60, red: 1, green: 2, blue: 3))
        let sampler = FakeSampler()
        let result = try await OutfitTryOn.generate(person: person, garments: [], steps: 4, seed: 1, sampler: sampler, prepare: Self.fakePrepare)
        XCTAssertTrue(result === person)
        XCTAssertTrue(sampler.categories.isEmpty)
    }

    func testUnErroreAlSecondoCapoFermaTutto() async throws {
        let person = try XCTUnwrap(Self.solid(width: 576, height: 864, red: 10, green: 10, blue: 10))
        let sampler = FakeSampler()
        sampler.failAt = 2
        do {
            _ = try await OutfitTryOn.generate(person: person, garments: [TryOnGarment(photo: person, category: .tops),
                                                                         TryOnGarment(photo: person, category: .bottoms)],
                                               steps: 4, seed: 1, sampler: sampler, prepare: Self.fakePrepare)
            XCTFail("doveva fermarsi")
        } catch {
            XCTAssertEqual(sampler.categories.count, 2)
        }
    }

    func testAnnullareFermaPrimaDelCapoSuccessivo() async throws {
        let person = try XCTUnwrap(Self.solid(width: 576, height: 864, red: 10, green: 10, blue: 10))
        let sampler = FakeSampler()
        let task = Task {
            try await OutfitTryOn.generate(person: person, garments: [TryOnGarment(photo: person, category: .tops)],
                                           steps: 4, seed: 1, sampler: sampler, prepare: Self.fakePrepare)
        }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("doveva essere annullata")
        } catch is CancellationError {
            XCTAssertTrue(sampler.categories.isEmpty)
        }
    }

    private static func solid(width: Int, height: Int, red: UInt8, green: UInt8, blue: UInt8) -> CGImage? {
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        context.setFillColor(red: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}
