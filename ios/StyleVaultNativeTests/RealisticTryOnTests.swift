import CoreGraphics
import FashnKit
import FashnWorn
import SwiftData
import XCTest
@testable import StyleVaultNative

/// Finto generatore: fa avanzare la barra come gli si dice e restituisce un'immagine, o un errore.
private final class ScriptedGenerator: RealisticGenerating, @unchecked Sendable {
    struct Failure: Error {}

    var isAvailable = true
    var fractions: [Double] = [0, 0.5, 1]
    var fails = false
    private let lock = NSLock()
    private var received: [[RealisticPlan.Piece]] = []
    var calls: [[RealisticPlan.Piece]] { lock.withLock { received } }

    func generate(body: Data, bodyKey: String, pieces: [RealisticPlan.Piece],
                  progress: @escaping @Sendable (RealisticProgress) -> Void) async throws -> CGImage {
        lock.withLock { received.append(pieces) }
        for fraction in fractions { progress(RealisticProgress(fraction: fraction, garment: 1, garments: pieces.count)) }
        try Task.checkCancellation()
        if fails { throw Failure() }
        return RealisticTryOnTests.solid(width: 20, height: 30)
    }
}

/// Finto generatore che, come il modello vero mentre si carica, non si accorge dell'annullamento finché non lo si lascia andare.
private final class GatedGenerator: RealisticGenerating, @unchecked Sendable {
    struct Failure: Error {}

    var isAvailable = true
    var failsWhenReleased = false
    private let lock = NSLock()
    private var isOpen = false
    private var waiting: [CheckedContinuation<Void, Never>] = []
    private var running = 0
    private var startedCount = 0
    private var peak = 0

    var started: Int { lock.withLock { startedCount } }
    var mostTogether: Int { lock.withLock { peak } }

    func release() {
        let resumed = lock.withLock {
            isOpen = true
            defer { waiting = [] }
            return waiting
        }
        resumed.forEach { $0.resume() }
    }

    func generate(body: Data, bodyKey: String, pieces: [RealisticPlan.Piece],
                  progress: @escaping @Sendable (RealisticProgress) -> Void) async throws -> CGImage {
        lock.withLock {
            running += 1
            startedCount += 1
            peak = max(peak, running)
        }
        defer { lock.withLock { running -= 1 } }
        await withCheckedContinuation { continuation in
            let goes = lock.withLock {
                if isOpen { return true }
                waiting.append(continuation)
                return false
            }
            if goes { continuation.resume() }
        }
        if failsWhenReleased { throw Failure() }
        return RealisticTryOnTests.solid(width: 20, height: 30)
    }
}

