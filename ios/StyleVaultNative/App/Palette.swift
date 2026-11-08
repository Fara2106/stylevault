import SwiftUI
import UIKit

/// I colori dell'app, chiari e scuri.
enum Palette {
    static let bg = dynamic(light: 0xFAF7F2, dark: 0x141210)
    static let surface = dynamic(light: 0xFFFFFF, dark: 0x1D1A17)
    /// Dietro i capi scontornati, chiaro anche in modalità scura: un capo nero non sparisce.
    static let studio = dynamic(light: 0xF1ECE4, dark: 0xE6E0D7)
    static let ink = dynamic(light: 0x1A1A1A, dark: 0xF2EDE6)
    static let muted = dynamic(light: 0x6B6560, dark: 0xA39B91)
    static let border = dynamic(light: 0xE5DFD6, dark: 0x3A342E)
    static let accent = dynamic(light: 0x8B7355, dark: 0xC4A57F)
    /// I testi cliccabili: l'accento chiaro non arriva a 4.5:1 sullo sfondo.
    static let link = dynamic(light: 0x6B6560, dark: 0xC4A57F)
    static let danger = dynamic(light: 0x9D4040, dark: 0xE08A8A)

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

extension Font {
    /// Titoli editoriali: il serif di sistema (New York).
    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .regular, design: .serif) }
}
