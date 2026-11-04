import Foundation

/// Configurazione dell'app. URL e chiave Supabase arrivano da
/// Config/Secrets.xcconfig (generato da .env.local, non in git) via Info.plist.
enum AppConfig {
    static let supabaseURL: URL = {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String,
              let url = URL(string: raw) else {
            fatalError("SupabaseURL mancante: crea ios/Config/Secrets.xcconfig")
        }
        return url
    }()

    static let supabaseKey: String = {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SupabaseKey") as? String,
              !key.isEmpty else {
            fatalError("SupabaseKey mancante: crea ios/Config/Secrets.xcconfig")
        }
        return key
    }()

    /// Il sito dentro l'app. In DEBUG il dev server locale in modalità cloud
    /// (porta 5181): sul simulatore localhost; su un iPhone vero l'IP del Mac,
    /// da SITE_URL in Secrets.xcconfig. In Release il sito pubblicato.
    #if DEBUG
    static let siteURL: URL = {
        if let raw = Bundle.main.object(forInfoDictionaryKey: "SiteURL") as? String,
           !raw.isEmpty, let url = URL(string: raw) {
            return url
        }
        return URL(string: "http://localhost:5181/")!
    }()
    #else
    static let siteURL = URL(string: "https://fara2106.github.io/stylevault/")!
    #endif

    /// Pagine pubbliche del sito pubblicato (anche in Debug: sono le stesse
    /// indicate in App Store Connect).
    static let privacyURL = URL(string: "https://fara2106.github.io/stylevault/privacy")!
    static let supportURL = URL(string: "https://fara2106.github.io/stylevault/supporto")!

    /// Redirect del login Google (schema URL registrato in project.yml).
    static let authCallback = URL(string: "stylevault://auth-callback")!

    /// Dove riporta il link dell'email "Password dimenticata?" (va tra le
    /// Redirect URLs di Supabase, come quello di Google).
    static let recoveryCallback = URL(string: "stylevault://reset-password")!

    /// "Accedi con Apple" richiede l'Apple Developer Program a pagamento:
    /// resta spento finché Lorenzo non si iscrive.
    static let appleSignInEnabled = false
}
