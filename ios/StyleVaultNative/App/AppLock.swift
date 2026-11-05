import Observation
import SwiftUI

enum AuthOutcome: Equatable {
    case success
    case failed
    /// Il dispositivo non può autenticare (per esempio il codice è stato tolto).
    case unavailable
}

protocol DeviceAuthenticating {
    var isAvailable: Bool { get }
    func authenticate(reason: String) async -> AuthOutcome
}

/// Blocco facoltativo dell'app. La scelta vale per il dispositivo: sta in `UserDefaults`, non passa da iCloud.
/// Non conosce `LocalAuthentication`: parla con un `DeviceAuthenticating`, così si prova con uno finto.
@MainActor @Observable
final class AppLock {
    static let defaultsKey = "native.lock.enabled"

    private(set) var isEnabled: Bool
    private(set) var isLocked: Bool
    private(set) var isObscured = false

    var canEnable: Bool { authenticator.isAvailable }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let authenticator: DeviceAuthenticating
    @ObservationIgnored private var isAuthenticating = false
    /// Sale a ogni `.background`: un esito arrivato da una richiesta più vecchia non sblocca.
    @ObservationIgnored private var generation = 0

    init(defaults: UserDefaults, authenticator: DeviceAuthenticating) {
        self.defaults = defaults
        self.authenticator = authenticator
        let enabled = defaults.bool(forKey: Self.defaultsKey)
        isEnabled = enabled
        isLocked = enabled
    }

    /// Attivare e disattivare chiedono un'autenticazione riuscita; se fallisce il valore resta com'era.
    func setEnabled(_ value: Bool, reason: String) async {
        guard value != isEnabled, !isAuthenticating else { return }
        if value && !canEnable { return }
        isAuthenticating = true
        defer { isAuthenticating = false }
        let started = generation
        let outcome = await authenticator.authenticate(reason: reason)
        // Se il codice è sparito mentre si spegne, spegnere è l'unica via d'uscita sensata.
        guard outcome == .success || (outcome == .unavailable && !value) else { return }
        store(enabled: value)
        if started == generation { isLocked = false }
    }

    func unlock(reason: String) async {
        guard isLocked, !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }
        let started = generation
        switch await authenticator.authenticate(reason: reason) {
        case .success:
            if started == generation { isLocked = false }
        case .unavailable:
            // Mai chiudere la persona fuori dai suoi dati.
            store(enabled: false)
            isLocked = false
        case .failed:
            break
        }
    }

    /// Si blocca in `.background`, non in `.inactive`: il foglio di Face ID porta la scena in `.inactive`
    /// e bloccare lì creerebbe un ciclo. Da `.inactive` si copre soltanto.
    func sceneDidChange(to phase: ScenePhase) {
        isObscured = isEnabled && phase != .active
        if phase == .background { generation += 1 }
        if isEnabled && phase == .background { isLocked = true }
    }

    private func store(enabled: Bool) {
        isEnabled = enabled
        defaults.set(enabled, forKey: Self.defaultsKey)
        if !enabled { isObscured = false }
    }
}
