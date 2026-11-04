import AppleArchive
import CryptoKit
import System
import XCTest
@testable import StyleVault

/// Rete finta: serve gli archivi in memoria e registra le richieste.
/// L'interruzione è una risposta che promette più byte (Content-Length) di quanti ne consegna.
final class FakeModelServer: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var files: [String: Data] = [:]
    nonisolated(unsafe) static var requests: [URLRequest] = []
    /// Se valorizzato: i primi `interruptTimes` scarichi di questo file si interrompono dopo `count` byte
    nonisolated(unsafe) static var interrupt: (name: String, count: Int)?
    nonisolated(unsafe) static var interruptTimes = 1
    /// Errori di rete da dare alle prossime richieste di un file, uno per richiesta
    nonisolated(unsafe) static var failures: [String: [URLError.Code]] = [:]
    /// Rete a consumo: le richieste che non la permettono falliscono come fa iOS
    nonisolated(unsafe) static var expensive = false
    nonisolated(unsafe) static var ignoreRange = false
    nonisolated(unsafe) static var rangeNotSatisfiable = false
    /// Se valorizzato, le richieste di `gatedName` restano ferme finché non si fa `signal()`
    nonisolated(unsafe) static var gate: DispatchSemaphore?
    nonisolated(unsafe) static var gatedName = "Denoiser.aar"
    private static let lock = NSLock()

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        files = [:]; requests = []; interrupt = nil; ignoreRange = false; rangeNotSatisfiable = false
        gate = nil; interruptTimes = 1; failures = [:]; expensive = false
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        Self.lock.lock()
        Self.requests.append(request)
        let name = request.url?.lastPathComponent ?? ""
        let body = Self.files[name]
        let interrupt = Self.interrupt
        let ignoreRange = Self.ignoreRange
        if let i = interrupt, i.name == name {
            Self.interruptTimes -= 1
            if Self.interruptTimes <= 0 { Self.interrupt = nil }
        }
        var failure: URLError.Code?
        if var list = Self.failures[name], !list.isEmpty { failure = list.removeFirst(); Self.failures[name] = list }
        let expensive = Self.expensive
        Self.lock.unlock()

        if expensive, !request.allowsExpensiveNetworkAccess {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet, userInfo: [
                NSURLErrorNetworkUnavailableReasonKey: URLError.NetworkUnavailableReason.expensive.rawValue]))
            return
        }
        if let failure {
            client?.urlProtocol(self, didFailWithError: URLError(failure))
            return
        }

        if name == Self.gatedName, let gate = Self.gate { _ = gate.wait(timeout: .now() + 20) }
        guard let body else {
            respond(status: 404, data: Data(), headers: [:]); return
        }
        if Self.rangeNotSatisfiable, request.value(forHTTPHeaderField: "Range") != nil {
            respond(status: 416, data: Data(), headers: [:]); return
        }
        var start = 0
        var status = 200
        if !ignoreRange, let range = request.value(forHTTPHeaderField: "Range"),
           let n = Int(range.dropFirst("bytes=".count).dropLast()) {
            start = n; status = 206
        }
        let slice = body.suffix(from: start)
        if let i = interrupt, i.name == name {
            let part = slice.prefix(i.count)
            respond(status: status, data: Data(part), headers: ["Content-Length": "\(slice.count)"])
        } else {
            respond(status: status, data: Data(slice), headers: [:])
        }
    }

    private func respond(status: Int, data: Data, headers: [String: String]) {
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
}

final class RealisticModelStoreTests: XCTestCase {
    private var root: URL!
    private var folder: URL!
    private let baseURL = URL(string: "https://example.test/models/")!

    override func setUpWithError() throws {
        FakeModelServer.reset()
        root = FileManager.default.temporaryDirectory.appending(path: "RMS-\(UUID().uuidString)", directoryHint: .isDirectory)
        folder = root.appending(path: "RealisticModels", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    // MARK: - Aiuti

    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FakeModelServer.self]
        return URLSession(configuration: config)
    }

