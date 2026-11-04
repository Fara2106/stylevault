import CoreGraphics
import XCTest
@testable import StyleVault

/// Motore finto: aspetta `delay`, manda l'avanzamento e restituisce un'immagine piena.
private final class FakeEngine: RealisticTryOn, @unchecked Sendable {
    private let lock = NSLock()
    private var _calls = 0
    var calls: Int { lock.lock(); defer { lock.unlock() }; return _calls }
    let delay: Duration
    let error: Error?

    init(delay: Duration = .milliseconds(150), error: Error? = nil) {
        self.delay = delay; self.error = error
    }

    func generate(person: CGImage, garment: CGImage, item: AvatarItem,
                  progress: @Sendable (TryOnProgress) -> Void) async throws -> CGImage {
        lock.lock(); _calls += 1; lock.unlock()
        progress(TryOnProgress(fraction: 0.1))
        // Come il motore vero: si ferma tra un passo e l'altro se annullato
        for step in 1...10 {
            try await Task.sleep(for: delay / 10)
            try Task.checkCancellation()
            progress(TryOnProgress(fraction: Double(step) / 10))
        }
        if let error { throw error }
        return RealisticAvatarModelTests.solid(person.width, person.height)
    }
}

/// Store finto: conta le chiamate; se non è pronto, "scarica" e "prepara" in un attimo.
private final class FakeStore: RealisticModelPreparing, @unchecked Sendable {
    private let lock = NSLock()
    private var ready: Bool
    private var _readyChecks = 0, _prepares = 0
    let failure: ModelStoreError?
    var readyChecks: Int { lock.lock(); defer { lock.unlock() }; return _readyChecks }
    var prepares: Int { lock.lock(); defer { lock.unlock() }; return _prepares }

    init(ready: Bool, failure: ModelStoreError? = nil) { self.ready = ready; self.failure = failure }

    var isReady: Bool {
        get async { lock.lock(); defer { lock.unlock() }; _readyChecks += 1; return ready }
    }

    func prepare(progress: @escaping @Sendable (ModelStoreProgress) -> Void) async throws {
        lock.lock(); _prepares += 1; lock.unlock()
        if let failure { throw failure }
        progress(.downloading(done: 0, total: 1_000))
        try await Task.sleep(for: .milliseconds(80))
        progress(.downloading(done: 1_000, total: 1_000))
        progress(.preparing(done: 3, total: 7))
        try await Task.sleep(for: .milliseconds(80))
        lock.lock(); ready = true; lock.unlock()
    }
}

@MainActor
final class RealisticAvatarModelTests: XCTestCase {
    private var folder: URL!
    private var cache: RealisticCache!
    private let item = AvatarItem(id: "3f2a-UUID", category: "top", slot: "top",
                                  photo: "https://example.com/a.jpg", name: "Maglione", descriptor: "cream sweater")
    private let person = RealisticAvatarModelTests.solid(60, 80)
    private let garment = RealisticAvatarModelTests.solid(30, 40)

    nonisolated static func solid(_ w: Int, _ h: Int) -> CGImage {
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()!
    }

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appending(path: "realistic-test-\(UUID().uuidString)")
        cache = RealisticCache(folder: folder)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func model(engine: FakeEngine?, store: FakeStore? = FakeStore(ready: true),
                       supported: Bool = true) -> RealisticAvatarModel {
        RealisticAvatarModel(engine: engine, store: store, supported: supported, cache: cache)
    }

    private func start(_ m: RealisticAvatarModel, _ view: BodyView) async {
        await m.start(view, person: person, garment: garment, item: item, bodyKey: "body-\(view.rawValue)-abc")
    }

