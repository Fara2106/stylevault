import CoreGraphics
import Foundation
import Observation
import os

/// A che punto è la versione realistica di una vista.
enum RealisticState: Equatable {
    /// Si vede il collage (all'inizio, o dopo un annullamento).
    case collage
    case downloading(done: Int64, total: Int64)
    case preparing(done: Int, total: Int)
    /// Frazione 0…1 dei passi del calcolo.
    case generating(Double)
    /// Prima generazione sul telefono: Core ML prepara le reti per il Neural Engine
    /// (minuti). done/total reti caricate, fraction dei passi del calcolo.
    case warming(done: Int, total: Int, fraction: Double)
    case ready
    /// Messaggio breve; resta il collage.
    case failed(String)
    /// Rete a consumo o Risparmio dati: si scarica solo dopo "Scarica comunque".
    case needsNetworkConsent
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
    /// Una generazione gira (o scarica), o si stanno togliendo i modelli: i pulsanti sono spenti.
    var isBusy: Bool { running != nil || isRemoving }
    var busyView: BodyView? { running?.view }
    /// L'ultima generazione è stata interrotta da una chiusura dell'app (memoria):
    /// la vista davanti non parte da sola, c'è "Riprova".
    let wasInterrupted: Bool
    /// La vista davanti può partire da sola all'apertura: no se l'ultima generazione
    /// si è interrotta, né dopo `maxInterruptions` interruzioni di fila (finché una non riesce).
    let autoStartAllowed: Bool
    private(set) var isRemoving = false
    /// L'utente ha detto sì al download dei modelli (Apple 4.2.3(ii)): senza,
    /// la versione realistica non parte da sola e mostra "Scarica (1,3 GB)".
    private(set) var downloadConsented: Bool

    static let maxInterruptions = 2
    /// Un id per avvio dell'app: il segno di "generazione in corso" di questo avvio non è un'interruzione.
    static let launch = UUID()

    enum Keys {
        static let inProgress = "realistic.inProgress"
        static let interruptions = "realistic.interruptions"
        static let warmed = "realistic.warmed"
        /// Sì al download dei modelli (1,3 GB): si chiede la prima volta, anche in Wi-Fi.
        static let downloadConsented = "realistic.downloadConsented"
    }

    private struct Run {
        let view: BodyView
        let id: UUID
        let task: Task<Void, Never>
    }
    private var running: Run?
    /// Il calcolo appena annullato: il motore si ferma solo tra una rete e l'altra
    /// (anche secondi), quindi il prossimo aspetta che finisca. Mai due reti grandi insieme,
    /// anche riaprendo subito la schermata (statico: vale per tutte le istanze).
    private static var draining: (id: UUID, task: Task<Void, Never>)?

    @ObservationIgnored private let store: RealisticModelPreparing?
    @ObservationIgnored private let cache: RealisticCache
    @ObservationIgnored private let makeEngine: (@Sendable () async throws -> RealisticTryOn)?
    @ObservationIgnored private var engine: RealisticTryOn?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let launch: UUID
    /// Ultimi valori del download e della preparazione (lo store li alterna file per file).
    @ObservationIgnored private var download: (done: Int64, total: Int64) = (0, 0)
    @ObservationIgnored private var preparation: (done: Int, total: Int) = (0, 0)
    /// Le cartelle `tryon-features-*` rimaste da una chiusura per memoria si tolgono una volta per avvio.
    private static var cleanedWorkFolders = false

    /// - makeEngine: crea il motore quando i modelli sono pronti (dopo `store.prepare`).
    /// - defaults, launch: dove resta il segno di "generazione in corso" e l'avvio attuale (i test li cambiano).
    init(store: RealisticModelPreparing?, supported: Bool, cache: RealisticCache = .shared,
         defaults: UserDefaults = .standard, launch: UUID = RealisticAvatarModel.launch,
         makeEngine: (@Sendable () async throws -> RealisticTryOn)?) {
        self.store = store
        self.supported = supported
        self.cache = cache
        self.defaults = defaults
        self.launch = launch
        self.makeEngine = makeEngine
        let initial: RealisticState = supported ? .collage : .unsupported
        state = Dictionary(uniqueKeysWithValues: BodyView.allCases.map { ($0, initial) })
        // Il segno di un avvio precedente vuol dire che iOS ha chiuso l'app durante il calcolo
        var interrupted = false
        if supported, let marker = defaults.dictionary(forKey: Keys.inProgress),
           marker["launch"] as? String != launch.uuidString {
            defaults.removeObject(forKey: Keys.inProgress)
            defaults.set(defaults.integer(forKey: Keys.interruptions) + 1, forKey: Keys.interruptions)
            interrupted = true
        }
        wasInterrupted = interrupted
        downloadConsented = defaults.bool(forKey: Keys.downloadConsented)
        autoStartAllowed = supported && !interrupted
            && defaults.integer(forKey: Keys.interruptions) < Self.maxInterruptions
    }