    /// Crea un .aar con i file indicati (percorso relativo -> contenuto).
    private func makeArchive(_ files: [String: String]) throws -> Data {
        let src = root.appending(path: "src-\(UUID().uuidString)", directoryHint: .isDirectory)
        for (path, content) in files {
            let url = src.appending(path: path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(content.utf8).write(to: url)
        }
        let aar = root.appending(path: "\(UUID().uuidString).aar")
        let file = try XCTUnwrap(ArchiveByteStream.fileStream(
            path: FilePath(aar.path), mode: .writeOnly, options: [.create], permissions: FilePermissions(rawValue: 0o644)))
        let compress = try XCTUnwrap(ArchiveByteStream.compressionStream(using: .lzfse, writingTo: file))
        let encode = try XCTUnwrap(ArchiveStream.encodeStream(writingTo: compress))
        let keys = try XCTUnwrap(ArchiveHeader.FieldKeySet("TYP,PAT,DAT,SIZ"))
        try encode.writeDirectoryContents(archiveFrom: FilePath(src.path), keySet: keys)
        try encode.close(); try compress.close(); try file.close()
        return try Data(contentsOf: aar)
    }

    private func sha(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Pubblica nel server finto due modelli piccoli + tokenizzatore. Torna il manifest.
    @discardableResult
    private func publish(names: [String] = ["Denoiser", "VAEDecoder"], badHash: Bool = false,
                         declaredBytes: Int64? = nil, extraEntry: String? = nil) throws -> [[String: Any]] {
        var entries: [[String: Any]] = []
        for name in names {
            let data = try makeArchive(["Manifest.json": "{\"m\":\"\(name)\"}", "Data/weights.bin": String(repeating: name, count: 4000)])
            FakeModelServer.files["\(name).aar"] = data
            entries.append(["name": "\(name).aar", "bytes": declaredBytes ?? Int64(data.count),
                            "sha256": badHash ? String(repeating: "0", count: 64) : sha(data)])
        }
        let tok = try makeArchive(["vocab.json": "{}", "merges.txt": "a b"])
        FakeModelServer.files["Tokenizer.aar"] = tok
        entries.append(["name": "Tokenizer.aar", "bytes": Int64(tok.count), "sha256": sha(tok)])
        if let extraEntry {
            entries.append(["name": extraEntry, "bytes": 10, "sha256": String(repeating: "a", count: 64)])
        }
        let manifest: [String: Any] = ["version": 1, "files": entries]
        FakeModelServer.files["models-manifest.json"] = try JSONSerialization.data(withJSONObject: manifest)
        return entries
    }

    /// Compilazione finta: rinomina la cartella in .mlmodelc.
    private let fakeCompile: @Sendable (URL) async throws -> URL = { url in
        let out = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).mlmodelc", directoryHint: .isDirectory)
        try FileManager.default.copyItem(at: url, to: out)
        return out
    }

    /// Attese chieste dallo store prima di riprovare (nessuna attesa vera).
    private let sleeps = Locked<[Duration]>([])

    private func makeStore(freeSpace: @escaping @Sendable () -> Int64 = { Int64.max },
                           compile: (@Sendable (URL) async throws -> URL)? = nil,
                           retryDelays: [Duration] = [.seconds(1), .seconds(3)]) -> RealisticModelStore {
        let sleeps = sleeps
        return RealisticModelStore(baseURL: baseURL, folder: folder, session: makeSession(),
                                   freeSpace: freeSpace, compile: compile ?? fakeCompile,
                                   retryDelays: retryDelays, sleep: { d in sleeps.mutate { $0.append(d) } })
    }

    private func archiveExists(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: folder.appending(path: "downloads/\(name)").path)
    }

    // MARK: - Test

    func testUnsupportedDevices() {
        XCTAssertFalse(RealisticSupport.isSupported(physicalMemory: 6_000_000_000, isSimulator: false, hasIOS18: true))
        XCTAssertFalse(RealisticSupport.isSupported(physicalMemory: 8_000_000_000, isSimulator: true, hasIOS18: true))
        XCTAssertTrue(RealisticSupport.isSupported(physicalMemory: 8_000_000_000, isSimulator: false, hasIOS18: true))
    }

