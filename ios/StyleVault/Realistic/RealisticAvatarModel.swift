import CoreGraphics
import Foundation
import Observation

/// A che punto è la versione realistica di una vista.
enum RealisticState: Equatable {
    /// Si vede il collage (all'inizio, o dopo un annullamento).
    case collage
    case downloading(done: Int64, total: Int64)
    case preparing(done: Int, total: Int)
    /// Frazione 0…1 dei passi del calcolo.
    case generating(Double)
    case ready
    /// Messaggio breve; resta il collage.
    case failed(String)
    /// Dispositivo senza abbastanza memoria (o simulatore): solo collage.
    case unsupported
}

/// Stato della versione realistica per vista: scarica i modelli se servono,
/// genera una vista alla volta e salva il risultato. Produce solo l'immagine
/// realistica grezza (`images`): la composizione col collage (Vision) sta in
/// `RealisticComposer`, così questo modello si prova nel simulatore.
@MainActor @Observable
final class RealisticAvatarModel {
    private(set) var state: [BodyView: RealisticState]
    /// Risultato del modello per vista, grande come la foto del corpo data a `start`.
    private(set) var images = [BodyView: CGImage]()

    let supported: Bool
    /// Una generazione gira (o scarica): i pulsanti delle altre viste sono spenti.
    var isBusy: Bool { running != nil }
    var busyView: BodyView? { running?.view }

    private struct Run {
        let view: BodyView
        let id: UUID
        let task: Task<Void, Never>
    }
    private var running: Run?
    /// Il calcolo appena annullato: il motore si ferma solo tra una rete e l'altra
    /// (anche secondi), quindi il prossimo aspetta che finisca. Mai due reti grandi insieme.
    @ObservationIgnored private var draining: (id: UUID, task: Task<Void, Never>)?

    @ObservationIgnored private let store: RealisticModelPreparing?
    @ObservationIgnored private let cache: RealisticCache
    @ObservationIgnored private let makeEngine: (@Sendable () async throws -> RealisticTryOn)?
    @ObservationIgnored private var engine: RealisticTryOn?
    /// Ultimi valori del download e della preparazione (lo store li alterna file per file).
    @ObservationIgnored private var download: (done: Int64, total: Int64) = (0, 0)
    @ObservationIgnored private var preparation: (done: Int, total: Int) = (0, 0)
    /// Le cartelle `tryon-features-*` rimaste da una chiusura per memoria si tolgono una volta per avvio.
    private static var cleanedWorkFolders = false

    /// - makeEngine: crea il motore quando i modelli sono pronti (dopo `store.prepare`).
    init(store: RealisticModelPreparing?, supported: Bool, cache: RealisticCache = .shared,
         makeEngine: (@Sendable () async throws -> RealisticTryOn)?) {
        self.store = store
        self.supported = supported
        self.cache = cache
        self.makeEngine = makeEngine
        let initial: RealisticState = supported ? .collage : .unsupported
        state = Dictionary(uniqueKeysWithValues: BodyView.allCases.map { ($0, initial) })
    }

    /// Con un motore già fatto (i test usano un finto).
    convenience init(engine: RealisticTryOn?, store: RealisticModelPreparing?, supported: Bool,
                     cache: RealisticCache = .shared) {
        self.init(store: store, supported: supported, cache: cache,
                  makeEngine: engine.map { engine in { @Sendable in engine } })
    }

    /// Quello dell'app: modelli dalla Release, motore Mobile-VTON sul telefono.
    static func live() -> RealisticAvatarModel {
        let store = RealisticModelStore.shared
        return RealisticAvatarModel(store: store, supported: RealisticSupport.current) {
            guard let tokenizer = store.tokenizerFiles() else { throw TryOnError.tokenizer }
            return MobileVTONTryOn(models: { store.modelURL($0) }, tokenizer: tokenizer)
        }
    }

    // MARK: - Comandi

    /// Mostra la vista già salvata, senza generare. true se c'era.
    @discardableResult
    func restore(_ view: BodyView, item: AvatarItem, bodyKey: String) async -> Bool {
        guard supported, state[view] == .collage else { return state[view] == .ready }
        guard let hit = await cache.image(item: item, view: view, bodyKey: bodyKey),
              state[view] == .collage else { return false }
        images[view] = hit
        state[view] = .ready
        return true
    }

