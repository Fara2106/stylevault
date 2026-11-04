import CoreGraphics
import XCTest
@testable import StyleVault

/// Motore finto: aspetta `delay`, manda l'avanzamento e restituisce un'immagine piena.
/// Come il motore vero carica 7 reti: 4 prima del primo passo, poi le altre in mezzo.
private final class FakeEngine: RealisticTryOn, @unchecked Sendable {
    private let lock = NSLock()
    private var _calls = 0
    var calls: Int { lock.lock(); defer { lock.unlock() }; return _calls }
    let delay: Duration
    let error: Error?
    /// Chiamato a metà calcolo (i test guardano il segno "in corso")
    var midway: (@Sendable () -> Void)?

    init(delay: Duration = .milliseconds(150), error: Error? = nil) {
        self.delay = delay; self.error = error
    }

    func generate(person: CGImage, garment: CGImage, item: AvatarItem,
                  progress: @Sendable (TryOnProgress) -> Void) async throws -> CGImage {
        lock.lock(); _calls += 1; lock.unlock()
        var loaded = 0
        func load() async throws {
            try await Task.sleep(for: delay / 20)
            try Task.checkCancellation()
            loaded += 1
            progress(TryOnProgress(fraction: 0, loaded: loaded))
        }
        for _ in 0..<4 { try await load() }
        progress(TryOnProgress(fraction: 0.1, loaded: loaded))
        // Come il motore vero: si ferma tra un passo e l'altro se annullato
        for step in 1...10 {
            if step == 2 || step == 6 { try await load() }
            if step == 5 { midway?() }
            try await Task.sleep(for: delay / 10)
            try Task.checkCancellation()
            if step == 10 { try await load() }
            progress(TryOnProgress(fraction: Double(step) / 10, loaded: loaded))
        }
        if let error { throw error }
        return RealisticAvatarModelTests.solid(person.width, person.height)
    }
}

/// Motore lento come quello vero: una "rete" non si interrompe a metà (attesa che
/// ignora l'annullamento), si controlla solo tra una rete e l'altra. Conta quante
/// generazioni girano insieme.
private final class StubbornEngine: RealisticTryOn, @unchecked Sendable {
    private let lock = NSLock()
    private var active = 0, _maxActive = 0, _calls = 0
    var maxActive: Int { lock.lock(); defer { lock.unlock() }; return _maxActive }
    var calls: Int { lock.lock(); defer { lock.unlock() }; return _calls }

    func generate(person: CGImage, garment: CGImage, item: AvatarItem,
                  progress: @Sendable (TryOnProgress) -> Void) async throws -> CGImage {
        lock.lock(); active += 1; _calls += 1; _maxActive = max(_maxActive, active); lock.unlock()
        defer { lock.lock(); active -= 1; lock.unlock() }
        for step in 1...3 {
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.15) { c.resume() }
            }
            try Task.checkCancellation()
            progress(TryOnProgress(fraction: Double(step) / 3))
        }
        return RealisticAvatarModelTests.solid(person.width, person.height)
    }
}

/// Store finto: conta le chiamate; se non è pronto, "scarica" e "prepara" in un attimo.
private final class FakeStore: RealisticModelPreparing, @unchecked Sendable {
    private let lock = NSLock()
    private var ready: Bool
    private var _readyChecks = 0, _prepares = 0, _removals = 0
    private var _allows = [Bool](), _invalidated = [String]()
    let failure: ModelStoreError?
    /// Rete a consumo: senza permesso lo scarico fallisce con .expensiveNetwork
    let expensive: Bool
    var readyChecks: Int { lock.lock(); defer { lock.unlock() }; return _readyChecks }
    var prepares: Int { lock.lock(); defer { lock.unlock() }; return _prepares }
    var removals: Int { lock.lock(); defer { lock.unlock() }; return _removals }
    var allows: [Bool] { lock.lock(); defer { lock.unlock() }; return _allows }
    var invalidated: [String] { lock.lock(); defer { lock.unlock() }; return _invalidated }

    init(ready: Bool, failure: ModelStoreError? = nil, expensive: Bool = false) {
        self.ready = ready; self.failure = failure; self.expensive = expensive
    }

    var isReady: Bool {
        get async { lock.lock(); defer { lock.unlock() }; _readyChecks += 1; return ready }
    }

    func invalidate(_ name: String) async {
        lock.lock(); _invalidated.append(name); ready = false; lock.unlock()
    }

