import LocalAuthentication

/// Face ID o Touch ID, poi il codice del dispositivo. È l'unico file che conosce `LocalAuthentication`.
struct SystemAuthenticator: DeviceAuthenticating {
    var isAvailable: Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    func authenticate(reason: String) async -> AuthOutcome {
        var error: NSError?
        guard LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return .unavailable }
        do {
            let ok = try await LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            return ok ? .success : .failed
        } catch let error as LAError {
            // Il codice del dispositivo c'è sempre: tutto il resto (annullata, non riconosciuto...) è un semplice fallimento.
            return error.code == .passcodeNotSet ? .unavailable : .failed
        } catch {
            return .failed
        }
    }
}

#if DEBUG
/// Per i test UI: il simulatore non ha Face ID registrato. Riesce sempre tranne una richiesta, "annullata"
/// come se la persona chiudesse il foglio: così resta la schermata di blocco col tasto Sblocca.
final class FakeAuthenticator: DeviceAuthenticating {
    private let failingCall: Int
    private var calls = 0
    /// Fallisce (come un foglio annullato) la richiesta numero `failingCall`; le altre riescono.
    init(failingCall: Int) { self.failingCall = failingCall }
    var isAvailable: Bool { true }
    func authenticate(reason: String) async -> AuthOutcome {
        calls += 1
        return calls == failingCall ? .failed : .success
    }
}
#endif
