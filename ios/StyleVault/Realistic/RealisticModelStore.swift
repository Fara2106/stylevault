import AppleArchive
import CoreML
import CryptoKit
import Foundation
import System

enum ModelStoreProgress: Equatable {
    case downloading(done: Int64, total: Int64)
    case preparing(done: Int, total: Int)
}

enum ModelStoreError: Error, Equatable {
    case notEnoughSpace(neededMB: Int)
    case corrupted(String)
    case network
    /// Core ML non ha compilato il modello (ad esempio iOS troppo vecchio): l'archivio è già tolto.
    case compileFailed(String)
    /// Rete a consumo (cellulare, hotspot) o Risparmio dati: serve il permesso di chi usa l'app.
    case expensiveNetwork
}

/// Quello che serve a chi mostra la schermata (e ai suoi test, con un finto).
protocol RealisticModelPreparing: Sendable {
    var isReady: Bool { get async }
    /// - allowsExpensiveNetwork: false per lo scarico automatico (niente rete a consumo
    ///   né Risparmio dati); true dopo "Scarica comunque".
    func prepare(allowsExpensiveNetwork: Bool,
                 progress: @escaping @Sendable (ModelStoreProgress) -> Void) async throws
    /// Toglie un modello compilato che non si carica più: il prossimo `prepare` lo rifà.
    func invalidate(_ name: String) async
    /// Toglie tutti i modelli (Crediti, "Elimina i modelli").
    func removeAll() async
}

extension RealisticModelPreparing {
    /// Scarico automatico: mai su rete a consumo.
    func prepare(progress: @escaping @Sendable (ModelStoreProgress) -> Void) async throws {
        try await prepare(allowsExpensiveNetwork: false, progress: progress)
    }
}