    func removeAll() async {
        lock.lock(); _removals += 1; ready = false; lock.unlock()
    }

    func prepare(allowsExpensiveNetwork: Bool,
                 progress: @escaping @Sendable (ModelStoreProgress) -> Void) async throws {
        lock.lock(); _prepares += 1; _allows.append(allowsExpensiveNetwork); lock.unlock()
        if let failure { throw failure }
        if expensive, !allowsExpensiveNetwork { throw ModelStoreError.expensiveNetwork }
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
    private var defaults: UserDefaults!
    private var suite: String!
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
        suite = "realistic-test-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: folder)
        defaults.removePersistentDomain(forName: suite)
    }

    private func model(engine: RealisticTryOn?, store: FakeStore? = FakeStore(ready: true),
                       supported: Bool = true, launch: UUID = RealisticAvatarModel.launch) -> RealisticAvatarModel {
        RealisticAvatarModel(engine: engine, store: store, supported: supported, cache: cache,
                             defaults: defaults, launch: launch)
    }

    private func start(_ m: RealisticAvatarModel, _ view: BodyView, allowsExpensiveNetwork: Bool = false) async {
        await m.start(view, person: person, garment: garment, item: item, bodyKey: "body-\(view.rawValue)-abc",
                      allowsExpensiveNetwork: allowsExpensiveNetwork)
    }

    /// Il segno lasciato da un avvio precedente che iOS ha chiuso durante il calcolo.
    private func leaveMarkerFromAnotherLaunch() {
        defaults.set(["view": "front", "at": Date().timeIntervalSince1970, "launch": UUID().uuidString],
                     forKey: RealisticAvatarModel.Keys.inProgress)
    }

    private var marker: [String: Any]? { defaults.dictionary(forKey: RealisticAvatarModel.Keys.inProgress) }
    private var interruptions: Int { defaults.integer(forKey: RealisticAvatarModel.Keys.interruptions) }

    /// Aspetta (al massimo 3 s) che la condizione sia vera.
    private func wait(_ condition: () -> Bool) async throws {
        for _ in 0..<300 where !condition() { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(condition(), "condizione mai raggiunta")
    }

    private func isGenerating(_ state: RealisticState?) -> Bool {
        switch state {
        case .generating?, .warming?: return true
        default: return false
        }
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

    func testRestartAfterCancelWaitsForTheStoppedEngine() async throws {
        let engine = StubbornEngine()
        let m = model(engine: engine)
        let first = Task { await start(m, .front) }
        try await wait { isGenerating(m.state[.front]) && engine.calls == 1 }
        m.cancelAll()
        XCTAssertEqual(m.state[.front], .collage)
        // Ripartenza immediata (ritorno dal background, "Riprova"): aspetta che la rete in corso finisca
        await start(m, .front)
        await first.value
        XCTAssertEqual(m.state[.front], .ready)
        XCTAssertEqual(engine.calls, 2)
        XCTAssertEqual(engine.maxActive, 1, "mai due generazioni insieme")
        XCTAssertFalse(m.isBusy)
    }

    func testReleaseImageKeepsReady() async {
        let m = model(engine: FakeEngine())
        await start(m, .front)
        m.releaseImage(.front)
        XCTAssertNil(m.images[.front])
        XCTAssertEqual(m.state[.front], .ready)
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
            case .warming?: if seen.last != "w" { seen.append("w") }
            default: break
            }
            if m.state[.front] == .ready || seen.count > 10 { break }
            try await Task.sleep(for: .milliseconds(5))
        }
        await run.value
        // Primo uso: dopo lo scarico la prima generazione prepara il motore
        XCTAssertEqual(seen, ["d", "p", "w"])
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
        XCTAssertEqual(RealisticAvatarModel.text(for: .warming(done: 3, total: 7, fraction: 0.2)),
                       "Preparo il motore, solo la prima volta… 3/7")
        XCTAssertNil(RealisticAvatarModel.text(for: .ready))
        XCTAssertNil(RealisticAvatarModel.text(for: .needsNetworkConsent))
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
        XCTAssertTrue(files.first?.contains("-side-body-side-xyz-") == true, "\(files)")
        XCTAssertTrue(files.first?.hasSuffix(".png") == true, "\(files)")
        let back = await cache.image(item: odd, view: .side, bodyKey: "body-side-xyz")
        XCTAssertNotNil(back)
    }

