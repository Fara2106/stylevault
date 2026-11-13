import Foundation
import StyleVaultCore
import SwiftUI

protocol FaceAnalyzing: Sendable {
    func analyze(_ data: Data) async throws -> FaceColors
}

struct SystemFaceAnalyzer: FaceAnalyzing {
    func analyze(_ data: Data) async throws -> FaceColors {
        guard let image = ImagePrep.decodedForAnalysis(data) else { return FaceColors() }
        return try await FaceColorAnalyzer.analyze(image)
    }
}

#if DEBUG
/// Vision non gira nel simulatore iOS 27: per i test UI, solo con `-SVFakeBody`.
struct FakeFaceAnalyzer: FaceAnalyzing {
    func analyze(_ data: Data) async throws -> FaceColors {
        FaceColors(skin: "#a9765c", hair: "#1d1a19", eyes: nil)
    }
}
#endif

private struct FaceAnalyzerKey: EnvironmentKey {
    static let defaultValue: any FaceAnalyzing = SystemFaceAnalyzer()
}

extension EnvironmentValues {
    var faceAnalyzer: any FaceAnalyzing {
        get { self[FaceAnalyzerKey.self] }
        set { self[FaceAnalyzerKey.self] = newValue }
    }
}

extension Color {
    /// Da `#rrggbb`; un valore non valido diventa un grigio caldo.
    init(hex: String) {
        let rgb = ColorLab.rgb(hex: hex) ?? RGB(r: 201, g: 184, b: 168)
        self.init(.sRGB, red: Double(rgb.r) / 255, green: Double(rgb.g) / 255, blue: Double(rgb.b) / 255)
    }

    /// Il colore in `#rrggbb`, nello spazio sRGB.
    var hexString: String {
        var (r, g, b, a): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        func byte(_ v: CGFloat) -> Int { max(0, min(255, Int((v * 255).rounded()))) }
        return ColorLab.hex(RGB(r: byte(r), g: byte(g), b: byte(b)))
    }
}

/// La lingua dei link ai negozi: l'inglese solo se l'app è in inglese.
enum ShopLanguage {
    static var current: String { Locale.current.language.languageCode?.identifier == "en" ? "en" : "it" }
}

func localized(_ key: String) -> String {
    String(localized: String.LocalizationValue(key))
}
