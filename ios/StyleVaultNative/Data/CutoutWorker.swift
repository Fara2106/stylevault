import Foundation
import OSLog
import Observation
import StyleVaultCore
import SwiftData

/// Fa gli scontorni dopo il salvataggio, uno alla volta: il foglio si chiude subito e Vision
/// non occupa la memoria due volte. Se non riesce, il capo resta senza scontorno e basta.
@MainActor @Observable final class CutoutWorker {
    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let cut: @Sendable (Data) async -> Data?
    @ObservationIgnored private var queue: [UUID] = []
    @ObservationIgnored private var running: Task<Void, Never>?
    /// Vision non ci ha trovato un capo: `enqueueMissing` non li riprova fino al prossimo avvio.
    @ObservationIgnored private var failed: Set<UUID> = []
    @ObservationIgnored private let logger = Logger(subsystem: "it.faraoni.stylevault.nativa", category: "cutout")

    init(context: ModelContext, cut: @escaping @Sendable (Data) async -> Data? = { await GarmentImage.cutout($0) }) {
        self.context = context
        self.cut = cut
    }

    func enqueue(_ itemID: UUID) {
        guard !queue.contains(itemID) else { return }
        queue.append(itemID)
        if running == nil {
            running = Task { await drain() }
        }
    }

    /// I capi con la foto ma senza scontorno: app chiusa prima della fine, importazione, versione precedente.
    func enqueueMissing() {
        let descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.cutout == nil && $0.photoFront != nil })
        do {
            for item in try context.fetch(descriptor) where !failed.contains(item.id) { enqueue(item.id) }
        } catch {
            logger.error("Ricerca dei capi senza scontorno non riuscita: \(error)")
        }
    }

    func waitUntilIdle() async {
        while let running { await running.value }
    }

    private func drain() async {
        while !queue.isEmpty {
            await process(queue.removeFirst())
        }
        running = nil
    }

    private func process(_ id: UUID) async {
        guard let source = item(id)?.photoFront else { return }
        let result = await cut(source)
        // Si rilegge: durante l'attesa il capo può essere stato cancellato o aver cambiato foto.
        guard let result else {
            failed.insert(id)
            logger.info("Nessuno scontorno per un capo")
            return
        }
        guard let item = item(id), item.photoFront == source else { return }
        item.cutout = result
        do { try context.save() } catch { logger.error("Salvataggio dello scontorno non riuscito: \(error)") }
    }

    private func item(_ id: UUID) -> Item? {
        do {
            return try context.fetch(FetchDescriptor<Item>(predicate: #Predicate { $0.id == id })).first
        } catch {
            logger.error("Lettura del capo non riuscita: \(error)")
            return nil
        }
    }
}
