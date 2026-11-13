// Disegna l'icona di Style Vault: gruccia color accento e sigla "SV" nel serif di sistema.
// La variante usata è "b"; "a" e "c" sono le prove scartate del 2026-11-08.
// Uso: swiftc -O icon.swift -o icon && ./icon b light icon-1024.png && ./icon b dark icon-1024-dark.png && ./icon b tinted icon-1024-tinted.png
// Poi copiare i tre PNG in ios/StyleVaultNative/Resources/Assets.xcassets/AppIcon.appiconset/.

import AppKit
import CoreText

let args = CommandLine.arguments
let variant = args[1]          // a, b, c
let mode = args[2]             // light, dark, tinted
let out = args[3]
let size: CGFloat = 1024

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}
let ink: UInt32 = 0x1A1A1A, cream: UInt32 = 0xFAF7F2, gold: UInt32 = 0xC4A57F, goldDark: UInt32 = 0x8B7355

let cs = mode == "tinted" ? CGColorSpaceCreateDeviceGray() : CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: (mode == "dark" ? CGImageAlphaInfo.premultipliedLast : CGImageAlphaInfo.noneSkipLast).rawValue)!
_ = cs
// Sfondo
let bg: CGColor, letters: CGColor, accent: CGColor
switch mode {
case "dark": bg = rgb(0x000000, 0); letters = rgb(cream); accent = rgb(gold)
case "tinted": bg = rgb(0x000000); letters = rgb(0xFFFFFF); accent = rgb(0xB0B0B0)
default: bg = rgb(ink); letters = rgb(cream); accent = rgb(gold)
}
ctx.setFillColor(bg); ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

func serif(_ pt: CGFloat, italic: Bool) -> CTFont {
    var desc = NSFont.systemFont(ofSize: pt).fontDescriptor.withDesign(.serif)!
    if italic { desc = desc.withSymbolicTraits(.italic) }
    return NSFont(descriptor: desc, size: pt)! as CTFont
}

/// Testo centrato otticamente: si centra il riquadro dei glifi, non la linea di base.
func drawCentered(_ text: String, font: CTFont, color: CGColor, centerY: CGFloat, tracking: CGFloat = 0) {
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .kern: tracking]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
    let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    ctx.textPosition = CGPoint(x: (size - bounds.width) / 2 - bounds.minX, y: centerY - bounds.height / 2 - bounds.minY)
    CTLineDraw(line, ctx)
}

func hanger(centerX: CGFloat, hookTop: CGFloat, shoulderY: CGFloat, baseY: CGFloat, halfWidth: CGFloat, width: CGFloat, color: CGColor) {
    // Coordinate con l'origine in basso: hookTop è il punto più alto.
    let neckY = shoulderY + (hookTop - shoulderY) * 0.42
    let path = CGMutablePath()
    // gancio
    let r = (hookTop - neckY) * 0.48
    let start = CGFloat.pi * 1.18
    path.move(to: CGPoint(x: centerX + r * cos(start), y: hookTop - r + r * sin(start)))
    path.addArc(center: CGPoint(x: centerX, y: hookTop - r), radius: r, startAngle: start, endAngle: -.pi * 0.5, clockwise: true)
    path.addQuadCurve(to: CGPoint(x: centerX, y: neckY), control: CGPoint(x: centerX, y: hookTop - 2 * r - (hookTop - 2 * r - neckY) * 0.2))
    // spalle e barra
    path.move(to: CGPoint(x: centerX, y: neckY))
    path.addLine(to: CGPoint(x: centerX - halfWidth, y: baseY))
    path.addLine(to: CGPoint(x: centerX + halfWidth, y: baseY))
    path.closeSubpath()
    ctx.addPath(path)
    ctx.setStrokeColor(color); ctx.setLineWidth(width); ctx.setLineJoin(.round); ctx.setLineCap(.round)
    ctx.strokePath()
}

switch variant {
case "a": // sigla centrata, nient'altro
    drawCentered("SV", font: serif(470, italic: true), color: letters, centerY: size / 2)
case "b": // gruccia sopra, sigla dentro il triangolo
    hanger(centerX: size / 2, hookTop: 818, shoulderY: 549, baseY: 224, halfWidth: 381, width: 34, color: accent)
    drawCentered("SV", font: serif(230, italic: true), color: letters, centerY: 366)
case "c": // sigla grande con la gruccia piccola sopra
    hanger(centerX: size / 2, hookTop: 820, shoulderY: 700, baseY: 640, halfWidth: 150, width: 16, color: accent)
    drawCentered("SV", font: serif(400, italic: true), color: letters, centerY: 430)
default: break
}

let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