    /// Con un motore già fatto (i test usano un finto).
    convenience init(engine: RealisticTryOn?, store: RealisticModelPreparing?, supported: Bool,
                     cache: RealisticCache = .shared, defaults: UserDefaults = .standard,
                     launch: UUID = RealisticAvatarModel.launch) {
        self.init(store: store, supported: supported, cache: cache, defaults: defaults, launch: launch,
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
    /// - allowsExpensiveNetwork: true solo dopo "Scarica comunque" (rete a consumo o Risparmio dati).
    func start(_ view: BodyView, person: CGImage, garment: CGImage, item: AvatarItem, bodyKey: String,
               allowsExpensiveNetwork: Bool = false) async {
        guard supported, running == nil, !isRemoving, state[view] != .ready else { return }
        let id = UUID()
        let previous = Self.draining?.task
        // In attesa che il calcolo annullato si fermi: la barra parte da 0
        if previous != nil { state[view] = startingState }
        let task = Task {
            await previous?.value
            await run(view, id: id, person: person, garment: garment, item: item, bodyKey: bodyKey,
                      allowsExpensiveNetwork: allowsExpensiveNetwork)
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
        Self.draining = (run.id, run.task)
        state[run.view] = .collage
    }

    /// "Scarica (1,3 GB)": il sì resta per le aperture seguenti.
    func consentToDownload() {
        downloadConsented = true
        defaults.set(true, forKey: Keys.downloadConsented)
    }

    /// "Elimina i modelli" (Crediti): aspetta un calcolo che si sta fermando, toglie i
    /// modelli e torna al collage. Il prossimo uso riscarica e riprepara il motore.
    func removeModels() async {
        guard running == nil, !isRemoving else { return }
        isRemoving = true
        defer { isRemoving = false }
        await Self.draining?.task.value
        engine = nil
        await store?.removeAll()
        defaults.removeObject(forKey: Keys.warmed)
        // Il prossimo download (altri 1,3 GB) si richiede
        defaults.removeObject(forKey: Keys.downloadConsented)
        downloadConsented = false
        images.removeAll()
        if supported { for view in BodyView.allCases { state[view] = .collage } }
    }

    /// Il risultato grezzo non serve più quando la vista composta è pronta (memoria):
    /// lo stato resta `.ready`, riaprendo l'outfit si rilegge dal disco.
    func releaseImage(_ view: BodyView) {
        images[view] = nil
    }

    // MARK: - Lavoro

    private func run(_ view: BodyView, id: UUID, person: CGImage, garment: CGImage,
                     item: AvatarItem, bodyKey: String, allowsExpensiveNetwork: Bool) async {
        defer {
            if running?.id == id { running = nil }
            if Self.draining?.id == id { Self.draining = nil }
        }
        do {
            try checkCurrent(id)
            if let hit = await cache.image(item: item, view: view, bodyKey: bodyKey) {
                try checkCurrent(id)
                images[view] = hit
                state[view] = .ready
                return
            }
            let clock = ContinuousClock()
            let prepareStart = clock.now
            let engine = try await readyEngine(view, id: id, allowsExpensiveNetwork: allowsExpensiveNetwork)
            Self.log("modelli pronti per \(view) in \(Self.seconds(clock.now - prepareStart)) s")
            try checkCurrent(id)
            state[view] = startingState
            await removeStaleWorkFoldersOnce()
            try checkCurrent(id)
            // Se iOS chiude l'app durante il calcolo il segno resta: alla prossima apertura niente partenza da sola
            markInProgress(view)
            let generateStart = clock.now
            let image: CGImage
            do {
                image = try await engine.generate(person: person, garment: garment, item: item) { [weak self] p in
                    Task { @MainActor in self?.generationProgress(p, view: view, id: id) }
                }
            } catch {
                clearInProgress()
                throw error
            }
            clearInProgress()
            Self.log("vista \(view) generata in \(Self.seconds(clock.now - generateStart)) s")
            defaults.set(0, forKey: Keys.interruptions)
            defaults.set(true, forKey: Keys.warmed)
            try Task.checkCancellation()
            await cache.store(image, item: item, view: view, bodyKey: bodyKey)
            guard running?.id == id else { return }
            images[view] = image
            state[view] = .ready
        } catch {
            Self.log("vista \(view) non generata: \(error)")
            await forgetBrokenModel(error)
            // Già rimesso a collage da cancelAll
            guard running?.id == id else { return }
            if Task.isCancelled || error is CancellationError {
                state[view] = .collage
            } else if case ModelStoreError.expensiveNetwork = error {
                state[view] = .needsNetworkConsent
            } else {
                state[view] = .failed(Self.message(for: error))
            }
        }
    }

    private nonisolated static let logger = Logger(subsystem: "it.faraoni.stylevault", category: "realistic")

    /// Tempi ed errori nel registro di sistema e sulla console (per le prove sul telefono).
    private nonisolated static func log(_ line: String) {
        logger.info("\(line, privacy: .public)")
        print("SVREAL \(line)")
    }

    private nonisolated static func seconds(_ d: Duration) -> String {
        String(format: "%.1f", Double(d.components.seconds) + Double(d.components.attoseconds) / 1e18)
    }

    /// Un modello compilato che non si carica (o che manca) si toglie: con "Riprova" lo store lo rifà.
    private func forgetBrokenModel(_ error: Error) async {
        switch error {
        case TryOnError.loadFailed(let name):
            engine = nil
            await store?.invalidate(name)
        case TryOnError.missingModel:
            engine = nil
        default:
            break
        }
    }

    /// Prima barra del calcolo: la prima volta in assoluto è la preparazione del motore.
    private var startingState: RealisticState {
        defaults.bool(forKey: Keys.warmed)
            ? .generating(0) : .warming(done: 0, total: TryOnProgress.modelCount, fraction: 0)
    }

    private func markInProgress(_ view: BodyView) {
        defaults.set(["view": view.rawValue, "at": Date().timeIntervalSince1970, "launch": launch.uuidString],
                     forKey: Keys.inProgress)
    }

    private func clearInProgress() {
        defaults.removeObject(forKey: Keys.inProgress)
    }

    private func readyEngine(_ view: BodyView, id: UUID, allowsExpensiveNetwork: Bool) async throws -> RealisticTryOn {
        if let engine { return engine }
        guard let makeEngine else { throw TryOnError.missingModel("Denoiser") }
        if let store, !(await store.isReady) {
            // Annullato mentre si controllava: non lasciare la vista ferma su "Scarico…"
            try checkCurrent(id)
            download = (0, 0)
            preparation = (0, 0)
            state[view] = .downloading(done: 0, total: 0)
            try await store.prepare(allowsExpensiveNetwork: allowsExpensiveNetwork) { [weak self] p in
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

    /// Gli aggiornamenti arrivano in Task separati (ordine non garantito): la barra non torna mai indietro.
    private func generationProgress(_ progress: TryOnProgress, view: BodyView, id: UUID) {
        guard running?.id == id else { return }
        let fraction = min(max(progress.fraction, 0), 1)
        switch state[view] {
        case let .generating(old)?:
            if fraction > old { state[view] = .generating(fraction) }
        case let .warming(done, total, old)?:
            let loaded = min(max(progress.loaded, done), total)
            let f = max(fraction, old)
            if loaded != done || f != old { state[view] = .warming(done: loaded, total: total, fraction: f) }
        default:
            return
        }
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
        case let .warming(done, total, _):
            return "Preparo il motore, solo la prima volta… \(done)/\(total)"
        default:
            return nil
        }
    }

    /// Sotto la barra quando lo scarico aspetta il permesso ("Scarica comunque").
    nonisolated static let networkConsentText =
        "Per la versione realistica servono 1,3 GB. Sei su rete cellulare o Risparmio dati."
    /// Prima del primo download, anche in Wi-Fi.
    nonisolated static let downloadConsentText =
        "La versione realistica scarica 1,3 GB di modelli, una volta sola. Puoi eliminarli quando vuoi dai Crediti (i)."
    nonisolated static let interruptedText = "La versione realistica si è interrotta l'ultima volta."

    /// Avanzamento della barra 0…1; nil se non c'è nulla in corso.
    nonisolated static func fraction(for state: RealisticState) -> Double? {
        switch state {
        case let .downloading(done, total): return total > 0 ? Double(done) / Double(total) : 0
        case let .preparing(done, total): return total > 0 ? Double(done) / Double(total) : 0
        case let .generating(fraction): return fraction
        // Metà reti caricate, metà passi: tutte e due non scendono mai, la barra arriva a 1
        case let .warming(done, total, fraction):
            return total > 0 ? (Double(done) / Double(total) + fraction) / 2 : fraction
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
        case ModelStoreError.compileFailed:
            return "I modelli non funzionano su questo iPhone: serve iOS 18."
        case ModelStoreError.expensiveNetwork:
            return networkConsentText
        case TryOnError.loadFailed:
            return "Un modello non si carica: con Riprova lo riscarico."
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
