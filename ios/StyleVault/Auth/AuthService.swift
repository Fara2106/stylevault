import AuthenticationServices
import Foundation
import Supabase

/// Client Supabase unico dell'app. La sessione resta nel Portachiavi
/// (default di supabase-swift) e il login Google torna con stylevault://.
enum Supa {
    static let client = SupabaseClient(
        supabaseURL: AppConfig.supabaseURL,
        supabaseKey: AppConfig.supabaseKey,
        options: .init(auth: .init(redirectToURL: AppConfig.authCallback, flowType: .pkce))
    )
}

/// Errori di login in forma leggibile, con gli stessi testi del sito (auth.errors.*).
enum AuthErrorKind: Equatable {
    case invalidCredentials, emailTaken, weakPassword, cancelled, unreachable
    case other(String)

    static func from(_ error: Error) -> AuthErrorKind {
        if let web = error as? ASWebAuthenticationSessionError, web.code == .canceledLogin {
            return .cancelled
        }
        if let auth = error as? AuthError, case let .api(message, code, _, _) = auth {
            switch code {
            case .invalidCredentials: return .invalidCredentials
            case .userAlreadyExists, .emailExists: return .emailTaken
            case .weakPassword: return .weakPassword
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

    func signInWithGoogle() async throws {
        session = try await client.auth.signInWithOAuth(
            provider: .google, redirectTo: AppConfig.authCallback
        )
    }

    func signOut() async {
        try? await client.auth.signOut()
        session = nil
    }
}
