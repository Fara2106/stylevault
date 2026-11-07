import Foundation

/// Configurazione degli account. URL e chiave pubblica arrivano da Config/Secrets.xcconfig via Info.plist.
/// Lo schema `svnativa` è quello registrato nei Redirect URLs di Supabase.
enum AppConfig {
    static let supabaseURL: URL = {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String,
              let url = URL(string: raw) else {
            fatalError("SupabaseURL mancante: crea ios/Config/Secrets.xcconfig")
        }
        return url
    }()

    static let supabaseKey: String = {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SupabaseKey") as? String, !key.isEmpty else {
            fatalError("SupabaseKey mancante: crea ios/Config/Secrets.xcconfig")
        }
        return key
    }()

    static let authCallback = URL(string: "svnativa://auth-callback")!
    static let recoveryCallback = URL(string: "svnativa://reset-password")!
    static let supportEmail = "lorefara97@gmail.com"
    static let supportMail = URL(string: "mailto:\(supportEmail)?subject=StyleVault")!
    static let privacyURL = URL(string: "https://fara2106.github.io/stylevault/privacy")!
    static let supportURL = URL(string: "https://fara2106.github.io/stylevault/supporto")!
}