    func testIOS17NonSupportato() {
        // 8 GB su iOS 17: i modelli non si compilerebbero, niente scarico
        XCTAssertFalse(RealisticSupport.isSupported(physicalMemory: 8_000_000_000, isSimulator: false, hasIOS18: false))
        XCTAssertEqual(RealisticSupport.requirement, "La versione realistica richiede iPhone 15 Pro o successivo con iOS 18")
        #if targetEnvironment(simulator)
        XCTAssertFalse(RealisticSupport.current)
        #endif
    }

    func testPreparazioneCompletaEIsReady() async throws {
        try publish()
        let store = makeStore()
        let before = await store.isReady
        XCTAssertFalse(before)
        try await store.prepare { _ in }
        let ready = await store.isReady
        XCTAssertTrue(ready)
        let denoiser = store.modelURL("Denoiser")
        XCTAssertEqual(denoiser?.lastPathComponent, "Denoiser.mlmodelc")
        let missing = store.modelURL("Altro")
        XCTAssertNil(missing)
        let tok = store.tokenizerFiles()
        XCTAssertEqual(try String(contentsOf: XCTUnwrap(tok).vocab), "{}")
        XCTAssertEqual(try String(contentsOf: XCTUnwrap(tok).merges), "a b")
        // Gli archivi estratti non restano
        let left = try FileManager.default.contentsOfDirectory(atPath: folder.appending(path: "downloads").path)
        XCTAssertTrue(left.isEmpty, "\(left)")
        let excluded = try folder.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup
        XCTAssertEqual(excluded, true)
    }

