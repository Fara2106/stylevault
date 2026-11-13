import Foundation

/// Che cosa mostrare all'apertura. Si può entrare senza account: i dati stanno su iCloud e non dipendono da lui.
enum AuthRoute: Equatable {
    case loading, login, newPassword, app

    static func resolve(restoring: Bool, recovering: Bool, signedIn: Bool, skipped: Bool) -> AuthRoute {
        if recovering { return .newPassword }
        if signedIn || skipped { return .app }
        return restoring ? .loading : .login
    }
}

extension AuthErrorKind {
    /// La chiave del testo tradotto; nil per "annullato" e per i messaggi che arrivano già scritti dal servizio.
    var localizationKey: String? {
        switch self {
        case .invalidCredentials: return "auth.errors.invalid-credentials"
        case .emailTaken: return "auth.errors.email-taken"
        case .weakPassword: return "auth.errors.password-too-short"
        case .samePassword: return "auth.errors.same-password"
        case .tooManyEmails: return "auth.errors.rate-limited"
        case .unreachable: return "native.auth.unreachable"
        case .cancelled, .appleFailed, .other: return nil
        }
    }

    var localizedMessage: String? {
        if case let .appleFailed(code) = self { return String(localized: "native.auth.appleFailed \(String(code))") }
        return localizationKey.map { String(localized: String.LocalizationValue($0)) } ?? message
    }
}