    // MARK: - I2: chiusura per memoria durante il calcolo

    func testMarkerDuringGenerationClearedOnSuccess() async throws {
        let engine = FakeEngine(delay: .milliseconds(300))
        let seen = Locked<[String: Any]?>(nil)
        let suite = suite!
        engine.midway = { seen.mutate { $0 = UserDefaults(suiteName: suite)?.dictionary(forKey: RealisticAvatarModel.Keys.inProgress) } }
        let m = model(engine: engine)
        await start(m, .front)
        XCTAssertEqual(m.state[.front], .ready)
        let during = try XCTUnwrap(seen.value, "durante il calcolo il segno c'è")
        XCTAssertEqual(during["view"] as? String, "front")
        XCTAssertNotNil(during["at"] as? Double)
        XCTAssertEqual(during["launch"] as? String, RealisticAvatarModel.launch.uuidString)
        XCTAssertNil(marker, "tolto a calcolo riuscito")
        XCTAssertEqual(interruptions, 0)
    }

    func testMarkerClearedOnFailureAndCancel() async throws {
        let failing = model(engine: FakeEngine(error: TryOnError.image))
        await start(failing, .front)
        guard case .failed = failing.state[.front] else { return XCTFail("atteso .failed") }
        XCTAssertNil(marker, "tolto dopo un errore")

        let slow = model(engine: FakeEngine(delay: .seconds(2)))
        let run = Task { await start(slow, .side) }
        try await wait { self.marker != nil }
        slow.cancelAll()
        await run.value
        XCTAssertNil(marker, "tolto dopo l'annullamento")
    }

    func testMarkerFromPreviousLaunchStopsAutoStart() async {
        leaveMarkerFromAnotherLaunch()
        let m = model(engine: FakeEngine())
        XCTAssertTrue(m.wasInterrupted)
        XCTAssertFalse(m.autoStartAllowed, "niente partenza da sola dopo una chiusura")
        XCTAssertNil(marker, "il segno si conta una volta sola")
        XCTAssertEqual(interruptions, 1)
        // Alla riapertura seguente (senza nuova chiusura) si riparte da soli
        let next = model(engine: FakeEngine())
        XCTAssertFalse(next.wasInterrupted)
        XCTAssertTrue(next.autoStartAllowed)
        // "Riprova" a mano funziona sempre
        await start(m, .front)
        XCTAssertEqual(m.state[.front], .ready)
    }

    func testMarkerOfThisLaunchIsNotAnInterruption() {
        let launch = UUID()
        defaults.set(["view": "front", "at": Date().timeIntervalSince1970, "launch": launch.uuidString],
                     forKey: RealisticAvatarModel.Keys.inProgress)
        let m = model(engine: FakeEngine(), launch: launch)
        XCTAssertFalse(m.wasInterrupted, "un calcolo che si sta fermando in questo avvio non è una chiusura")
        XCTAssertTrue(m.autoStartAllowed)
        XCTAssertEqual(interruptions, 0)
    }

    func testTwoInterruptionsDisableAutoStartUntilSuccess() async {
        leaveMarkerFromAnotherLaunch()
        _ = model(engine: FakeEngine())
        leaveMarkerFromAnotherLaunch()
        _ = model(engine: FakeEngine())
        XCTAssertEqual(interruptions, 2)
        let third = model(engine: FakeEngine())
        XCTAssertFalse(third.wasInterrupted)
        XCTAssertFalse(third.autoStartAllowed, "dopo due chiusure di fila resta a mano")
        await start(third, .front)   // Riprova a mano
        XCTAssertEqual(third.state[.front], .ready)
        XCTAssertEqual(interruptions, 0, "un calcolo riuscito azzera il conto")
        XCTAssertTrue(model(engine: FakeEngine()).autoStartAllowed)
    }

    func testUnsupportedIgnoresMarker() {
        leaveMarkerFromAnotherLaunch()
        let m = model(engine: FakeEngine(), supported: false)
        XCTAssertFalse(m.autoStartAllowed)
        XCTAssertFalse(m.wasInterrupted)
        XCTAssertEqual(interruptions, 0)
    }

    // MARK: - I3: barra durante la prima preparazione del motore