    /// Genera la vista (o la prende dalla cache). Ignorato se un'altra gira già
    /// o se è già pronta. Ritorna a lavoro finito o annullato.
    func start(_ view: BodyView, person: CGImage, garment: CGImage, item: AvatarItem, bodyKey: String) async {
        guard supported, running == nil, state[view] != .ready else { return }
        let id = UUID()
        let previous = draining?.task
        // In attesa che il calcolo annullato si fermi: la barra parte da 0
        if previous != nil { state[view] = .generating(0) }
        let task = Task {
            await previous?.value
            await run(view, id: id, person: person, garment: garment, item: item, bodyKey: bodyKey)
        }
        running = Run(view: view, id: id, task: task)
        // Se chi aspetta viene annullato (la schermata si chiude), si ferma anche il calcolo
        await withTaskCancellationHandler { await task.value } onCancel: { task.cancel() }
    }

    /// Chiusura della schermata o app in background: il calcolo si ferma e la
    /// vista torna al collage. Un download dei modelli già partito continua.
    func cancelAll() {
        guard let run = running else { return }
        running = nil
        run.task.cancel()
        // Il suo task finisce solo dopo quello annullato prima (lo aspetta): basta ricordare l'ultimo
        draining = (run.id, run.task)
        state[run.view] = .collage
    }

    /// Il risultato grezzo non serve più quando la vista composta è pronta (memoria):
    /// lo stato resta `.ready`, riaprendo l'outfit si rilegge dal disco.
    func releaseImage(_ view: BodyView) {
        images[view] = nil
    }

    // MARK: - Lavoro

    private func run(_ view: BodyView, id: UUID, person: CGImage, garment: CGImage,
                     item: AvatarItem, bodyKey: String) async {
        defer {
            if running?.id == id { running = nil }
            if draining?.id == id { draining = nil }
        }
        do {
            try checkCurrent(id)
            if let hit = await cache.image(item: item, view: view, bodyKey: bodyKey) {
                try checkCurrent(id)
                images[view] = hit
                state[view] = .ready
                return
            }
            let engine = try await readyEngine(view, id: id)
            try checkCurrent(id)
            state[view] = .generating(0)
            await removeStaleWorkFoldersOnce()
            try checkCurrent(id)
            let image = try await engine.generate(person: person, garment: garment, item: item) { [weak self] p in
                Task { @MainActor in self?.generationProgress(p.fraction, view: view, id: id) }
            }
            try Task.checkCancellation()
            await cache.store(image, item: item, view: view, bodyKey: bodyKey)
            guard running?.id == id else { return }
            images[view] = image
            state[view] = .ready
        } catch {
            // Già rimesso a collage da cancelAll
            guard running?.id == id else { return }
            state[view] = Task.isCancelled || error is CancellationError ? .collage : .failed(Self.message(for: error))
        }
    }

    private func readyEngine(_ view: BodyView, id: UUID) async throws -> RealisticTryOn {
        if let engine { return engine }
        guard let makeEngine else { throw TryOnError.missingModel("Denoiser") }
        if let store, !(await store.isReady) {
            // Annullato mentre si controllava: non lasciare la vista ferma su "Scarico…"
            try checkCurrent(id)
            download = (0, 0)
            preparation = (0, 0)
            state[view] = .downloading(done: 0, total: 0)
            try await store.prepare { [weak self] p in
                Task { @MainActor in self?.storeProgress(p, view: view, id: id) }
            }
            try Task.checkCancellation()
        }
        let made = try await makeEngine()
        engine = made
        return made
    }

    /// Questo lavoro è ancora quello in corso (non annullato né sostituito)?
    private func checkCurrent(_ id: UUID) throws {
        guard running?.id == id, !Task.isCancelled else { throw CancellationError() }
    }

