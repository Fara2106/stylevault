import Foundation

public struct PaletteMatch: Equatable, Sendable {
    public let id: String
    public let distance: Double
    public let paletteHex: String
}

/// Capi "in palette": il deltaE minimo fra i colori del capo e palette e neutri della stagione.
public enum ArmocromiaWardrobe {
    public static let inPaletteMax = 25.0

    public static func match(_ items: [(id: String, colors: [String])], season seasonID: String) -> [PaletteMatch] {
        guard let season = ArmocromiaSeasons.season(id: seasonID) else { return [] }
        let palette = (season.palette + season.neutrals).compactMap { color in
            ColorLab.lab(hex: color.hex).map { (color.hex, $0) }
        }
        let matches = items.compactMap { item -> PaletteMatch? in
            var best: PaletteMatch?
            for colorID in item.colors {
                guard let hex = Catalog.colors.first(where: { $0.id == colorID })?.hex,
                      let lab = ColorLab.lab(hex: hex) else { continue }
                for (paletteHex, paletteLab) in palette {
                    let distance = ColorLab.deltaE(lab, paletteLab)
                    if distance < (best?.distance ?? .infinity) {
                        best = PaletteMatch(id: item.id, distance: distance, paletteHex: paletteHex)
                    }
                }
            }
            return best.flatMap { $0.distance <= inPaletteMax ? $0 : nil }
        }
        return matches.sorted { $0.distance < $1.distance }
    }
}