/// Scarica da una Release pubblica gli archivi dei modelli (Apple Archive),
/// ne controlla l'SHA-256, li estrae e compila i Core ML. Riprende da dove era
/// rimasto (`Range`) e toglie l'archivio appena estratto per liberare spazio.
///
/// Disposizione in `folder`:
/// - `models-manifest.json`: il manifest scaricato
/// - `downloads/<Nome>.aar(.part)`: archivi in arrivo
/// - `compiled/<Nome>.mlmodelc`: modelli pronti
/// - `Tokenizer/`: `vocab.json` + `merges.txt`
actor RealisticModelStore: RealisticModelPreparing {
    /// La Release con i modelli (anche nella chiave di RealisticCache).
    static let release = "avatar-models-v1"

    static let shared = RealisticModelStore(
        baseURL: URL(string: "https://github.com/Fara2106/stylevault/releases/download/\(release)/")!,
        folder: URL.applicationSupportDirectory.appending(path: "RealisticModels", directoryHint: .isDirectory))

    private struct Manifest: Codable, Equatable {
        struct File: Codable, Equatable { let name: String; let bytes: Int64; let sha256: String }
        let version: Int
        let files: [File]
    }

    private static let tokenizerName = "Tokenizer"
    private static let manifestName = "models-manifest.json"
    /// Spazio che serve in più dei byte scaricati (archivio + estratto + compilato).
    private static let spaceFactor = 2.5

    /// Errore di rete passeggero (timeout, connessione caduta, file arrivato a metà): si riprova.
    private struct TransientFailure: Error {}

    /// Chi segue l'avanzamento di una preparazione; si toglie da solo se il chiamante annulla.
    private final class Observers: @unchecked Sendable {
        private let lock = NSLock()
        private var list: [UUID: @Sendable (ModelStoreProgress) -> Void] = [:]
        func add(_ id: UUID, _ f: @escaping @Sendable (ModelStoreProgress) -> Void) { lock.lock(); list[id] = f; lock.unlock() }
        func remove(_ id: UUID) { lock.lock(); list[id] = nil; lock.unlock() }
        func send(_ p: ModelStoreProgress) {
            lock.lock(); let current = Array(list.values); lock.unlock()
            current.forEach { $0(p) }
        }
    }

    /// Attesa di un chiamante: finisce con il risultato della preparazione oppure subito se annulla.
    private final class Waiter: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<Void, Error>?
        private var result: Result<Void, Error>?
        func wait() async throws {
            try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
                lock.lock()
                if let result { lock.unlock(); c.resume(with: result) } else { continuation = c; lock.unlock() }
            }
        }
        func finish(_ r: Result<Void, Error>) {
            lock.lock()
            guard result == nil else { lock.unlock(); return }
            result = r
            let c = continuation
            continuation = nil
            lock.unlock()
            c?.resume(with: r)
        }
    }

    private struct Run {
        let id: UUID
        let task: Task<Void, Error>
        let observers: Observers
    }
    private var currentRun: Run?

    private let baseURL: URL
    private let folder: URL
    private let session: URLSession
    private let freeSpace: @Sendable () -> Int64
    private let compile: @Sendable (URL) async throws -> URL
    /// Attese prima dei nuovi tentativi dopo un errore di rete passeggero.
    private let retryDelays: [Duration]
    private let sleep: @Sendable (Duration) async throws -> Void

    /// - retryDelays, sleep: i test le cambiano per non aspettare davvero.
    init(baseURL: URL, folder: URL, session: URLSession = .shared,
         freeSpace: (@Sendable () -> Int64)? = nil,
         compile: @escaping @Sendable (URL) async throws -> URL = { try await MLModel.compileModel(at: $0) },
         retryDelays: [Duration] = [.seconds(1), .seconds(3)],
         sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.baseURL = baseURL
        self.folder = folder
        self.session = session
        self.compile = compile
        self.retryDelays = retryDelays
        self.sleep = sleep
        self.freeSpace = freeSpace ?? {
            let probe = folder.deletingLastPathComponent()
            let values = try? probe.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            return values?.volumeAvailableCapacityForImportantUsage ?? Int64.max
        }
    }

    // MARK: - Percorsi

    private var manifestURL: URL { folder.appending(path: Self.manifestName) }
    private var downloadsURL: URL { folder.appending(path: "downloads", directoryHint: .isDirectory) }
    private nonisolated var compiledURL: URL { folder.appending(path: "compiled", directoryHint: .isDirectory) }
    private nonisolated var tokenizerURL: URL { folder.appending(path: Self.tokenizerName, directoryHint: .isDirectory) }

    private func archiveURL(_ file: Manifest.File) -> URL { downloadsURL.appending(path: file.name) }
    private func partURL(_ file: Manifest.File) -> URL { downloadsURL.appending(path: file.name + ".part") }
    private func baseName(_ file: Manifest.File) -> String { String(file.name.dropLast(".aar".count)) }

    private func outputURL(_ file: Manifest.File) -> URL {
        let name = baseName(file)
        return name == Self.tokenizerName ? tokenizerURL : compiledURL.appending(path: name + ".mlmodelc")
    }

    private func isDone(_ file: Manifest.File) -> Bool {
        let fm = FileManager.default
        if baseName(file) == Self.tokenizerName {
            return fm.fileExists(atPath: tokenizerURL.appending(path: "vocab.json").path)
                && fm.fileExists(atPath: tokenizerURL.appending(path: "merges.txt").path)
        }
        return fm.fileExists(atPath: outputURL(file).path)
    }

    private func loadManifest() -> Manifest? {
        guard let data = try? Data(contentsOf: manifestURL) else { return nil }
        return try? JSONDecoder().decode(Manifest.self, from: data)
    }

    // MARK: - Lettura

    var isReady: Bool {
        guard let manifest = loadManifest(), !manifest.files.isEmpty else { return false }
        return manifest.files.allSatisfy { Self.isValidName($0.name) && isDone($0) }
    }

    /// `name` senza estensione, ad esempio "Denoiser". `nonisolated`: legge solo
    /// percorsi fissi e il disco, così il motore la chiama dalla sua closure sincrona.
    nonisolated func modelURL(_ name: String) -> URL? {
        let url = compiledURL.appending(path: name + ".mlmodelc")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    nonisolated func tokenizerFiles() -> (vocab: URL, merges: URL)? {
        let vocab = tokenizerURL.appending(path: "vocab.json")
        let merges = tokenizerURL.appending(path: "merges.txt")
        let fm = FileManager.default
        guard fm.fileExists(atPath: vocab.path), fm.fileExists(atPath: merges.path) else { return nil }
        return (vocab, merges)
    }

    // MARK: - Pulizia

    func invalidate(_ name: String) {
        guard Self.isValidName(name + ".aar"), name != Self.tokenizerName else { return }
        try? FileManager.default.removeItem(at: compiledURL.appending(path: name + ".mlmodelc"))
    }

    /// Ferma una preparazione in corso (e aspetta che si fermi), poi toglie la cartella.
    func removeAll() async {
        if let run = currentRun {
            currentRun = nil
            run.task.cancel()
            _ = await run.task.result
        }
        try? FileManager.default.removeItem(at: folder)
    }

    // MARK: - Preparazione

    /// Una sola preparazione alla volta: chi arriva mentre ne gira una si
    /// aggancia alla stessa (e ne riceve l'avanzamento), senza scrivere due volte gli stessi file.
    /// Se un chiamante annulla smette subito di aspettare, ma la preparazione continua per gli altri.
    /// Chi si aggancia usa il permesso di rete della preparazione già partita.
    func prepare(allowsExpensiveNetwork: Bool,
                 progress: @escaping @Sendable (ModelStoreProgress) -> Void) async throws {
        let run = currentRun ?? startRun(allowsExpensiveNetwork: allowsExpensiveNetwork)
        let observerID = UUID()
        run.observers.add(observerID, progress)
        let waiter = Waiter()
        Task { waiter.finish(await run.task.result) }
        try await withTaskCancellationHandler {
            try await waiter.wait()
        } onCancel: {
            run.observers.remove(observerID)
            waiter.finish(.failure(CancellationError()))
        }
    }

    private func startRun(allowsExpensiveNetwork: Bool) -> Run {
        let id = UUID()
        let observers = Observers()
        let task = Task {
            do {
                try await self.run(allowsExpensiveNetwork: allowsExpensiveNetwork) { observers.send($0) }
            } catch {
                self.finishRun(id)
                throw error
            }
            self.finishRun(id)
        }
        let run = Run(id: id, task: task, observers: observers)
        currentRun = run
        return run
    }

    /// Solo la preparazione che finisce libera il posto, e solo se è ancora la sua.
    private func finishRun(_ id: UUID) {
        if currentRun?.id == id { currentRun = nil }
    }

    private func run(allowsExpensiveNetwork: Bool,
                     progress: @escaping @Sendable (ModelStoreProgress) -> Void) async throws {
        let fm = FileManager.default
        let previous = loadManifest()
        do {
            try fm.createDirectory(at: downloadsURL, withIntermediateDirectories: true)
            try fm.createDirectory(at: compiledURL, withIntermediateDirectories: true)
        } catch where Self.isOutOfSpace(error) {
            // Senza manifest si stima la Release attuale: 1,3 GB × 2,5
            let needed = previous.map { neededBytes($0.files.filter { !isDone($0) }) } ?? 3_250_000_000
            throw ModelStoreError.notEnoughSpace(neededMB: Self.megabytes(max(needed, 1)))
        }
        var root = folder
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? root.setResourceValues(values)
        let manifest = try await withRetries {
            try await self.fetchManifest(fallback: previous, allowsExpensiveNetwork: allowsExpensiveNetwork)
        }
        try validate(manifest)

        // Un file cambiato nel manifest (altro hash) rende vecchio ciò che avevamo
        for file in manifest.files {
            if let old = previous?.files.first(where: { $0.name == file.name }), old.sha256 != file.sha256 {
                try? fm.removeItem(at: outputURL(file))
                try? fm.removeItem(at: archiveURL(file))
                try? fm.removeItem(at: partURL(file))
            }
        }

        let pending = manifest.files.filter { !isDone($0) }
        let needed = neededBytes(pending)
        if !pending.isEmpty, freeSpace() < needed {
            throw ModelStoreError.notEnoughSpace(neededMB: Self.megabytes(needed))
        }

        do {
            let data = try JSONEncoder().encode(manifest)
            try data.write(to: manifestURL, options: .atomic)
        } catch where Self.isOutOfSpace(error) {
            throw ModelStoreError.notEnoughSpace(neededMB: Self.megabytes(needed))
        }

        let total = manifest.files.reduce(Int64(0)) { $0 + $1.bytes }
        var doneBytes: Int64 = 0
        var doneModels = 0
        progress(.downloading(done: 0, total: total))
        progress(.preparing(done: 0, total: manifest.files.count))

        for (index, file) in manifest.files.enumerated() {
            try Task.checkCancellation()
            if isDone(file) {
                doneBytes += file.bytes
                doneModels += 1
                progress(.downloading(done: doneBytes, total: total))
                progress(.preparing(done: doneModels, total: manifest.files.count))
                continue
            }
            // Disco pieno a metà strada: si dice quanto serve ancora, l'archivio verificato resta
            let spaceMB = Self.megabytes(neededBytes(manifest.files[index...].filter { !isDone($0) }))
            do {
                let before = doneBytes
                try await withRetries {
                    try await self.download(file, doneBefore: before, total: total,
                                            allowsExpensiveNetwork: allowsExpensiveNetwork, progress: progress)
                }
                doneBytes += file.bytes
                progress(.downloading(done: doneBytes, total: total))
                try verify(file)
                try await extractAndCompile(file)
            } catch where Self.isOutOfSpace(error) {
                throw ModelStoreError.notEnoughSpace(neededMB: spaceMB)
            }
            doneModels += 1
            progress(.preparing(done: doneModels, total: manifest.files.count))
        }
    }

    /// Byte che servono su disco per finire questi file (il .part già arrivato non si riscarica).
    private func neededBytes<S: Sequence>(_ files: S) -> Int64 where S.Element == Manifest.File {
        let bytes = files.reduce(Int64(0)) { $0 + max(0, $1.bytes - min(fileSize(partURL($1)), $1.bytes)) }
        return Int64(Double(bytes) * Self.spaceFactor)
    }

    private static func megabytes(_ bytes: Int64) -> Int { Int((bytes + 1_048_575) / 1_048_576) }

    /// Riprova dopo `retryDelays` gli errori passeggeri; poi è `.network`.
    private func withRetries<T>(_ body: () async throws -> T) async throws -> T {
        var attempt = 0
        while true {
            do {
                return try await body()
            } catch is TransientFailure {
                guard attempt < retryDelays.count else { throw ModelStoreError.network }
                try await sleep(retryDelays[attempt])
                try Task.checkCancellation()
                attempt += 1
            }
        }
    }

    // MARK: - Errori

    /// Disco pieno (`ENOSPC`), anche dentro un altro errore.
    nonisolated static func isOutOfSpace(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.domain == NSCocoaErrorDomain, ns.code == NSFileWriteOutOfSpaceError { return true }
        if ns.domain == NSPOSIXErrorDomain, ns.code == Int(ENOSPC) { return true }
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? Error { return isOutOfSpace(underlying) }
        return false
    }

    /// Richiesta rifiutata perché la rete è a consumo o c'è Risparmio dati.
    nonisolated static func isExpensiveNetwork(_ error: Error) -> Bool {
        guard let reason = (error as? URLError)?.networkUnavailableReason else { return false }
        return reason == .expensive || reason == .constrained
    }

    /// Timeout o connessione caduta: vale la pena riprovare tra poco.
    nonisolated static func isTransient(_ error: Error) -> Bool {
        guard let code = (error as? URLError)?.code else { return false }
        return code == .timedOut || code == .networkConnectionLost
    }

    // MARK: - Manifest

    private static func isValidName(_ name: String) -> Bool {
        !name.isEmpty && !name.contains("/") && !name.contains("..") && !name.contains("\\")
            && name.hasSuffix(".aar") && name.count > ".aar".count
    }

    private func validate(_ manifest: Manifest) throws {
        for file in manifest.files {
            guard Self.isValidName(file.name), file.bytes >= 0,
                  file.sha256.count == 64, file.sha256.allSatisfy(\.isHexDigit) else {
                throw ModelStoreError.corrupted(Self.manifestName)
            }
        }
        guard !manifest.files.isEmpty else { throw ModelStoreError.corrupted(Self.manifestName) }
    }

    private func fetchManifest(fallback: Manifest?, allowsExpensiveNetwork: Bool) async throws -> Manifest {
        var request = URLRequest(url: baseURL.appending(path: Self.manifestName))
        request.allowsExpensiveNetworkAccess = allowsExpensiveNetwork
        request.allowsConstrainedNetworkAccess = allowsExpensiveNetwork
        do {
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ModelStoreError.network }
            guard let manifest = try? JSONDecoder().decode(Manifest.self, from: data) else {
                throw ModelStoreError.corrupted(Self.manifestName)
            }
            return manifest
        } catch let error as ModelStoreError {
            throw error
        } catch {
            if error is CancellationError || (error as? URLError)?.code == .cancelled && Task.isCancelled {
                throw CancellationError()
            }
            // Senza rete si può comunque finire con il manifest già salvato
            if let fallback { return fallback }
            if Self.isExpensiveNetwork(error) { throw ModelStoreError.expensiveNetwork }
            if Self.isTransient(error) { throw TransientFailure() }
            throw ModelStoreError.network
        }
    }

    // MARK: - Scarico

    private func fileSize(_ url: URL) -> Int64 {
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? NSNumber
        return size?.int64Value ?? 0
    }

    private func download(_ file: Manifest.File, doneBefore: Int64, total: Int64, allowsExpensiveNetwork: Bool,
                          progress: @escaping @Sendable (ModelStoreProgress) -> Void,
                          retryOnRangeError: Bool = true) async throws {
        let fm = FileManager.default
        let archive = archiveURL(file)
        let part = partURL(file)
        if fm.fileExists(atPath: archive.path), fileSize(archive) == file.bytes { return }

        var offset = fileSize(part)
        if offset > file.bytes { try? fm.removeItem(at: part); offset = 0 }
        if offset == file.bytes {
            try? fm.removeItem(at: archive)
            try fm.moveItem(at: part, to: archive)
            return
        }

        var request = URLRequest(url: baseURL.appending(path: file.name))
        request.allowsExpensiveNetworkAccess = allowsExpensiveNetwork
        request.allowsConstrainedNetworkAccess = allowsExpensiveNetwork
        if offset > 0 { request.setValue("bytes=\(offset)-", forHTTPHeaderField: "Range") }

        if !fm.fileExists(atPath: part.path) { fm.createFile(atPath: part.path, contents: nil) }
        let handle = try FileHandle(forWritingTo: part)
        defer { try? handle.close() }

        let downloader = PartDownloader(handle: handle) { written in
            progress(.downloading(done: doneBefore + min(written, file.bytes), total: total))
        }
        let task = session.dataTask(with: request)
        task.delegate = downloader
        let outcome: PartDownloader.Outcome = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                downloader.continuation = continuation
                task.resume()
            }
        } onCancel: { task.cancel() }
        try? handle.close()
        try Task.checkCancellation()

        if outcome.status == 416 {
            // Il file parziale non combacia più con il server: si riparte da zero
            try? fm.removeItem(at: part)
            guard retryOnRangeError else { throw ModelStoreError.network }
            return try await download(file, doneBefore: doneBefore, total: total,
                                      allowsExpensiveNetwork: allowsExpensiveNetwork,
                                      progress: progress, retryOnRangeError: false)
        }
        // Quel che è arrivato resta nel .part: il prossimo tentativo riprende da lì
        if let error = outcome.error {
            if Self.isOutOfSpace(error) { throw error }   // diventa .notEnoughSpace in `run`
            if Self.isExpensiveNetwork(error) { throw ModelStoreError.expensiveNetwork }
            if Self.isTransient(error) { throw TransientFailure() }
            throw ModelStoreError.network
        }
        guard outcome.status == 200 || outcome.status == 206 else { throw ModelStoreError.network }
        let size = fileSize(part)
        guard size == file.bytes else {
            if size > file.bytes { try? fm.removeItem(at: part); throw ModelStoreError.corrupted(file.name) }
            throw TransientFailure()   // risposta finita prima del tempo
        }
        try? fm.removeItem(at: archive)
        try fm.moveItem(at: part, to: archive)
    }

    // MARK: - Verifica

    private func verify(_ file: Manifest.File) throws {
        let archive = archiveURL(file)
        let digest: String
        do {
            digest = try Self.sha256(of: archive)
        } catch {
            try? FileManager.default.removeItem(at: archive)
            throw ModelStoreError.corrupted(file.name)
        }
        guard digest == file.sha256.lowercased() else {
            try? FileManager.default.removeItem(at: archive)
            throw ModelStoreError.corrupted(file.name)
        }
    }

    private static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 4 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Estrazione e compilazione

    private func extractAndCompile(_ file: Manifest.File) async throws {
        let fm = FileManager.default
        let archive = archiveURL(file)
        let name = baseName(file)

        if name == Self.tokenizerName {
            let temp = folder.appending(path: "Tokenizer.tmp", directoryHint: .isDirectory)
            try? fm.removeItem(at: temp)
            try extract(archive, to: temp, file: file)
            guard fm.fileExists(atPath: temp.appending(path: "vocab.json").path),
                  fm.fileExists(atPath: temp.appending(path: "merges.txt").path) else {
                try? fm.removeItem(at: temp)
                try? fm.removeItem(at: archive)
                throw ModelStoreError.corrupted(file.name)
            }
            try? fm.removeItem(at: tokenizerURL)
            try fm.moveItem(at: temp, to: tokenizerURL)
            try? fm.removeItem(at: archive)
            return
        }

        let package = folder.appending(path: name + ".mlpackage", directoryHint: .isDirectory)
        try? fm.removeItem(at: package)
        try extract(archive, to: package, file: file)
        let compiled: URL
        do {
            compiled = try await compile(package)
        } catch {
            try? fm.removeItem(at: package)
            if error is CancellationError { throw error }
            // Disco pieno: l'archivio verificato resta, si riprende da lì liberato lo spazio
            if Self.isOutOfSpace(error) || freeSpace() < file.bytes { throw POSIXError(.ENOSPC) }
            // Non si compilerà mai (ad esempio iOS troppo vecchio): l'archivio non deve restare
            try? fm.removeItem(at: archive)
            throw ModelStoreError.compileFailed(name)
        }
        let target = outputURL(file)
        try? fm.removeItem(at: target)
        try fm.moveItem(at: compiled, to: target)
        try? fm.removeItem(at: package)
        try? fm.removeItem(at: archive)
    }

    private func extract(_ archive: URL, to destination: URL, file: Manifest.File) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)   // ENOSPC: lo gestisce `run`
        func fail(_ error: Error? = nil) -> Error {
            try? fm.removeItem(at: destination)
            // Disco pieno: l'archivio verificato resta (`run` lo trasforma in .notEnoughSpace)
            if let error, Self.isOutOfSpace(error) { return error }
            if freeSpace() < file.bytes { return POSIXError(.ENOSPC) }
            try? fm.removeItem(at: archive)
            return ModelStoreError.corrupted(file.name)
        }
        guard let source = ArchiveByteStream.fileStream(
                path: FilePath(archive.path), mode: .readOnly, options: [], permissions: FilePermissions(rawValue: 0o644)),
              let decompress = ArchiveByteStream.decompressionStream(readingFrom: source),
              let decode = ArchiveStream.decodeStream(readingFrom: decompress),
              let extractor = ArchiveStream.extractStream(
                extractingTo: FilePath(destination.path), flags: [.ignoreOperationNotPermitted])
        else { throw fail() }
        defer {
            try? extractor.close(); try? decode.close(); try? decompress.close(); try? source.close()
        }
        do {
            _ = try ArchiveStream.process(readingFrom: decode, writingTo: extractor)
        } catch {
            throw fail(error)
        }
    }
}

