import Foundation

public enum SensitiveKind: String, CaseIterable, Sendable {
    case email, iban, number

    public var labelKey: String {
        switch self {
        case .email: return "feedback.sensitiveEmail"
        case .iban: return "feedback.sensitiveIban"
        case .number: return "feedback.sensitiveNumber"
        }
    }
}

/// Le regole delle segnalazioni. Sono le stesse di `redactSensitive` nella funzione `send-feedback`:
/// qui fermano l'invio e spiegano cosa togliere, là sono la rete di sicurezza.
public enum FeedbackRules {
    public static let minimum = 10
    public static let maximum = 2000

    private static let patterns: [(SensitiveKind, String)] = [
        (.email, #"[^\s@]+@[^\s@]+\.[^\s@]+"#),
        (.iban, #"\b[A-Z]{2}\d{2}(?:\s?[A-Z0-9]){11,30}\b"#),
        (.number, #"\+?\d(?:[\s./-]?\d){8,}"#),
    ]

    public static func sensitive(in text: String) -> [SensitiveKind] {
        patterns.compactMap { kind, pattern in
            text.range(of: pattern, options: .regularExpression) == nil ? nil : kind
        }
    }

    public static func canSend(_ text: String) -> Bool {
        let length = text.trimmingCharacters(in: .whitespacesAndNewlines).count
        return (minimum...maximum).contains(length) && sensitive(in: text).isEmpty
    }

    public static func deviceInfo(appVersion: String, osVersion: String, model: String, language: String) -> [String: String] {
        let info = ["source": "app iOS", "appVersion": appVersion, "osVersion": osVersion, "model": model, "language": language]
        return info.filter { !$0.value.isEmpty }
    }
}
