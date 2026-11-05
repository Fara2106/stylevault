import CryptoKit
import AuthenticationServices
import Foundation
import Supabase

/// Client Supabase unico dell'app. La sessione resta nel Portachiavi
/// (default di supabase-swift) e il login Google torna con lo schema dell'app (AppConfig.authCallback).
enum Supa {
    /// emitLocalSessionAsInitialSession: senza rete si entra lo stesso con la
    /// sessione salvata (poi si rinnova in background) invece di finire sul login.
    static let authOptions = SupabaseClientOptions.AuthOptions(
        redirectToURL: AppConfig.authCallback, flowType: .pkce, emitLocalSessionAsInitialSession: true
    )

    static let client = SupabaseClient(
        supabaseURL: AppConfig.supabaseURL,
        supabaseKey: AppConfig.supabaseKey,
        options: .init(auth: authOptions)
    )
}

/// Il valore che lega la risposta di Apple a questa richiesta: ad Apple va cifrato, a Supabase in chiaro.
struct AppleNonce {
    let raw: String

    init(raw: String = UUID().uuidString) { self.raw = raw }

    var hashed: String {
        SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// Apple manda il nome solo al primo accesso: nil vuol dire "lascia quello salvato".
    static func displayName(_ components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let name = [components.givenName, components.familyName].compactMap { $0 }.joined(separator: " ")
        return name.isEmpty ? nil : name
    }
}

/// Apple ha detto sì ma senza il token da dare a Supabase.
struct AppleTokenMissing: LocalizedError {
    var errorDescription: String? { "Apple non ha completato l'accesso: riprova." }
}

/// Errori di login in forma leggibile, con gli stessi testi del sito (auth.errors.*).
enum AuthErrorKind: Equatable {
    case invalidCredentials, emailTaken, weakPassword, samePassword, tooManyEmails, cancelled, unreachable
    case other(String)

    static func from(_ error: Error) -> AuthErrorKind {
        if let web = error as? ASWebAuthenticationSessionError, web.code == .canceledLogin {
            return .cancelled
        }
        if let apple = error as? ASAuthorizationError, apple.code == .canceled { return .cancelled }
        if let auth = error as? AuthError, case let .api(message, code, _, _) = auth {
            switch code {
            case .invalidCredentials: return .invalidCredentials
            case .userAlreadyExists, .emailExists: return .emailTaken
            case .weakPassword: return .weakPassword
            case .samePassword: return .samePassword
            case .overEmailSendRateLimit: return .tooManyEmails
            default: return .other(message)
            }
        }
        if error is URLError { return .unreachable }
        return .other(error.localizedDescription)
    }

    /// nil per "annullato": chi chiude il login Google non vede un errore rosso.
    var message: String? {
        switch self {
        case .invalidCredentials: return "Email o password non corrette."
        case .emailTaken: return "Esiste già un account con questa email: prova ad accedere."
        case .weakPassword: return "La password deve avere almeno 6 caratteri."
        case .samePassword: return "La nuova password deve essere diversa da quella vecchia."
        case .tooManyEmails: return "Hai già chiesto un'email da poco: aspetta qualche minuto e riprova."
        case .unreachable: return "Il servizio online non risponde. Controlla la connessione e riprova."
        case .cancelled: return nil
        case let .other(text): return text
        }
    }
}

/// Stato del login nativo: email/password, Google e (quando attivo) Apple.
@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var session: Session?
    @Published private(set) var restoring = true
    /// Il bottone Google compare solo se il provider è attivo su Supabase
    /// (come sul sito): spento, darebbe solo un errore.
    @Published private(set) var googleAvailable = false
    /// Dopo il link dell'email di reset si ha già una sessione, ma si entra
    /// solo dopo aver scelto la nuova password.
    @Published private(set) var recovering = false
    @Published private(set) var recoveryLinkFailed = false

    private let client: SupabaseClient

    init(client: SupabaseClient = Supa.client) {
        self.client = client
        // Il primo evento è la sessione salvata (o nessuna): poi ogni login,
        // logout e rinnovo del token.
        Task { [weak self] in
            for await (_, session) in client.auth.authStateChanges {
                self?.session = session
                self?.restoring = false
            }
        }
    }

    nonisolated static func googleEnabled(in settingsJSON: Data) -> Bool {
        let json = try? JSONSerialization.jsonObject(with: settingsJSON) as? [String: Any]
        return (json?["external"] as? [String: Any])?["google"] as? Bool ?? false
    }

    func refreshProviders() async {
        var request = URLRequest(url: AppConfig.supabaseURL.appendingPathComponent("auth/v1/settings"))
        request.setValue(AppConfig.supabaseKey, forHTTPHeaderField: "apikey")
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return }
        googleAvailable = Self.googleEnabled(in: data)
    }

    func signIn(email: String, password: String) async throws {
        session = try await client.auth.signIn(email: email, password: password)
    }

    func signUp(name: String, email: String, password: String) async throws {
        let response = try await client.auth.signUp(
            email: email, password: password, data: ["name": .string(name)]
        )
        session = response.session
    }

    nonisolated static func isRecoveryLink(_ url: URL) -> Bool {
        url.scheme == AppConfig.recoveryCallback.scheme && url.host == AppConfig.recoveryCallback.host
    }

    func sendPasswordReset(email: String) async throws {
        recoveryLinkFailed = false
        try await client.auth.resetPasswordForEmail(email, redirectTo: AppConfig.recoveryCallback)
    }

    /// Il link dell'email riapre l'app con un codice (PKCE): si scambia con
    /// una sessione. Un link scaduto o aperto su un altro telefono fallisce.
    func handle(_ url: URL) async {
        guard Self.isRecoveryLink(url) else { return }
        recovering = true
        do {
            session = try await client.auth.session(from: url)
        } catch {
            recovering = false
            recoveryLinkFailed = true
        }
    }

    func updatePassword(_ password: String) async throws {
        _ = try await client.auth.update(user: UserAttributes(password: password))
        recovering = false
    }

    func signInWithGoogle() async throws {
        session = try await client.auth.signInWithOAuth(
            provider: .google, redirectTo: AppConfig.authCallback
        )
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential, nonce: AppleNonce) async throws {
        guard let data = credential.identityToken, let token = String(data: data, encoding: .utf8) else {
            throw AppleTokenMissing()
        }
        session = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(provider: .apple, idToken: token, nonce: nonce.raw)
        )
        if let name = AppleNonce.displayName(credential.fullName) {
            _ = try? await client.auth.update(user: UserAttributes(data: ["name": .string(name)]))
        }
    }

    /// Cancella l'account di chi è entrato (Apple 5.1.1(v)). L'utente non esiste più: si chiude la sessione locale.
    func deleteAccount() async throws {
        struct Confirmation: Encodable { let confirm = "DELETE" }
        try await client.functions.invoke("delete-account", options: FunctionInvokeOptions(body: Confirmation()))
        try? await client.auth.signOut(scope: .local)
        session = nil
        recovering = false
    }

    func signOut() async {
        try? await client.auth.signOut()
        session = nil
        recovering = false
    }
}
