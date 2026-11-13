import CloudKit
import CoreData
import Foundation
import Observation

enum SyncState: Equatable { case active, unavailable, temporaryStore }

enum SyncRules {
    /// Unica regola dell'avviso "sincronizzazione non attiva". Senza rete non è un problema:
    /// CloudKit riprova da solo, quindi gli errori di rete non contano.
    static func state(health: StoreHealth, account: CKAccountStatus, lastError: Error?) -> SyncState {
        switch health {
        case .temporary: return .temporaryStore
        case .localOnly: return .unavailable
        case .cloud: break
        }
        if account != .available { return .unavailable }
        if let lastError, containsQuotaExceeded(lastError) { return .unavailable }
        return .active
    }

    /// CloudKit consegna `quotaExceeded` anche dentro `.partialFailure` e Core Data
    /// può avvolgerlo in un errore sottostante: si cerca a ogni livello.
    static func isQuotaExceeded(_ error: Error) -> Bool { containsQuotaExceeded(error) }

    private static func containsQuotaExceeded(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == CKErrorDomain, nsError.code == CKError.Code.quotaExceeded.rawValue { return true }
        if let partial = nsError.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error],
           partial.values.contains(where: containsQuotaExceeded) { return true }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return containsQuotaExceeded(underlying)
        }
        return false
    }
}

/// Tipo di evento di sincronizzazione, specchio di `NSPersistentCloudKitContainer.Event.EventType`
/// (così i test non dipendono da CoreData).
enum SyncEventKind: Hashable { case setup, `import`, export }

@MainActor @Observable
final class SyncMonitor {
    private(set) var state: SyncState

    @ObservationIgnored private let health: StoreHealth
    @ObservationIgnored private var account: CKAccountStatus?  // nil = non ancora noto
    /// Ultimo errore per tipo di evento: un errore si azzera solo con un evento riuscito dello stesso tipo.
    @ObservationIgnored private var lastErrors: [SyncEventKind: Error] = [:]
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init(health: StoreHealth) {
        self.health = health
        // Con il cloud si parte "attivo" fino alla prima risposta di accountStatus(): niente lampo dell'avviso.
        self.state = health == .cloud ? .active : SyncRules.state(health: health, account: .couldNotDetermine, lastError: nil)
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    func start() {
        // Con l'archivio temporaneo non si contatta CloudKit; una seconda chiamata non fa nulla.
        guard health == .cloud, observers.isEmpty else { return }

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .CKAccountChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.refreshAccount() }
        })
        observers.append(center.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main
        ) { [weak self] note in
            let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event
            let finished = event?.endDate != nil
            let succeeded = event?.succeeded ?? false
            let error = event?.error
            let kind: SyncEventKind
            switch event?.type {
            case .setup: kind = .setup
            case .import: kind = .import
            case .export: kind = .export
            default: return
            }
            guard finished else { return }
            Task { @MainActor in self?.record(kind, succeeded: succeeded, error: error) }
        })
        Task { await refreshAccount() }
    }

    private func refreshAccount() async {
        do {
            apply(account: try await CKContainer(identifier: StoreFactory.containerID).accountStatus())
        } catch {
            apply(account: .couldNotDetermine)
        }
    }

    /// Internal per i test: applica la risposta di `accountStatus()` senza CloudKit.
    func apply(account status: CKAccountStatus) {
        account = status
        recompute()
    }

    /// Internal per i test. Un evento riuscito azzera l'errore del suo tipo; uno fallito senza errore non cambia nulla.
    func record(_ kind: SyncEventKind, succeeded: Bool, error: Error?) {
        if succeeded {
            lastErrors[kind] = nil
        } else if let error {
            lastErrors[kind] = error
        }
        recompute()
    }

    /// L'errore di quota, se c'è in un tipo qualunque (non deve lampeggiare); altrimenti uno qualsiasi.
    private var relevantError: Error? {
        let errors = Array(lastErrors.values)
        return errors.first(where: SyncRules.isQuotaExceeded) ?? errors.first
    }

    private func recompute() {
        // Finché l'account non è noto lo stato resta quello iniziale (niente lampo dell'avviso).
        guard let account else { return }
        state = SyncRules.state(health: health, account: account, lastError: relevantError)
    }
}
