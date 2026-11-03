import SwiftUI

/// Il tema scelto nel Profilo del sito (Chiaro · Scuro · Sistema) vale anche
/// per le schermate native. Arriva col messaggio themeChanged e resta salvato
/// per il prossimo avvio (login compreso).
enum ThemeStore {
    static let key = "sv_theme"

    /// nil = "Sistema": segue l'aspetto dell'iPhone.
    static func colorScheme(for setting: String) -> ColorScheme? {
        switch setting {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}
