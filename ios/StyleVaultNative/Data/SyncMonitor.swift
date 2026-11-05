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

@MainActor @Observable
final class SyncMonitor {
    private(set) var state: SyncState

    @ObservationIgnored private let health: StoreHealth
    @ObservationIgnored private var account: CKAccountStatus?  // nil = non ancora noto
    @ObservationIgnored private var lastError: Error?
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
            guard finished else { return }
            Task { @MainActor in self?.record(succeeded: succeeded, error: error) }
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

    func record(succeeded: Bool, error: Error?) {
        lastError = succeeded ? nil : error
        recompute()
    }

    private func recompute() {
        // Finché l'account non è noto lo stato resta quello iniziale (niente lampo dell'avviso).
        guard let account else { return }
        state = SyncRules.state(health: health, account: account, lastError: lastError)
    }
}
