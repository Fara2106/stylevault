import SwiftUI

/// Il tema scelto nel Profilo (Chiaro · Scuro · Sistema).
enum ThemeStore {
    /// nil = "Sistema": segue l'aspetto del dispositivo.
    static func colorScheme(for setting: String) -> ColorScheme? {
        switch setting {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}
