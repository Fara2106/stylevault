import Foundation

public struct SeasonColor: Equatable, Sendable, Hashable {
    public let hex: String
    /// Coda della chiave di testo `armocromia.colors.<id>`.
    public let id: String

    public init(hex: String, id: String) {
        self.hex = hex
        self.id = id
    }

    public var nameKey: String { "armocromia.colors.\(id)" }
}

public struct SeasonMakeup: Equatable, Sendable {
    public let lips: [SeasonColor]
    public let blush: [SeasonColor]
    public let eyes: [SeasonColor]
    public let undertone: String

    public init(lips: [SeasonColor], blush: [SeasonColor], eyes: [SeasonColor], undertone: String) {
        self.lips = lips
        self.blush = blush
        self.eyes = eyes
        self.undertone = undertone
    }
}

public struct ArmocromiaSeason: Identifiable, Equatable, Sendable {
    public let id: String
    public let palette: [SeasonColor]
    public let avoid: [SeasonColor]
    public let neutrals: [SeasonColor]
    public let metal: String
    public let makeup: SeasonMakeup

    public init(id: String, palette: [SeasonColor], avoid: [SeasonColor], neutrals: [SeasonColor],
                metal: String, makeup: SeasonMakeup) {
        self.id = id
        self.palette = palette
        self.avoid = avoid
        self.neutrals = neutrals
        self.metal = metal
        self.makeup = makeup
    }

    public var nameKey: String { "armocromia.seasons.\(id).name" }
    public var descKey: String { "armocromia.seasons.\(id).desc" }
    public var metalKey: String { "armocromia.metal.\(metal)" }
    public var undertoneKey: String { "armocromia.undertone.\(makeup.undertone)" }

    /// Tre abbinamenti dalla palette: maglia, pantaloni e scarpe.
    public var outfits: [[SeasonColor]] {
        [
            [palette[0], neutrals[0], neutrals[1]],
            [palette[1], palette[3], neutrals[0]],
            [palette[2], neutrals.count > 2 ? neutrals[2] : neutrals[0], palette[4]],
        ]
    }
}

public enum ArmocromiaSeasons {
    public static func season(id: String?) -> ArmocromiaSeason? {
        all.first { $0.id == id }
    }
}
