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
}

/// Quello che serve a chi mostra la schermata (e ai suoi test, con un finto).
protocol RealisticModelPreparing: Sendable {
    var isReady: Bool { get async }
    func prepare(progress: @escaping @Sendable (ModelStoreProgress) -> Void) async throws
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
    static let shared = RealisticModelStore(
        baseURL: URL(string: "https://github.com/Fara2106/stylevault/releases/download/avatar-models-v1/")!,
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

    private final class Observers: @unchecked Sendable {
        private let lock = NSLock()
        private var list: [@Sendable (ModelStoreProgress) -> Void] = []
        func add(_ f: @escaping @Sendable (ModelStoreProgress) -> Void) { lock.lock(); list.append(f); lock.unlock() }
        func removeAll() { lock.lock(); list = []; lock.unlock() }
        func send(_ p: ModelStoreProgress) {
            lock.lock(); let current = list; lock.unlock()
            current.forEach { $0(p) }
        }
    }
    private let observers = Observers()
    private var inFlight: Task<Void, Error>?

    private let baseURL: URL
    private let folder: URL
    private let session: URLSession
    private let freeSpace: @Sendable () -> Int64
    private let compile: @Sendable (URL) async throws -> URL

    init(baseURL: URL, folder: URL, session: URLSession = .shared,
         freeSpace: (@Sendable () -> Int64)? = nil,
         compile: @escaping @Sendable (URL) async throws -> URL = { try await MLModel.compileModel(at: $0) }) {
        self.baseURL = baseURL
        self.folder = folder
        self.session = session
        self.compile = compile
        self.freeSpace = freeSpace ?? {
            let probe = folder.deletingLastPathComponent()
            let values = try? probe.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            return values?.volumeAvailableCapacityForImportantUsage ?? Int64.max
        }
    }

    // MARK: - Percorsi

    private var manifestURL: URL { folder.appending(path: Self.manifestName) }
    private var downloadsURL: URL { folder.appending(path: "downloads", directoryHint: .isDirectory) }
    private var compiledURL: URL { folder.appending(path: "compiled", directoryHint: .isDirectory) }
    private var tokenizerURL: URL { folder.appending(path: Self.tokenizerName, directoryHint: .isDirectory) }

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

    /// `name` senza estensione, ad esempio "Denoiser".
    func modelURL(_ name: String) -> URL? {
        let url = compiledURL.appending(path: name + ".mlmodelc")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func tokenizerFiles() -> (vocab: URL, merges: URL)? {
        let vocab = tokenizerURL.appending(path: "vocab.json")
        let merges = tokenizerURL.appending(path: "merges.txt")
        let fm = FileManager.default
        guard fm.fileExists(atPath: vocab.path), fm.fileExists(atPath: merges.path) else { return nil }
        return (vocab, merges)
    }

    // MARK: - Preparazione

    /// Una sola preparazione alla volta: chi arriva mentre ne gira una si
    /// aggancia alla stessa (e ne riceve l'avanzamento), senza scrivere due volte gli stessi file.
    func prepare(progress: @escaping @Sendable (ModelStoreProgress) -> Void) async throws {
        observers.add(progress)
        if inFlight == nil {
            let observers = self.observers
            inFlight = Task { [weak self] in
                try await self?.run { observers.send($0) }
            }
        }
        guard let task = inFlight else { return }
        do {
            try await task.value
        } catch {
            finishPreparation()
            throw error
        }
        finishPreparation()
    }

    private func finishPreparation() {
        inFlight = nil
        observers.removeAll()
    }

    private func run(progress: @escaping @Sendable (ModelStoreProgress) -> Void) async throws {
        let fm = FileManager.default
        try fm.createDirectory(at: downloadsURL, withIntermediateDirectories: true)
        try fm.createDirectory(at: compiledURL, withIntermediateDirectories: true)
        var root = folder
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? root.setResourceValues(values)

        let previous = loadManifest()
        let manifest = try await fetchManifest(fallback: previous)
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
        let pendingBytes = pending.reduce(Int64(0)) { $0 + max(0, $1.bytes - min(fileSize(partURL($1)), $1.bytes)) }
        let needed = Int64(Double(pendingBytes) * Self.spaceFactor)
        if !pending.isEmpty, freeSpace() < needed {
            throw ModelStoreError.notEnoughSpace(neededMB: Int((needed + 1_048_575) / 1_048_576))
        }

        let data = try JSONEncoder().encode(manifest)
        try data.write(to: manifestURL, options: .atomic)

        let total = manifest.files.reduce(Int64(0)) { $0 + $1.bytes }
        var doneBytes: Int64 = 0
        var doneModels = 0
        progress(.downloading(done: 0, total: total))
        progress(.preparing(done: 0, total: manifest.files.count))

        for file in manifest.files {
            try Task.checkCancellation()
            if isDone(file) {
                doneBytes += file.bytes
                doneModels += 1
                progress(.downloading(done: doneBytes, total: total))
                progress(.preparing(done: doneModels, total: manifest.files.count))
                continue
            }
            try await download(file, doneBefore: doneBytes, total: total, progress: progress)
            doneBytes += file.bytes
            progress(.downloading(done: doneBytes, total: total))
            try verify(file)
            try await extractAndCompile(file)
            doneModels += 1
            progress(.preparing(done: doneModels, total: manifest.files.count))
        }
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

    private func fetchManifest(fallback: Manifest?) async throws -> Manifest {
        do {
            let (data, response) = try await session.data(from: baseURL.appending(path: Self.manifestName))
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
            throw ModelStoreError.network
        }
    }

    // MARK: - Scarico

    private func fileSize(_ url: URL) -> Int64 {
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? NSNumber
        return size?.int64Value ?? 0
    }

    private func download(_ file: Manifest.File, doneBefore: Int64, total: Int64,
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
                                      progress: progress, retryOnRangeError: false)
        }
        // Quel che è arrivato resta nel .part: la volta dopo si riprende da lì
        guard outcome.error == nil, outcome.status == 200 || outcome.status == 206 else {
            throw ModelStoreError.network
        }
        let size = fileSize(part)
        guard size == file.bytes else {
            if size > file.bytes { try? fm.removeItem(at: part); throw ModelStoreError.corrupted(file.name) }
            throw ModelStoreError.network
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
            throw ModelStoreError.corrupted(file.name)
        }
        let target = outputURL(file)
        try? fm.removeItem(at: target)
        try fm.moveItem(at: compiled, to: target)
        try? fm.removeItem(at: package)
        try? fm.removeItem(at: archive)
    }

    private func extract(_ archive: URL, to destination: URL, file: Manifest.File) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        func fail() -> ModelStoreError {
            try? fm.removeItem(at: destination)
            try? fm.removeItem(at: archive)
            return .corrupted(file.name)
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
            throw fail()
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
        let failure = writeError ?? ((status == 200 || status == 206 || status == 416) ? error : nil)
        continuation?.resume(returning: Outcome(status: status, error: failure))
        continuation = nil
    }
}