/// Scrive su disco man mano che i byte arrivano (nessun buffer in memoria).
/// Se il server ignora `Range` e risponde 200, il file riparte da zero.
private final class PartDownloader: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    struct Outcome: Sendable { let status: Int; let error: Error? }

    private let handle: FileHandle
    private let onWritten: @Sendable (Int64) -> Void
    private var status = 0
    private var written: Int64 = 0
    private var writeError: Error?
    var continuation: CheckedContinuation<Outcome, Never>?

    init(handle: FileHandle, onWritten: @escaping @Sendable (Int64) -> Void) {
        self.handle = handle
        self.onWritten = onWritten
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        status = (response as? HTTPURLResponse)?.statusCode ?? 0
        do {
            switch status {
            case 200:
                try handle.truncate(atOffset: 0)
                try handle.seek(toOffset: 0)
                written = 0
            case 206:
                written = Int64(try handle.seekToEnd())
            default:
                completionHandler(.cancel)
                return
            }
            completionHandler(.allow)
        } catch {
            writeError = error
            completionHandler(.cancel)
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        do {
            try handle.write(contentsOf: data)
            written += Int64(data.count)
            onWritten(written)
        } catch {
            writeError = error
            dataTask.cancel()
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // Anche senza risposta (rete a consumo, timeout): chi chiama decide cosa farne
        let failure = writeError ?? error
        continuation?.resume(returning: Outcome(status: status, error: failure))
        continuation = nil
    }
}