    func testFirstGenerationShowsEngineWarmupThenNormalProgress() async throws {
        let m = model(engine: FakeEngine(delay: .milliseconds(400)))
        var bars = [Double](), texts = [String]()
        let run = Task { await start(m, .front) }
        for _ in 0..<2000 where m.state[.front] != .ready {
            if let state = m.state[.front], let f = RealisticAvatarModel.fraction(for: state),
               let t = RealisticAvatarModel.text(for: state) {
                if bars.last != f { bars.append(f) }
                if texts.last != t { texts.append(t) }
            }
            try await Task.sleep(for: .milliseconds(2))
        }
        await run.value
        XCTAssertEqual(bars, bars.sorted(), "la barra non scende mai: \(bars)")
        XCTAssertGreaterThan(bars.count, 4, "la barra si muove anche mentre si caricano le reti: \(bars)")
        XCTAssertTrue(texts.allSatisfy { $0.hasPrefix("Preparo il motore, solo la prima volta… ") }, "\(texts)")
        XCTAssertTrue(texts.contains("Preparo il motore, solo la prima volta… 1/7"), "\(texts)")
        XCTAssertTrue(defaults.bool(forKey: RealisticAvatarModel.Keys.warmed))

        // Dalla seconda volta la barra normale
        var later = [String]()
        let second = Task { await start(m, .side) }
        for _ in 0..<2000 where m.state[.side] != .ready {
            if let state = m.state[.side], let t = RealisticAvatarModel.text(for: state), later.last != t { later.append(t) }
            try await Task.sleep(for: .milliseconds(2))
        }
        await second.value
        XCTAssertFalse(later.isEmpty)
        XCTAssertTrue(later.allSatisfy { $0.hasPrefix("Versione realistica… ") }, "\(later)")
    }

    func testWarmingBarIsMonotonicAndEndsAtOne() {
        // Come il motore vero: 4 reti, fase 1, rete del capo, 10 passi, Denoiser, 10 passi, decoder
        var events: [(Int, Double)] = (0...4).map { ($0, 0) } + [(4, 0.05), (5, 0.05)]
        events += (1...10).map { (5, 0.05 + Double($0) / 100) } + [(6, 0.15)]
        events += (1...10).map { (6, 0.15 + Double($0) * 0.08) } + [(7, 0.95), (7, 1)]
        let bars = events.map { RealisticAvatarModel.fraction(for: .warming(done: $0.0, total: 7, fraction: $0.1))! }
        for (a, b) in zip(bars, bars.dropFirst()) { XCTAssertGreaterThan(b, a, "ogni aggiornamento fa avanzare la barra") }
        XCTAssertEqual(bars.first, 0)
        XCTAssertEqual(bars.last ?? 0, 1, accuracy: 1e-9)
    }

    // MARK: - I4: rete a consumo

    func testExpensiveNetworkAsksConsentThenDownloads() async {
        let store = FakeStore(ready: false, expensive: true)
        let m = model(engine: FakeEngine(), store: store)
        await start(m, .front)
        XCTAssertEqual(m.state[.front], .needsNetworkConsent)
        XCTAssertFalse(m.isBusy)
        XCTAssertNil(m.images[.front])
        // "Scarica comunque"
        await start(m, .front, allowsExpensiveNetwork: true)
        XCTAssertEqual(m.state[.front], .ready)
        XCTAssertEqual(store.allows, [false, true])
    }

    // MARK: - M3: modello rovinato

    func testLoadFailureInvalidatesModelAndRebuildsEngine() async {
        let store = FakeStore(ready: true)
        let makes = Locked(0)
        let broken = FakeEngine(error: TryOnError.loadFailed("Denoiser"))
        let good = FakeEngine()
        let m = RealisticAvatarModel(store: store, supported: true, cache: cache, defaults: defaults) {
            makes.mutate { $0 += 1 }
            return makes.value == 1 ? broken : good
        }
        await start(m, .front)
        XCTAssertEqual(m.state[.front], .failed("Un modello non si carica: con Riprova lo riscarico."))
        XCTAssertEqual(store.invalidated, ["Denoiser"])
        // Riprova: lo store non è più pronto, si riprepara e si rifà il motore
        await start(m, .front)
        XCTAssertEqual(m.state[.front], .ready)
        XCTAssertEqual(store.prepares, 1)
        XCTAssertEqual(makes.value, 2)
    }

