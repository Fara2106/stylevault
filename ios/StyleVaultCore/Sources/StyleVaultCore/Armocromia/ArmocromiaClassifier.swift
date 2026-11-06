import Foundation

/// I colori di una persona, in esadecimale. Ognuno può mancare.
public struct FaceColors: Codable, Equatable, Sendable {
    public var skin: String?
    public var hair: String?
    public var eyes: String?

    public init(skin: String? = nil, hair: String? = nil, eyes: String? = nil) {
        self.skin = skin
        self.hair = hair
        self.eyes = eyes
    }
}

public struct SeasonAxes: Equatable, Sendable {
    public let lightDeep: Double
    public let warmCool: Double
    public let brightSoft: Double
}

public struct SeasonResult: Equatable, Sendable {
    public let season: String
    public let axes: SeasonAxes
    public let confidence: Double
}

/// Classificatore a 12 sotto-stagioni: tre assi da pelle, capelli e occhi in Lab, poi il centroide più
/// vicino. I numeri sono tarati sulle terne dei test: non si ritoccano senza rifare la taratura.
public enum ArmocromiaClassifier {
    static let centroids: [(String, SeasonAxes)] = [
        ("light-spring", .init(lightDeep: 0.9, warmCool: 0.5, brightSoft: -0.45)),
        ("light-summer", .init(lightDeep: 0.9, warmCool: -0.4, brightSoft: -0.85)),
        ("true-spring", .init(lightDeep: 0.3, warmCool: 1.3, brightSoft: 0.3)),
        ("true-summer", .init(lightDeep: 0.3, warmCool: -0.5, brightSoft: -0.5)),
        ("true-autumn", .init(lightDeep: -0.2, warmCool: 1.1, brightSoft: 0.1)),
        ("true-winter", .init(lightDeep: -0.3, warmCool: -0.7, brightSoft: -0.15)),
        ("bright-spring", .init(lightDeep: 0.3, warmCool: 0.85, brightSoft: 0.75)),
        ("bright-winter", .init(lightDeep: -0.25, warmCool: -0.85, brightSoft: 0.55)),
        ("soft-autumn", .init(lightDeep: 0.15, warmCool: 0.6, brightSoft: -0.45)),
        ("soft-summer", .init(lightDeep: 0.45, warmCool: -0.35, brightSoft: -0.9)),
        ("deep-autumn", .init(lightDeep: -0.55, warmCool: 1.0, brightSoft: 0.1)),
        ("deep-winter", .init(lightDeep: -0.75, warmCool: -0.3, brightSoft: -0.3)),
    ]

    /// Media pesata che ignora i termini assenti e rinormalizza i pesi.
    private static func weighted(_ pairs: [(Double?, Double)]) -> Double {
        let active = pairs.compactMap { value, weight in value.map { ($0, weight) } }
        let total = active.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return 0 }
        return active.reduce(0) { $0 + $1.0 * ($1.1 / total) }
    }

    static func axes(_ colors: FaceColors) -> SeasonAxes {
        let s = colors.skin.flatMap { ColorLab.lab(hex: $0) }
        let h = colors.hair.flatMap { ColorLab.lab(hex: $0) }
        let e = colors.eyes.flatMap { ColorLab.lab(hex: $0) }

        let value = weighted([(h?.L, 0.5), (s?.L, 0.35), (e?.L, 0.15)])
        let lightDeep = (value - 53) / 34

        func warm(_ lab: Lab, _ neutral: Double) -> Double { (lab.b - neutral) - 0.35 * max(0, lab.a - 14) }
        let warmCool = weighted([(s.map { warm($0, 15) }, 0.45), (h.map { warm($0, 10) }, 0.35),
                                 (e.map { $0.b - 2 }, 0.2)]) / 16

        func chroma(_ lab: Lab) -> Double { (lab.a * lab.a + lab.b * lab.b).squareRoot() }
        var contrast = 0.0
        if let s, let h { contrast = abs(s.L - h.L) }
        let brightSoft = (weighted([(e.map(chroma), 0.45), (s.map(chroma), 0.25), (h.map(chroma), 0.3)]) - 27) / 26
            + (contrast - 34) / 90
        return SeasonAxes(lightDeep: lightDeep, warmCool: warmCool, brightSoft: brightSoft)
    }

    public static func classify(_ colors: FaceColors) -> SeasonResult? {
        guard colors.skin != nil || colors.hair != nil else { return nil } // gli occhi da soli non bastano
        let a = axes(colors)
        func distance(_ c: SeasonAxes) -> Double {
            let (x, y, z) = (a.lightDeep - c.lightDeep, a.warmCool - c.warmCool, a.brightSoft - c.brightSoft)
            return (x * x + 1.4 * y * y + z * z).squareRoot()
        }
        let ranked = centroids.map { ($0.0, distance($0.1)) }.sorted { $0.1 < $1.1 }
        let (best, d1, d2) = (ranked[0].0, ranked[0].1, ranked[1].1)
        // Margine fra i due centroidi migliori: se sono vicini il verdetto è incerto.
        let confidence = ((d2 - d1) / (d2 + d1) * 100).rounded() / 100
        return SeasonResult(season: best, axes: a, confidence: confidence)
    }
}
