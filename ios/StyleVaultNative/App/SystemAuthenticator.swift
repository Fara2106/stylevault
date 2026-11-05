import LocalAuthentication

/// Face ID o Touch ID, poi il codice del dispositivo. È l'unico file che conosce `LocalAuthentication`.
struct SystemAuthenticator: DeviceAuthenticating {
    var isAvailable: Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    func authenticate(reason: String) async -> AuthOutcome {
        do {
            let ok = try await LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            return ok ? .success : .failed
        } catch let error as LAError {
            switch error.code {
            case .passcodeNotSet, .biometryNotAvailable, .biometryNotEnrolled:
                return .unavailable
            default:
                return .failed // annullata, non riconosciuto, ecc.
            }
        } catch {
            return .failed
        }
    }
}

#if DEBUG
/// Per i test UI: il simulatore non ha Face ID registrato. Riesce sempre; con `cancelFirst` la prima richiesta
/// è "annullata", come se la persona chiudesse il foglio: resta la schermata di blocco col tasto Sblocca.
final class FakeAuthenticator: DeviceAuthenticating {
    private var cancelNext: Bool
    init(cancelFirst: Bool) { cancelNext = cancelFirst }
    var isAvailable: Bool { true }
    func authenticate(reason: String) async -> AuthOutcome {
        if cancelNext { cancelNext = false; return .failed }
        return .success
    }
}
#endif