    func testHashMismatchDeletesFile() async throws {
        try publish(badHash: true)
        let store = makeStore()
        do {
            try await store.prepare { _ in }
            XCTFail("doveva fallire")
        } catch {
            XCTAssertEqual(error as? ModelStoreError, .corrupted("Denoiser.aar"))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appending(path: "downloads/Denoiser.aar").path))
        let ready = await store.isReady
        XCTAssertFalse(ready)
    }

    func testResumesAfterInterruption() async throws {
        let entries = try publish(names: ["Denoiser"])
        // Senza nuovi tentativi: si riprende alla preparazione seguente
        let store = makeStore(retryDelays: [])
        let full = try XCTUnwrap(FakeModelServer.files["Denoiser.aar"])
        FakeModelServer.interrupt = ("Denoiser.aar", full.count / 2)
        do {
            try await store.prepare { _ in }
            XCTFail("doveva fallire")
        } catch {
            XCTAssertEqual(error as? ModelStoreError, .network)
        }
        let partSize = try XCTUnwrap(FileManager.default.attributesOfItem(
            atPath: folder.appending(path: "downloads/Denoiser.aar.part").path)[.size] as? Int)
        XCTAssertEqual(partSize, full.count / 2)

        try await store.prepare { _ in }
        let ranges = FakeModelServer.requests
            .filter { $0.url?.lastPathComponent == "Denoiser.aar" }
            .map { $0.value(forHTTPHeaderField: "Range") }
        XCTAssertEqual(ranges.last ?? nil, "bytes=\(partSize)-")
        let ready = await store.isReady
        XCTAssertTrue(ready)
        XCTAssertEqual(entries.count, 2)
    }

    func testServerCheIgnoraRangeRiparteDaZero() async throws {
        try publish(names: ["Denoiser"])
        let store = makeStore()
        let full = try XCTUnwrap(FakeModelServer.files["Denoiser.aar"])
        FakeModelServer.interrupt = ("Denoiser.aar", full.count / 3)
        let first = makeStore(retryDelays: [])
        _ = try? await first.prepare { _ in }
        FakeModelServer.ignoreRange = true
        try await store.prepare { _ in }
        let ready = await store.isReady
        XCTAssertTrue(ready)
    }

    func testNotEnoughSpace() async throws {
        try publish(declaredBytes: 1_000_000_000)
        let store = makeStore(freeSpace: { 1_000_000_000 })
        do {
            try await store.prepare { _ in }
            XCTFail("doveva fallire")
        } catch {
            guard case .notEnoughSpace(let mb)? = error as? ModelStoreError else { return XCTFail("\(error)") }
            // 2 modelli da 1 GB dichiarati + tokenizzatore reale ≈ 2 GB × 2,5
            XCTAssertGreaterThan(mb, 4_700)
        }
        // Nessun archivio scaricato
        XCTAssertFalse(FakeModelServer.requests.contains { $0.url?.lastPathComponent == "Denoiser.aar" })
    }

    func testProgressIsMonotonic() async throws {
        try publish()
        let store = makeStore()
        let events = Locked<[ModelStoreProgress]>([])
        try await store.prepare { p in events.mutate { $0.append(p) } }
        var lastDone: Int64 = -1
        var lastTotal: Int64 = 0
        var lastModels = -1
        for event in events.value {
            switch event {
            case .downloading(let done, let total):
                XCTAssertGreaterThanOrEqual(done, lastDone)
                lastDone = done; lastTotal = total
            case .preparing(let done, let total):
                XCTAssertGreaterThanOrEqual(done, lastModels)
                lastModels = done
                XCTAssertEqual(total, 3)
            }
        }
        XCTAssertGreaterThan(lastTotal, 0)
        XCTAssertEqual(lastDone, lastTotal)
        XCTAssertEqual(lastModels, 3)
    }

    func testConcurrentPrepareDownloadsOnce() async throws {
        try publish()
        let store = makeStore()
        async let a: Void = store.prepare { _ in }
        async let b: Void = store.prepare { _ in }
        try await a
        try await b
        for name in ["Denoiser.aar", "VAEDecoder.aar", "Tokenizer.aar"] {
            let count = FakeModelServer.requests.filter { $0.url?.lastPathComponent == name }.count
            XCTAssertEqual(count, 1, name)
        }
        let ready = await store.isReady
        XCTAssertTrue(ready)
    }

    func testManifestChangeRedownloads() async throws {
        try publish()
        let store = makeStore()
        try await store.prepare { _ in }
        let oldOutputURL = store.modelURL("Denoiser")
        let oldOutput = try String(contentsOf: XCTUnwrap(oldOutputURL).appending(path: "Manifest.json"))
        // Nuova versione di Denoiser: altro corpo, altro hash
        let data = try makeArchive(["Manifest.json": "{\"m\":\"nuovo\"}", "Data/weights.bin": "xyz"])
        FakeModelServer.files["Denoiser.aar"] = data
        var manifest = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(FakeModelServer.files["models-manifest.json"])) as? [String: Any])
        var files = try XCTUnwrap(manifest["files"] as? [[String: Any]])
        let i = try XCTUnwrap(files.firstIndex { ($0["name"] as? String) == "Denoiser.aar" })
        files[i]["bytes"] = Int64(data.count); files[i]["sha256"] = sha(data)
        manifest["files"] = files
        FakeModelServer.files["models-manifest.json"] = try JSONSerialization.data(withJSONObject: manifest)
        FakeModelServer.requests = []
        try await store.prepare { _ in }
        let archives = FakeModelServer.requests.compactMap { $0.url?.lastPathComponent }.filter { $0.hasSuffix(".aar") }
        XCTAssertEqual(archives, ["Denoiser.aar"])
        let newOutputURL = store.modelURL("Denoiser")
        let newOutput = try String(contentsOf: XCTUnwrap(newOutputURL).appending(path: "Manifest.json"))
        XCTAssertNotEqual(oldOutput, newOutput)
        XCTAssertTrue(newOutput.contains("nuovo"))
    }

    func testRange416Restarts() async throws {
        try publish(names: ["Denoiser"])
        let store = makeStore()
        // .part vecchio e più corto del file: il server risponde 416 alla Range
        try FileManager.default.createDirectory(at: folder.appending(path: "downloads"), withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: folder.appending(path: "downloads/Denoiser.aar.part"))
        FakeModelServer.rangeNotSatisfiable = true
        try await store.prepare { _ in }
        let ranges = FakeModelServer.requests.filter { $0.url?.lastPathComponent == "Denoiser.aar" }
            .map { $0.value(forHTTPHeaderField: "Range") }
        XCTAssertEqual(ranges.count, 2)
        XCTAssertEqual(ranges[0], "bytes=3-")
        XCTAssertNil(ranges[1])
        let ready = await store.isReady
        XCTAssertTrue(ready)
    }

    /// Cambia hash e corpo di un archivio e aggiorna il manifest servito.
    private func republish(_ name: String, marker: String) throws {
        let data = try makeArchive(["Manifest.json": "{\"m\":\"\(marker)\"}", "Data/weights.bin": marker])
        FakeModelServer.files[name] = data
        var manifest = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(FakeModelServer.files["models-manifest.json"])) as? [String: Any])
        var files = try XCTUnwrap(manifest["files"] as? [[String: Any]])
        let i = try XCTUnwrap(files.firstIndex { ($0["name"] as? String) == name })
        files[i]["bytes"] = Int64(data.count); files[i]["sha256"] = sha(data)
        manifest["files"] = files
        FakeModelServer.files["models-manifest.json"] = try JSONSerialization.data(withJSONObject: manifest)
    }

    private func requestCount(_ name: String) -> Int {
        FakeModelServer.requests.filter { $0.url?.lastPathComponent == name }.count
    }

    func testLateWaiterDoesNotClearNewRun() async throws {
        try publish()
        let store = makeStore()
        // Prima preparazione con due chiamanti (A e B)
        let a = Task { try await store.prepare { _ in } }
        let b = Task { try await store.prepare { _ in } }
        try await a.value
        // Nuova versione di Denoiser: C avvia una seconda preparazione, ferma sul cancello
        try republish("Denoiser.aar", marker: "v2")
        FakeModelServer.gate = DispatchSemaphore(value: 0)
        let events = Locked<[ModelStoreProgress]>([])
        let c = Task { try await store.prepare { p in events.mutate { $0.append(p) } } }
        // B torna solo ora (o è già tornato): non deve toccare la seconda preparazione
        try await b.value
        let d = Task { try await store.prepare { _ in } }
        try await Task.sleep(nanoseconds: 300_000_000)
        FakeModelServer.gate?.signal()
        try await c.value
        try await d.value
        XCTAssertEqual(requestCount("Denoiser.aar"), 2, "una per preparazione, mai una terza")
        XCTAssertEqual(requestCount("VAEDecoder.aar"), 1)
        XCTAssertEqual(requestCount("Tokenizer.aar"), 1)
        var lastDone: Int64 = -1, lastTotal: Int64 = 0
        for case .downloading(let done, let total) in events.value { lastDone = done; lastTotal = total }
        XCTAssertGreaterThan(lastTotal, 0)
        XCTAssertEqual(lastDone, lastTotal)
    }

    func testCancelledCallerReturnsWhileDownloadContinues() async throws {
        try publish()
        FakeModelServer.gate = DispatchSemaphore(value: 0)
        let store = makeStore()
        let a = Task { try await store.prepare { _ in } }
        let b = Task { try await store.prepare { _ in } }
        // Aspetta che lo scarico sia partito (e fermo sul cancello)
        for _ in 0..<100 where requestCount("Denoiser.aar") == 0 { try await Task.sleep(nanoseconds: 50_000_000) }
        XCTAssertEqual(requestCount("Denoiser.aar"), 1)
        let start = Date()
        a.cancel()
        do {
            try await a.value
            XCTFail("doveva essere annullato")
        } catch {
            XCTAssertTrue(error is CancellationError, "\(error)")
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 2, "deve smettere di aspettare subito")
        FakeModelServer.gate?.signal()
        try await b.value
        for name in ["Denoiser.aar", "VAEDecoder.aar", "Tokenizer.aar"] {
            XCTAssertEqual(requestCount(name), 1, name)
        }
        let ready = await store.isReady
        XCTAssertTrue(ready)
    }

    func testNomeNelManifestFuoriCartellaERifiutato() async throws {
        for bad in ["../Evil.aar", "a/b.aar", "..aar"] {
            FakeModelServer.reset()
            try publish(extraEntry: bad)
            let store = makeStore()
            do {
                try await store.prepare { _ in }
                XCTFail("doveva fallire per \(bad)")
            } catch {
                XCTAssertEqual(error as? ModelStoreError, .corrupted("models-manifest.json"))
            }
            // Non ha scaricato niente
            XCTAssertFalse(FakeModelServer.requests.contains { $0.url?.lastPathComponent == "Denoiser.aar" })
        }
    }

    // MARK: - M2: nuovi tentativi

    func testInterruzioneRiprovataSubitoDaDoveEraArrivata() async throws {
        try publish(names: ["Denoiser"])
        let full = try XCTUnwrap(FakeModelServer.files["Denoiser.aar"])
        FakeModelServer.interrupt = ("Denoiser.aar", full.count / 2)
        let store = makeStore()
        try await store.prepare { _ in }
        let ready = await store.isReady
        XCTAssertTrue(ready, "una sola preparazione basta")
        let ranges = FakeModelServer.requests.filter { $0.url?.lastPathComponent == "Denoiser.aar" }
            .map { $0.value(forHTTPHeaderField: "Range") }
        XCTAssertEqual(ranges, [nil, "bytes=\(full.count / 2)-"])
        XCTAssertEqual(sleeps.value, [.seconds(1)])
    }

    func testTimeoutRiprovatoDueVoltePoiErrore() async throws {
        try publish(names: ["Denoiser"])
        FakeModelServer.failures["Denoiser.aar"] = [.timedOut, .networkConnectionLost, .timedOut]
        let store = makeStore()
        do {
            try await store.prepare { _ in }
            XCTFail("doveva fallire")
        } catch {
            XCTAssertEqual(error as? ModelStoreError, .network)
        }
        XCTAssertEqual(requestCount("Denoiser.aar"), 3, "il primo tentativo e altri due")
        XCTAssertEqual(sleeps.value, [.seconds(1), .seconds(3)])
        // Al terzo tentativo va: riesce
        FakeModelServer.failures["Denoiser.aar"] = [.timedOut, .timedOut]
        sleeps.mutate { $0 = [] }
        try await store.prepare { _ in }
        let ready = await store.isReady
        XCTAssertTrue(ready)
    }

    func testErroreNonPassaggeroNonRiprovato() async throws {
        try publish(names: ["Denoiser"])
        FakeModelServer.failures["Denoiser.aar"] = [.cannotDecodeRawData]
        let store = makeStore()
        do {
            try await store.prepare { _ in }
            XCTFail("doveva fallire")
        } catch {
            XCTAssertEqual(error as? ModelStoreError, .network)
        }
        XCTAssertEqual(requestCount("Denoiser.aar"), 1)
        XCTAssertEqual(sleeps.value, [])
    }

    // MARK: - I4: rete a consumo

    func testReteAConsumoChiedeIlPermessoPoiScarica() async throws {
        try publish(names: ["Denoiser"])
        FakeModelServer.expensive = true
        let store = makeStore()
        do {
            try await store.prepare { _ in }
            XCTFail("doveva fermarsi")
        } catch {
            XCTAssertEqual(error as? ModelStoreError, .expensiveNetwork)
        }
        XCTAssertFalse(FakeModelServer.requests.contains { $0.allowsExpensiveNetworkAccess || $0.allowsConstrainedNetworkAccess },
                       "lo scarico automatico non usa rete a consumo né Risparmio dati")
        XCTAssertEqual(sleeps.value, [], "non è un errore passeggero")
        // "Scarica comunque"
        try await store.prepare(allowsExpensiveNetwork: true) { _ in }
        let ready = await store.isReady
        XCTAssertTrue(ready)
        let allowed = FakeModelServer.requests.filter { $0.allowsExpensiveNetworkAccess && $0.allowsConstrainedNetworkAccess }
        XCTAssertFalse(allowed.isEmpty)
    }

    func testReteAConsumoDopoIlManifestSalvato() async throws {
        // Manifest già salvato da una volta precedente, archivio da scaricare: serve comunque il permesso
        try publish(names: ["Denoiser"])
        FakeModelServer.failures["Denoiser.aar"] = [.cannotDecodeRawData]
        _ = try? await makeStore().prepare { _ in }
        FakeModelServer.expensive = true
        do {
            try await makeStore().prepare { _ in }
            XCTFail("doveva fermarsi")
        } catch {
            XCTAssertEqual(error as? ModelStoreError, .expensiveNetwork)
        }
    }

    // MARK: - M1: disco pieno

    func testRiconosceDiscoPieno() {
        XCTAssertTrue(RealisticModelStore.isOutOfSpace(NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError)))
        XCTAssertTrue(RealisticModelStore.isOutOfSpace(POSIXError(.ENOSPC)))
        XCTAssertTrue(RealisticModelStore.isOutOfSpace(NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError,
                                                               userInfo: [NSUnderlyingErrorKey: POSIXError(.ENOSPC)])))
        XCTAssertFalse(RealisticModelStore.isOutOfSpace(URLError(.timedOut)))
        XCTAssertFalse(RealisticModelStore.isOutOfSpace(POSIXError(.EACCES)))
    }

    func testDiscoPienoInCompilazioneTieneLArchivio() async throws {
        try publish(names: ["Denoiser"])
        let full: @Sendable (URL) async throws -> URL = { _ in throw POSIXError(.ENOSPC) }
        do {
            try await makeStore(compile: full).prepare { _ in }
            XCTFail("doveva fallire")
        } catch {
            guard case .notEnoughSpace(let mb)? = error as? ModelStoreError else { return XCTFail("\(error)") }
            XCTAssertGreaterThan(mb, 0)
        }
        XCTAssertTrue(archiveExists("Denoiser.aar"), "l'archivio verificato resta")
        // Liberato lo spazio si riprende senza riscaricare
        try await makeStore().prepare { _ in }
        XCTAssertEqual(requestCount("Denoiser.aar"), 1)
        let ready = await makeStore().isReady
        XCTAssertTrue(ready)
    }

    // MARK: - I1: compilazione fallita

    func testCompilazioneFallitaTogleLArchivio() async throws {
        try publish(names: ["Denoiser"])
        let broken: @Sendable (URL) async throws -> URL = { _ in throw NSError(domain: "com.apple.CoreML", code: 0) }
        do {
            try await makeStore(compile: broken).prepare { _ in }
            XCTFail("doveva fallire")
        } catch {
            XCTAssertEqual(error as? ModelStoreError, .compileFailed("Denoiser"))
        }
        XCTAssertFalse(archiveExists("Denoiser.aar"), "l'archivio non deve restare per sempre")
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appending(path: "Denoiser.mlpackage").path))
    }

    // MARK: - M3: modello rovinato

    func testInvalidateTogleIlModelloCompilato() async throws {
        try publish()
        let store = makeStore()
        try await store.prepare { _ in }
        await store.invalidate("Denoiser")
        await store.invalidate("../compiled")   // nomi strani: niente
        let ready = await store.isReady
        XCTAssertFalse(ready)
        XCTAssertNil(store.modelURL("Denoiser"))
        XCTAssertNotNil(store.modelURL("VAEDecoder"))
        FakeModelServer.requests = []
        try await store.prepare { _ in }
        let archives = FakeModelServer.requests.compactMap { $0.url?.lastPathComponent }.filter { $0.hasSuffix(".aar") }
        XCTAssertEqual(archives, ["Denoiser.aar"], "si rifà solo quello")
        let again = await store.isReady
        XCTAssertTrue(again)
    }

    // MARK: - M5: elimina i modelli

    func testRemoveAllTogleTutto() async throws {
        try publish()
        let store = makeStore()
        try await store.prepare { _ in }
        await store.removeAll()
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
        let ready = await store.isReady
        XCTAssertFalse(ready)
        XCTAssertNil(store.tokenizerFiles())
    }

    func testRemoveAllFermaLoScaricoInCorso() async throws {
        try publish()
        FakeModelServer.gate = DispatchSemaphore(value: 0)
        let store = makeStore()
        let run = Task { try await store.prepare { _ in } }
        for _ in 0..<100 where requestCount("Denoiser.aar") == 0 { try await Task.sleep(nanoseconds: 20_000_000) }
        let removal = Task { await store.removeAll() }
        // removeAll ha già annullato lo scarico fermo sul cancello: ora lo si lascia andare
        try await Task.sleep(nanoseconds: 200_000_000)
        FakeModelServer.gate?.signal()
        await removal.value
        do { try await run.value; XCTFail("doveva essere fermato") } catch {}
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
    }
}

final class Locked<T>: @unchecked Sendable {
    private var _value: T
    private let lock = NSLock()
    init(_ value: T) { _value = value }
    var value: T { lock.lock(); defer { lock.unlock() }; return _value }
    func mutate(_ f: (inout T) -> Void) { lock.lock(); defer { lock.unlock() }; f(&_value) }
}