    private func storeProgress(_ progress: ModelStoreProgress, view: BodyView, id: UUID) {
        guard running?.id == id else { return }
        switch state[view] {
        case .downloading?, .preparing?: break
        default: return   // arriva in ritardo, il calcolo è già partito
        }
        switch progress {
        case let .downloading(done, total): download = (max(done, total == download.total ? download.done : 0), total)
        case let .preparing(done, total): preparation = (max(done, total == preparation.total ? preparation.done : 0), total)
        }
        // Finché mancano byte si mostra il download, poi la preparazione
        state[view] = download.total > 0 && download.done < download.total
            ? .downloading(done: download.done, total: download.total)
            : .preparing(done: preparation.done, total: preparation.total)
    }

    private func generationProgress(_ fraction: Double, view: BodyView, id: UUID) {
        guard running?.id == id, case let .generating(old)? = state[view], fraction > old else { return }
        state[view] = .generating(min(fraction, 1))
    }

    private func removeStaleWorkFoldersOnce() async {
        guard !Self.cleanedWorkFolders else { return }
        Self.cleanedWorkFolders = true
        let cutoff = Date()
        await Task.detached(priority: .utility) {
            Self.removeStaleWorkFolders(in: FileManager.default.temporaryDirectory, olderThan: cutoff)
        }.value
    }

    /// Toglie le cartelle `tryon-features-*` create prima di `date` (il motore
    /// le cancella da solo, ma non se iOS chiude l'app per memoria).
    nonisolated static func removeStaleWorkFolders(in directory: URL, olderThan date: Date) {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.creationDateKey, .contentModificationDateKey]
        guard let entries = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys) else { return }
        for url in entries where url.lastPathComponent.hasPrefix("tryon-features-") {
            let values = try? url.resourceValues(forKeys: Set(keys))
            guard let created = values?.creationDate ?? values?.contentModificationDate, created < date else { continue }
            try? fm.removeItem(at: url)
        }
    }

    // MARK: - Testi

    /// Il capo che il realistico ridisegna: il capospalla se c'è (è quello che si vede), altrimenti il top.
    nonisolated static func realisticItem(in items: [AvatarItem]) -> AvatarItem? {
        items.first { $0.slot == "outerwear" } ?? items.first { $0.slot == "top" }
    }

    /// Testo della barra; nil se non c'è nulla in corso.
    nonisolated static func text(for state: RealisticState) -> String? {
        switch state {
        case let .downloading(done, total):
            guard total > 0 else { return "Scarico i modelli…" }
            return "Scarico i modelli… \(percent(Double(done) / Double(total)))% (\(size(done)) di \(size(total)))"
        case let .preparing(done, total):
            return total > 0 ? "Preparo i modelli, solo la prima volta… \(done)/\(total)"
                             : "Preparo i modelli, solo la prima volta…"
        case let .generating(fraction):
            return "Versione realistica… \(percent(fraction))%"
        default:
            return nil
        }
    }

    /// Avanzamento della barra 0…1; nil se non c'è nulla in corso.
    nonisolated static func fraction(for state: RealisticState) -> Double? {
        switch state {
        case let .downloading(done, total): return total > 0 ? Double(done) / Double(total) : 0
        case let .preparing(done, total): return total > 0 ? Double(done) / Double(total) : 0
        case let .generating(fraction): return fraction
        default: return nil
        }
    }

    nonisolated static func message(for error: Error) -> String {
        switch error {
        case ModelStoreError.notEnoughSpace(let neededMB):
            return "Serve più spazio: libera almeno \(size(Int64(neededMB) * 1_000_000)) e riprova."
        case ModelStoreError.network, is URLError:
            return "Non riesco a scaricare i modelli: controlla la connessione."
        case ModelStoreError.corrupted:
            return "Il download dei modelli non è riuscito."
        default:
            return "La versione realistica non è riuscita: resta il collage."
        }
    }

    private nonisolated static func percent(_ fraction: Double) -> Int {
        Int((min(max(fraction, 0), 1) * 100 + 1e-9).rounded(.down))
    }

    /// "420 MB", "1,2 GB" (decimali all'italiana, 1 GB = 1000 MB come in Impostazioni).
    nonisolated static func size(_ bytes: Int64) -> String {
        let mb = Double(bytes) / 1_000_000
        if mb < 999.5 { return "\(Int(mb.rounded())) MB" }
        let gb = String(format: "%.1f", mb / 1000).replacingOccurrences(of: ".", with: ",")
        return "\(gb) GB"
    }
}
