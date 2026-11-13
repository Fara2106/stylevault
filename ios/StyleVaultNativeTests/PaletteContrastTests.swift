import SwiftUI
import XCTest
@testable import StyleVaultNative

/// Il criterio Apple "Sufficient Contrast": almeno 4.5:1 per il testo, in chiaro e in scuro.
final class PaletteContrastTests: XCTestCase {
    private func hex(_ color: Color, _ style: UIUserInterfaceStyle) -> (CGFloat, CGFloat, CGFloat) {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
            .getRed(&red, green: &green, blue: &blue, alpha: nil)
        return (red, green, blue)
    }

    private func luminance(_ rgb: (CGFloat, CGFloat, CGFloat)) -> CGFloat {
        let parts = [rgb.0, rgb.1, rgb.2].map { $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
        return 0.2126 * parts[0] + 0.7152 * parts[1] + 0.0722 * parts[2]
    }

    private func contrast(_ first: Color, _ second: Color, _ style: UIUserInterfaceStyle) -> CGFloat {
        let values = [luminance(hex(first, style)), luminance(hex(second, style))].sorted()
        return (values[1] + 0.05) / (values[0] + 0.05)
    }

    func testITestiSiLeggonoInEntrambiITemi() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            for text in [Palette.ink, Palette.muted, Palette.link, Palette.danger] {
                for background in [Palette.bg, Palette.surface] {
                    XCTAssertGreaterThanOrEqual(contrast(text, background, style), 4.5)
                }
            }
        }
    }

    /// Il bianco su sfondo chiaro e il nero su sfondo scuro devono restare riconoscibili.
    func testIlBordoDeiColoriSiVede() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            XCTAssertGreaterThanOrEqual(contrast(Palette.muted, Palette.bg, style), 3)
            XCTAssertGreaterThanOrEqual(contrast(Palette.muted, Palette.surface, style), 3)
        }
    }
}