@MainActor final class RealisticTryOnTests: XCTestCase {
    private var container: ModelContainer?
    private var folder: URL!

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("realistic-\(UUID().uuidString)")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: folder)
    }

    nonisolated static func solid(width: Int, height: Int) -> CGImage {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.setFillColor(red: 0.8, green: 0.2, blue: 0.1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    private func item(_ name: String, _ category: String, photo: Bool = true) throws -> Item {
        if container == nil { container = try StoreFactory.build(.memory) }
        var values = ItemValues()
        values.name = name
        values.category = category
        values.photoFront = photo ? Data([1, 2, 3]) : nil
        return try WardrobeStore.addItem(values, in: try XCTUnwrap(container).mainContext)
    }

    private func plan(_ items: [Item]) -> RealisticPlan { RealisticPlan.make(TryOnSelection.from(items)) }

    // MARK: - Cosa si genera

    func testSopraESottoSiGeneranoInQuestOrdine() throws {
        let made = plan([try item("Jeans", "bottoms"), try item("Maglia", "tops")])
        XCTAssertEqual(made.pieces.map(\.name), ["Maglia", "Jeans"])
        XCTAssertEqual(made.pieces.map(\.category), [.tops, .bottoms])
        XCTAssertTrue(made.leftOut.isEmpty)
        XCTAssertTrue(made.canGenerate)
    }

    func testCapospallaEScarpeRestanoFuoriEVengonoNominati() throws {
        let made = plan([try item("Maglia", "tops"), try item("Cappotto", "outerwear"), try item("Sneakers", "shoes")])
        XCTAssertEqual(made.pieces.map(\.name), ["Maglia"])
        XCTAssertEqual(made.leftOut, ["Cappotto", "Sneakers"])
    }

    func testConUnVestitoSopraESottoRestanoFuori() throws {
        let made = plan([try item("Maglia", "tops"), try item("Vestito", "dresses"), try item("Jeans", "bottoms")])
        XCTAssertEqual(made.pieces.map(\.name), ["Vestito"])
        XCTAssertEqual(made.pieces.first?.category, .onePieces)
        XCTAssertEqual(made.leftOut, ["Maglia", "Jeans"])
    }

    func testUnCapoSenzaFotoRestaFuori() throws {
        let made = plan([try item("Maglia", "tops", photo: false), try item("Jeans", "bottoms")])
        XCTAssertEqual(made.pieces.map(\.name), ["Jeans"])
        XCTAssertEqual(made.leftOut, ["Maglia"])
    }

    func testSoloScarpeNonSiGenera() throws {
        let made = plan([try item("Sneakers", "shoes")])
        XCTAssertTrue(made.pieces.isEmpty)
        XCTAssertFalse(made.canGenerate)
    }

    func testIntimoEAccessoriNonEntranoNemmenoTraGliEsclusi() throws {
        let made = plan([try item("Maglia", "tops"), try item("Slip", "underwear"), try item("Cintura", "accessories")])
        XCTAssertEqual(made.pieces.map(\.name), ["Maglia"])
        XCTAssertTrue(made.leftOut.isEmpty)
    }

    func testConUnCostumeNonSiGenera() throws {
        let made = plan([try item("Costume da bagno", "bottoms"), try item("Maglia", "tops")])
        XCTAssertTrue(made.hasSwimwear)
        XCTAssertFalse(made.canGenerate)
    }

    func testLaChiaveDelCapoELaStessaDellAvatar() throws {
        let top = try item("Maglia", "tops")
        let made = plan([top])
        XCTAssertEqual(made.pieces.first?.key, AvatarRequest.make(TryOnSelection.from([top]), view: .front).garments.first?.key)
    }

    // MARK: - Dispositivi

    func testSoloIDispositiviCheLoReggono() {
        let gigabyte: UInt64 = 1_073_741_824
        XCTAssertTrue(SystemRealisticGenerator.supports(memory: 8 * gigabyte, hasModel: true, systemIsRecentEnough: true))
        // Un telefono «da 8 GB» ne dichiara un po' meno
        XCTAssertTrue(SystemRealisticGenerator.supports(memory: 7_600_000_000, hasModel: true, systemIsRecentEnough: true))
        XCTAssertTrue(SystemRealisticGenerator.supports(memory: 7_300_000_000, hasModel: true, systemIsRecentEnough: true))
        XCTAssertFalse(SystemRealisticGenerator.supports(memory: 6 * gigabyte, hasModel: true, systemIsRecentEnough: true))
        XCTAssertFalse(SystemRealisticGenerator.supports(memory: 6_300_000_000, hasModel: true, systemIsRecentEnough: true))
        XCTAssertFalse(SystemRealisticGenerator.supports(memory: 12 * gigabyte, hasModel: false, systemIsRecentEnough: true))
        XCTAssertFalse(SystemRealisticGenerator.supports(memory: 12 * gigabyte, hasModel: true, systemIsRecentEnough: false))
    }

    func testSenzaModelloNelPacchettoLaFunzioneESpenta() {
        // Nelle build di prova il modello non c'è: la funzione non deve mostrarsi né provare a generare
        XCTAssertNil(SystemRealisticGenerator.modelURL)
        XCTAssertFalse(SystemRealisticGenerator().isAvailable)
    }

    // MARK: - Riquadro della persona

    func testIlRiquadroTieneTuttaLaPersonaInDueTerzi() {
        let frame = PersonFraming.frame(imageWidth: 3000, imageHeight: 4000, body: CGRect(x: 1200, y: 800, width: 600, height: 2400))
        XCTAssertTrue(frame.contains(CGRect(x: 1200, y: 800, width: 600, height: 2400)))
        XCTAssertEqual(frame.width / frame.height, 2.0 / 3.0, accuracy: 0.01)
        XCTAssertEqual(frame.midX, 1500, accuracy: 2)
    }

    func testIlRiquadroNonEsceDallaFoto() {
        let image = CGRect(x: 0, y: 0, width: 1000, height: 1500)
        let frame = PersonFraming.frame(imageWidth: 1000, imageHeight: 1500, body: CGRect(x: 0, y: 0, width: 400, height: 1500))
        XCTAssertTrue(image.contains(frame))
        XCTAssertEqual(frame.height, 1500)
        XCTAssertEqual(frame.minX, 0)
    }

    func testSenzaPersonaRestaLaFotoIntera() {
        XCTAssertEqual(PersonFraming.frame(imageWidth: 800, imageHeight: 600, body: .zero), CGRect(x: 0, y: 0, width: 800, height: 600))
    }

    // MARK: - Immagini già generate

    func testLaChiaveCambiaConFotoCapiEOrdine() throws {
        let made = plan([try item("Maglia", "tops"), try item("Jeans", "bottoms")])
        let key = RealisticCache.key(bodyKey: "body-1", pieces: made.pieces)
        XCTAssertEqual(key, RealisticCache.key(bodyKey: "body-1", pieces: made.pieces))
        XCTAssertNotEqual(key, RealisticCache.key(bodyKey: "body-2", pieces: made.pieces))
        XCTAssertNotEqual(key, RealisticCache.key(bodyKey: "body-1", pieces: Array(made.pieces.prefix(1))))
        XCTAssertNotEqual(key, RealisticCache.key(bodyKey: "body-1", pieces: made.pieces.reversed()))
    }

    func testUnImmagineSalvataSiRitrovaESiCancella() {
        XCTAssertNil(RealisticCache.load("k", in: folder))
        RealisticCache.save(Self.solid(width: 20, height: 30), key: "k", in: folder)
        XCTAssertEqual(RealisticCache.load("k", in: folder)?.width, 20)
        RealisticCache.removeAll(in: folder)
        XCTAssertNil(RealisticCache.load("k", in: folder))
    }

    func testLeImmaginiValgonoSoloPerLaFotoDelCorpoDiAdesso() throws {
        let pieces = plan([try item("Maglia", "tops")]).pieces
        let image = Self.solid(width: 20, height: 30)
        let first = RealisticCache.key(bodyKey: "body-front-A-1", pieces: pieces)
        let second = RealisticCache.key(bodyKey: "body-front-A-2", pieces: pieces)
        RealisticCache.save(image, key: first, in: folder)
        // Stessa foto: l'immagine resta
        RealisticCache.keep(for: "body-front-A-1", in: folder)
        XCTAssertNotNil(RealisticCache.load(first, in: folder))
        // Foto cambiata su un altro dispositivo: l'immagine era fatta con quella di prima
        RealisticCache.keep(for: "body-front-A-2", in: folder)
        XCTAssertNil(RealisticCache.load(first, in: folder))
        // Un'immagine fatta con la foto di prima e salvata dopo la pulizia sparisce al controllo dopo; quella di adesso resta
        RealisticCache.save(image, key: first, in: folder)
        RealisticCache.save(image, key: second, in: folder)
        RealisticCache.keep(for: "body-front-A-2", in: folder)
        XCTAssertNil(RealisticCache.load(first, in: folder))
        XCTAssertNotNil(RealisticCache.load(second, in: folder))
        // Foto cancellata
        RealisticCache.keep(for: "", in: folder)
        XCTAssertNil(RealisticCache.load(second, in: folder))
    }

    // MARK: - Generazione

    private func model(_ items: [Item], awake: @escaping (Bool) -> Void = { _ in }) -> RealisticTryOnModel {
        RealisticTryOnModel(plan: plan(items), cacheFolder: folder, keepAwake: awake)
    }

    func testGeneraMostraIlRisultatoELoSalva() async throws {
        var awake: [Bool] = []
        let made = model([try item("Maglia", "tops"), try item("Jeans", "bottoms")]) { awake.append($0) }
        let generator = ScriptedGenerator()
        made.generate(body: Data([9]), bodyKey: "body-1", with: generator)
        XCTAssertTrue(made.isGenerating)
        XCTAssertEqual(made.progress?.percent, 0)
        await made.waitUntilFinished()
        XCTAssertEqual(made.phase, .done)
        XCTAssertNotNil(made.result)
        XCTAssertFalse(made.isFromCache)
        XCTAssertEqual(generator.calls.first?.map(\.name), ["Maglia", "Jeans"])
        // Lo schermo resta acceso durante la generazione e torna normale alla fine
        XCTAssertEqual(awake, [true, false])

        // Riaprendo lo stesso outfit con la stessa foto l'immagine c'è già
        let again = model([try XCTUnwrap(container).mainContext.fetch(FetchDescriptor<Item>()).first { $0.name == "Maglia" }!,
                           try XCTUnwrap(container).mainContext.fetch(FetchDescriptor<Item>()).first { $0.name == "Jeans" }!])
        again.restore(bodyKey: "body-1")
        XCTAssertEqual(again.phase, .done)
        XCTAssertTrue(again.isFromCache)
        // Con un'altra foto del corpo no
        let other = model([try item("Maglia 2", "tops")])
        other.restore(bodyKey: "body-2")
        XCTAssertEqual(other.phase, .idle)
    }

    func testUnErroreSiVedeENonLasciaLoSchermoAcceso() async throws {
        var awake: [Bool] = []
        let made = model([try item("Maglia", "tops")]) { awake.append($0) }
        let generator = ScriptedGenerator()
        generator.fails = true
        made.generate(body: Data([9]), bodyKey: "body-1", with: generator)
        await made.waitUntilFinished()
        XCTAssertEqual(made.phase, .failed)
        XCTAssertNil(made.result)
        XCTAssertEqual(awake, [true, false])
    }

    func testSenzaCapiGenerabiliNonParte() throws {
        let made = model([try item("Sneakers", "shoes")])
        let generator = ScriptedGenerator()
        made.generate(body: Data([9]), bodyKey: "body-1", with: generator)
        XCTAssertEqual(made.phase, .idle)
        XCTAssertTrue(generator.calls.isEmpty)
    }

    func testAnnullareTornaAllInizio() async throws {
        let made = model([try item("Maglia", "tops")])
        made.generate(body: Data([9]), bodyKey: "body-1", with: ScriptedGenerator())
        made.cancel()
        await made.waitUntilFinished()
        XCTAssertEqual(made.phase, .idle)
        XCTAssertNil(made.result)
        XCTAssertNil(RealisticCache.load(RealisticCache.key(bodyKey: "body-1", pieces: made.plan.pieces), in: folder))
    }

    // MARK: - Annullare

    /// Aspetta che una condizione diventi vera, senza un tempo fisso.
    private func eventually(_ condition: () -> Bool) async {
        for _ in 0..<500 where !condition() { try? await Task.sleep(for: .milliseconds(10)) }
    }

    func testAnnullareEImmediatoAncheSeIlModelloNonSiFermaSubito() async throws {
        var awake: [Bool] = []
        let made = model([try item("Maglia", "tops")]) { awake.append($0) }
        let generator = GatedGenerator()
        made.generate(body: Data([9]), bodyKey: "body-1", with: generator)
        await eventually { generator.started == 1 }
        made.cancel()
        // Il modello sta ancora caricando e non può fermarsi: chi ha toccato «Annulla» lo vede subito lo stesso
        XCTAssertEqual(made.phase, .idle)
        XCTAssertNil(made.progress)
        generator.release()
        await made.waitUntilFinished()
        // L'immagine arrivata dopo l'annullamento non si mostra e non si salva
        XCTAssertEqual(made.phase, .idle)
        XCTAssertNil(made.result)
        XCTAssertNil(RealisticCache.load(RealisticCache.key(bodyKey: "body-1", pieces: made.plan.pieces), in: folder))
        XCTAssertEqual(awake, [true, false])
    }

    func testCambiataLaFotoDelCorpoLImmagineInArrivoNonSiSalva() async throws {
        let made = model([try item("Maglia", "tops")])
        let generator = GatedGenerator()
        made.generate(body: Data([9]), bodyKey: "body-1", with: generator)
        await eventually { generator.started == 1 }
        // La foto del corpo sparisce (anche da un altro dispositivo) mentre il modello lavora
        made.forget()
        XCTAssertEqual(made.phase, .idle)
        generator.release()
        await made.waitUntilFinished()
        XCTAssertEqual(made.phase, .idle)
        XCTAssertNil(made.result)
        XCTAssertNil(RealisticCache.load(RealisticCache.key(bodyKey: "body-1", pieces: made.plan.pieces), in: folder))
    }

    func testCambiataLaFotoDelCorpoLImmagineMostrataSparisce() async throws {
        let made = model([try item("Maglia", "tops")])
        made.generate(body: Data([9]), bodyKey: "body-1", with: ScriptedGenerator())
        await made.waitUntilFinished()
        XCTAssertEqual(made.phase, .done)
        made.forget()
        XCTAssertEqual(made.phase, .idle)
        XCTAssertNil(made.result)
        XCTAssertFalse(made.isFromCache)
    }

    func testUnErroreArrivatoDopoLAnnullamentoNonSiMostra() async throws {
        let made = model([try item("Maglia", "tops")])
        let generator = GatedGenerator()
        generator.failsWhenReleased = true
        made.generate(body: Data([9]), bodyKey: "body-1", with: generator)
        await eventually { generator.started == 1 }
        made.cancel()
        generator.release()
        await made.waitUntilFinished()
        XCTAssertEqual(made.phase, .idle)
    }

    func testDopoUnAnnullamentoLaNuovaGenerazioneAspettaLaVecchia() async throws {
        var awake: [Bool] = []
        let made = model([try item("Maglia", "tops")]) { awake.append($0) }
        let generator = GatedGenerator()
        made.generate(body: Data([9]), bodyKey: "body-1", with: generator)
        await eventually { generator.started == 1 }
        made.cancel()
        made.generate(body: Data([9]), bodyKey: "body-1", with: generator)
        XCTAssertTrue(made.isGenerating)
        // La vecchia non ha ancora lasciato il modello: la nuova non parte, altrimenti sarebbe in memoria due volte
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(generator.started, 1)
        generator.release()
        await made.waitUntilFinished()
        XCTAssertEqual(generator.started, 2)
        XCTAssertEqual(generator.mostTogether, 1)
        XCTAssertEqual(made.phase, .done)
        XCTAssertNotNil(made.result)
        // Lo schermo resta acceso fino alla fine della seconda
        XCTAssertEqual(awake, [true, false, true, false])
    }

    func testAnnullareUnaRigenerazioneLasciaLImmagineDiPrima() async throws {
        let made = model([try item("Maglia", "tops")])
        made.generate(body: Data([9]), bodyKey: "body-1", with: ScriptedGenerator())
        await made.waitUntilFinished()
        XCTAssertEqual(made.phase, .done)
        let generator = GatedGenerator()
        made.generate(body: Data([9]), bodyKey: "body-1", with: generator)
        await eventually { generator.started == 1 }
        made.cancel()
        XCTAssertEqual(made.phase, .done)
        XCTAssertNotNil(made.result)
        generator.release()
        await made.waitUntilFinished()
        XCTAssertEqual(made.phase, .done)
    }

    func testLaPercentualeNonSuperaCentoENonScendeSottoZero() {
        XCTAssertEqual(RealisticProgress(fraction: 1.2, garment: 1, garments: 1).percent, 100)
        XCTAssertEqual(RealisticProgress(fraction: -0.1, garment: 1, garments: 1).percent, 0)
        XCTAssertEqual(RealisticProgress(fraction: 0.499, garment: 1, garments: 2).percent, 49)
    }

    // MARK: - Pause

    func testSiFermaFinchéIlDispositivoECaldoEDiceQuando() {
        let states = Locked([ProcessInfo.ThermalState.serious, .serious, .fair])
        let slept = Locked([TimeInterval]())
        let pauses = GenerationPauses(thermalState: { states.next() ?? .nominal }, sleep: { seconds in slept.append(seconds) })
        var reported: [RealisticPause?] = []
        pauses.waitIfNeeded { reported.append($0) }
        XCTAssertEqual(reported, [.heat, nil])
        XCTAssertEqual(slept.all.count, 2)
    }

    func testATemperaturaNormaleNonSiFerma() {
        let pauses = GenerationPauses(thermalState: { .fair }, sleep: { _ in XCTFail("non doveva aspettare") })
        var reported: [RealisticPause?] = []
        pauses.waitIfNeeded { reported.append($0) }
        XCTAssertTrue(reported.isEmpty)
    }

    func testFuoriDalPrimoPianoAspettaIlRitorno() {
        let slept = Locked([TimeInterval]())
        var pauses: GenerationPauses!
        pauses = GenerationPauses(thermalState: { .nominal }, sleep: { seconds in
            slept.append(seconds)
            if slept.all.count == 3 { pauses.setAway(false) }
        })
        pauses.setAway(true)
        var reported: [RealisticPause?] = []
        pauses.waitIfNeeded { reported.append($0) }
        XCTAssertEqual(reported, [.background, nil])
        XCTAssertEqual(slept.all.count, 3)
    }
}

/// Una lista condivisa tra fili, per i finti dei test.
private final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Value]
    init(_ values: [Value]) { self.values = values }
    func next() -> Value? { lock.withLock { values.isEmpty ? nil : values.removeFirst() } }
    func append(_ value: Value) { lock.withLock { values.append(value) } }
    var all: [Value] { lock.withLock { values } }
}