    func testCompileFailedMessage() {
        XCTAssertEqual(RealisticAvatarModel.message(for: ModelStoreError.compileFailed("Denoiser")),
                       "I modelli non funzionano su questo iPhone: serve iOS 18.")
    }

    // MARK: - M5: elimina i modelli

    func testRemoveModelsResetsToCollage() async {
        let store = FakeStore(ready: true)
        let m = model(engine: FakeEngine(), store: store)
        await start(m, .front)
        XCTAssertEqual(m.state[.front], .ready)
        XCTAssertTrue(defaults.bool(forKey: RealisticAvatarModel.Keys.warmed))
        await m.removeModels()
        XCTAssertEqual(store.removals, 1)
        for view in BodyView.allCases { XCTAssertEqual(m.state[view], .collage) }
        XCTAssertTrue(m.images.isEmpty)
        XCTAssertFalse(defaults.bool(forKey: RealisticAvatarModel.Keys.warmed), "il motore va ripreparato")
        XCTAssertFalse(m.isBusy)
    }

    func testRemoveModelsIgnoredWhileGenerating() async throws {
        let store = FakeStore(ready: true)
        let m = model(engine: FakeEngine(delay: .milliseconds(400)), store: store)
        let run = Task { await start(m, .front) }
        try await wait { isGenerating(m.state[.front]) }
        await m.removeModels()
        XCTAssertEqual(store.removals, 0)
        await run.value
        XCTAssertEqual(m.state[.front], .ready)
    }

    // MARK: - M4: chiave della cache

    func testCacheKeyFollowsGarmentPhotoAndDescriptor() async {
        let base = AvatarItem(id: "c1", category: "top", slot: "top",
                              photo: "https://cdn.example.com/items/a.jpg?token=1", name: "M", descriptor: "cream sweater")
        let sameStable = AvatarItem(id: "c1", category: "top", slot: "top",
                                    photo: "https://cdn.example.com/items/a.jpg?token=2", name: "M", descriptor: "cream sweater")
        let newPhoto = AvatarItem(id: "c1", category: "top", slot: "top",
                                  photo: "https://cdn.example.com/items/b.jpg", name: "M", descriptor: "cream sweater")
        let newDescriptor = AvatarItem(id: "c1", category: "top", slot: "top",
                                       photo: "https://cdn.example.com/items/a.jpg?token=1", name: "M", descriptor: "red sweater")
        let key = { (i: AvatarItem) in RealisticCache.key(item: i, view: .front, bodyKey: "body-front-x") }
        XCTAssertEqual(key(base), key(sameStable), "il token dell'indirizzo cambia ma la foto è la stessa")
        XCTAssertNotEqual(key(base), key(newPhoto))
        XCTAssertNotEqual(key(base), key(newDescriptor))
        XCTAssertTrue(key(base).hasPrefix("c1-front-body-front-x-"))
        XCTAssertFalse(RealisticCache.modelVersion.isEmpty)
        XCTAssertTrue(RealisticCache.cutoutKey(item: base, view: .front, bodyKey: "body-front-x").hasSuffix(key(base)))

        await cache.store(Self.solid(4, 4), item: base, view: .front, bodyKey: "body-front-x")
        let hit = await cache.image(item: sameStable, view: .front, bodyKey: "body-front-x")
        XCTAssertNotNil(hit)
        let miss1 = await cache.image(item: newPhoto, view: .front, bodyKey: "body-front-x")
        let miss2 = await cache.image(item: newDescriptor, view: .front, bodyKey: "body-front-x")
        XCTAssertNil(miss1, "foto del capo cambiata: si rigenera")
        XCTAssertNil(miss2, "descrizione cambiata: si rigenera")
    }

    func testCacheKeyUsesBackPhotoForBackView() {
        let a = AvatarItem(id: "c", category: "top", slot: "top", photo: "https://x.com/a.jpg", name: "M",
                           photoBack: "https://x.com/back1.jpg")
        let b = AvatarItem(id: "c", category: "top", slot: "top", photo: "https://x.com/a.jpg", name: "M",
                           photoBack: "https://x.com/back2.jpg")
        XCTAssertEqual(RealisticCache.key(item: a, view: .front, bodyKey: "k"), RealisticCache.key(item: b, view: .front, bodyKey: "k"))
        XCTAssertNotEqual(RealisticCache.key(item: a, view: .back, bodyKey: "k"), RealisticCache.key(item: b, view: .back, bodyKey: "k"))
    }
}