    /// Aspetta (al massimo 3 s) che la condizione sia vera.
    private func wait(_ condition: () -> Bool) async throws {
        for _ in 0..<300 where !condition() { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(condition(), "condizione mai raggiunta")
    }

    private func isGenerating(_ state: RealisticState?) -> Bool {
        if case .generating = state { return true }
        return false
    }

    func testFrontStartsAloneOthersOnDemand() async throws {
        let engine = FakeEngine()
        let m = model(engine: engine)
        XCTAssertEqual(m.state[.front], .collage)
        let run = Task { await start(m, .front) }
        try await wait { isGenerating(m.state[.front]) }
        await run.value
        XCTAssertEqual(m.state[.front], .ready)
        XCTAssertNotNil(m.images[.front])
        XCTAssertEqual(m.state[.side], .collage)
        XCTAssertEqual(m.state[.back], .collage)
        XCTAssertEqual(engine.calls, 1)
        let cached = await cache.image(item: item, view: .front, bodyKey: "body-front-abc")
        XCTAssertNotNil(cached, "il risultato resta salvato")
    }

    func testUnsupportedNeverDownloads() async {
        let store = FakeStore(ready: false)
        let engine = FakeEngine()
        let m = model(engine: engine, store: store, supported: false)
        await start(m, .front)
        for view in BodyView.allCases { XCTAssertEqual(m.state[view], .unsupported) }
        XCTAssertEqual(store.readyChecks, 0)
        XCTAssertEqual(store.prepares, 0)
        XCTAssertEqual(engine.calls, 0)
    }

    func testCancelAllReturnsToCollage() async throws {
        let engine = FakeEngine(delay: .seconds(2))
        let m = model(engine: engine)
        let run = Task { await start(m, .front) }
        try await wait { isGenerating(m.state[.front]) }
        m.cancelAll()
        XCTAssertEqual(m.state[.front], .collage)
        await run.value
        XCTAssertEqual(m.state[.front], .collage)
        XCTAssertNil(m.images[.front])
        let cached = await cache.image(item: item, view: .front, bodyKey: "body-front-abc")
        XCTAssertNil(cached)
        // Dopo l'annullamento si può ripartire
        XCTAssertFalse(m.isBusy)
    }

    func testOneGenerationAtATime() async throws {
        let engine = FakeEngine(delay: .milliseconds(400))
        let m = model(engine: engine)
        let run = Task { await start(m, .front) }
        try await wait { isGenerating(m.state[.front]) }
        XCTAssertTrue(m.isBusy)
        await start(m, .side)
        XCTAssertEqual(m.state[.side], .collage)
        await run.value
        XCTAssertEqual(m.state[.front], .ready)
        XCTAssertEqual(m.state[.side], .collage)
        XCTAssertEqual(engine.calls, 1)
    }

    func testCacheHitSkipsEngine() async {
        await cache.store(Self.solid(60, 80), item: item, view: .front, bodyKey: "body-front-abc")
        let store = FakeStore(ready: false)
        let engine = FakeEngine()
        let m = model(engine: engine, store: store)
        await start(m, .front)
        XCTAssertEqual(m.state[.front], .ready)
        XCTAssertNotNil(m.images[.front])
        XCTAssertEqual(engine.calls, 0)
        XCTAssertEqual(store.prepares, 0, "con l'immagine salvata non serve scaricare nulla")
    }

    func testRestoreOnlyFromCache() async {
        await cache.store(Self.solid(60, 80), item: item, view: .back, bodyKey: "body-back-abc")
        let engine = FakeEngine()
        let m = model(engine: engine)
        let back = await m.restore(.back, item: item, bodyKey: "body-back-abc")
        let side = await m.restore(.side, item: item, bodyKey: "body-side-abc")
        XCTAssertTrue(back)
        XCTAssertFalse(side)
        XCTAssertEqual(m.state[.back], .ready)
        XCTAssertEqual(m.state[.side], .collage)
        XCTAssertEqual(engine.calls, 0)
    }

    func testFirstUseDownloadsThenGenerates() async throws {
        let store = FakeStore(ready: false)
        let engine = FakeEngine()
        let m = model(engine: engine, store: store)
        var seen = [String]()
        let run = Task { await start(m, .front) }
        for _ in 0..<1000 {
            switch m.state[.front] {
            case .downloading?: if seen.last != "d" { seen.append("d") }
            case .preparing?: if seen.last != "p" { seen.append("p") }
            case .generating?: if seen.last != "g" { seen.append("g") }
            default: break
            }
            if m.state[.front] == .ready || seen.count > 10 { break }
            try await Task.sleep(for: .milliseconds(5))
        }
        await run.value
        XCTAssertEqual(seen, ["d", "p", "g"])
        XCTAssertEqual(m.state[.front], .ready)
        XCTAssertEqual(store.prepares, 1)
    }

    func testStoreErrorShowsMessageAndStaysCollage() async {
        let m = model(engine: FakeEngine(), store: FakeStore(ready: false, failure: .notEnoughSpace(neededMB: 2500)))
        await start(m, .front)
        XCTAssertEqual(m.state[.front], .failed("Serve più spazio: libera almeno 2,5 GB e riprova."))
        XCTAssertNil(m.images[.front])
        XCTAssertFalse(m.isBusy)
    }

    func testEngineErrorShowsMessage() async {
        let m = model(engine: FakeEngine(error: TryOnError.missingModel("Denoiser")))
        await start(m, .front)
        guard case .failed = m.state[.front] else { return XCTFail("atteso .failed, era \(String(describing: m.state[.front]))") }
        XCTAssertNil(m.images[.front])
    }

    func testRealisticItemPrefersOuterwear() {
        let top = AvatarItem(id: "t", category: "top", slot: "top", photo: "", name: "T")
        let coat = AvatarItem(id: "c", category: "outerwear", slot: "outerwear", photo: "", name: "C")
        let jeans = AvatarItem(id: "j", category: "bottom", slot: "bottom", photo: "", name: "J")
        XCTAssertEqual(RealisticAvatarModel.realisticItem(in: [top, jeans, coat])?.id, "c")
        XCTAssertEqual(RealisticAvatarModel.realisticItem(in: [jeans, top])?.id, "t")
        XCTAssertNil(RealisticAvatarModel.realisticItem(in: [jeans]))
    }

    func testProgressTexts() {
        XCTAssertEqual(RealisticAvatarModel.text(for: .downloading(done: 420_000_000, total: 1_200_000_000)),
                       "Scarico i modelli… 35% (420 MB di 1,2 GB)")
        XCTAssertEqual(RealisticAvatarModel.text(for: .preparing(done: 3, total: 7)),
                       "Preparo i modelli, solo la prima volta… 3/7")
        XCTAssertEqual(RealisticAvatarModel.text(for: .generating(0.4)), "Versione realistica… 40%")
        XCTAssertNil(RealisticAvatarModel.text(for: .ready))
    }

    func testStaleWorkFoldersRemoved() throws {
        let dir = folder.appending(path: "tmp")
        let fm = FileManager.default
        let old = dir.appending(path: "tryon-features-OLD")
        let other = dir.appending(path: "altro")
        try fm.createDirectory(at: old, withIntermediateDirectories: true)
        try fm.createDirectory(at: other, withIntermediateDirectories: true)
        let cutoff = Date()
        let fresh = dir.appending(path: "tryon-features-NEW")
        try fm.createDirectory(at: fresh, withIntermediateDirectories: true)
        try fm.setAttributes([.creationDate: cutoff.addingTimeInterval(-60), .modificationDate: cutoff.addingTimeInterval(-60)],
                             ofItemAtPath: old.path)
        try fm.setAttributes([.creationDate: cutoff.addingTimeInterval(5), .modificationDate: cutoff.addingTimeInterval(5)],
                             ofItemAtPath: fresh.path)
        RealisticAvatarModel.removeStaleWorkFolders(in: dir, olderThan: cutoff)
        XCTAssertFalse(fm.fileExists(atPath: old.path))
        XCTAssertTrue(fm.fileExists(atPath: fresh.path), "quella della generazione in corso resta")
        XCTAssertTrue(fm.fileExists(atPath: other.path), "il resto della cartella non si tocca")
    }

    func testCacheFileNameIsSafe() async {
        let odd = AvatarItem(id: "../a b/c", category: "top", slot: "top", photo: "", name: "X")
        await cache.store(Self.solid(4, 4), item: odd, view: .side, bodyKey: "body-side-xyz")
        let files = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        XCTAssertEqual(files.count, 1)
        XCTAssertTrue(files.allSatisfy { !$0.contains("/") && !$0.contains(" ") && !$0.hasPrefix(".") }, "\(files)")
        XCTAssertTrue(files.first?.hasSuffix("-side-body-side-xyz-v1.png") == true, "\(files)")
        let back = await cache.image(item: odd, view: .side, bodyKey: "body-side-xyz")
        XCTAssertNotNil(back)
    }
}
