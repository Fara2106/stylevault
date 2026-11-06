import Foundation

/// Un capo come lo vede l'algoritmo: senza foto, così resta fuori da SwiftData.
public struct OutfitPiece: Identifiable, Equatable, Sendable {
    public let id: String
    public let category: String
    public let subcategory: String?
    public let colors: [String]
    public let season: String
    public let occasion: String
    public let warmthLevel: Int
    public let price: Double?

    public init(id: String, category: String, subcategory: String? = nil, colors: [String] = [], season: String = "all",
                occasion: String = "casual", warmthLevel: Int = 2, price: Double? = nil) {
        self.id = id
        self.category = category
        self.subcategory = subcategory
        self.colors = colors
        self.season = season
        self.occasion = occasion
        self.warmthLevel = warmthLevel
        self.price = price
    }

    /// `item.warmthLevel || 2` del sito.
    var warmth: Int { warmthLevel == 0 ? 2 : warmthLevel }
}

public enum MissingPiece: String, Equatable, Sendable { case top, bottom, shoes }

public struct RecentWear: Equatable, Sendable {
    public let itemID: String
    public let date: String

    public init(itemID: String, date: String) {
        self.itemID = itemID
        self.date = date
    }
}

public struct GeneratedOutfit: Identifiable, Equatable, Sendable {
    public var id = UUID()
    /// Con un abito, l'abito sta qui e `bottom` resta vuoto.
    public var top: OutfitPiece?
    public var bottom: OutfitPiece?
    public var shoes: OutfitPiece?
    public var outerwear: OutfitPiece?
    public var accessories: [OutfitPiece]
    public var score: Int
    public var weatherMatch: Int
    public var colorHarmony: Int
    public var repetitionPenalty: Int

    public init(top: OutfitPiece? = nil, bottom: OutfitPiece? = nil, shoes: OutfitPiece? = nil, outerwear: OutfitPiece? = nil,
                accessories: [OutfitPiece] = [], score: Int = 0, weatherMatch: Int = 0, colorHarmony: Int = 0,
                repetitionPenalty: Int = 0) {
        self.top = top
        self.bottom = bottom
        self.shoes = shoes
        self.outerwear = outerwear
        self.accessories = accessories
        self.score = score
        self.weatherMatch = weatherMatch
        self.colorHarmony = colorHarmony
        self.repetitionPenalty = repetitionPenalty
    }

    public var isDress: Bool { top?.category == "dresses" }

    var corePieces: [OutfitPiece] { [top, bottom, shoes, outerwear].compactMap { $0 } }

    /// Tutti i capi, accessori compresi, nell'ordine in cui si mostrano.
    public var pieces: [OutfitPiece] { corePieces + accessories }

    public var missing: [MissingPiece] {
        var result: [MissingPiece] = []
        if top == nil { result.append(.top) }
        if bottom == nil, !isDress { result.append(.bottom) }
        if shoes == nil { result.append(.shoes) }
        return result
    }

    fileprivate var duplicateKey: [String?] { [top?.id, bottom?.id, shoes?.id, outerwear?.id] }
}

/// Gli outfit di un giorno, come src/utils/outfitAlgorithm.js: stessi pesi, soglie e ripieghi.
/// Non si blocca mai: un pezzo che manca diventa un avviso. Unica eccezione, nessun capo da indossare.
public enum OutfitEngine {
    private static func hexColors(of piece: OutfitPiece) -> [String] {
        piece.colors.compactMap { Catalog.color(id: $0)?.hex }
    }

    private static func season(of date: String) -> String {
        let month = date.split(separator: "-").dropFirst().first.flatMap { Int($0) } ?? 1
        switch month {
        case 3...5: return "spring"
        case 6...8: return "summer"
        case 9...11: return "autumn"
        default: return "winter"
        }
    }

    private static func matchesSeason(_ piece: OutfitPiece, _ season: String) -> Bool {
        piece.season == "all" || season == "all" || piece.season == season
    }

    private static func matchesOccasion(_ piece: OutfitPiece, _ occasion: String) -> Bool {
        if occasion.isEmpty || occasion == "all" { return true }
        if piece.occasion == "casual", occasion == "casual" || occasion == "sport" { return true }
        return piece.occasion == occasion
    }

    /// Da 1 (leggerissimo) a 5 (pesante), col vento che raffredda.
    public static func warmthTarget(temperature: Double, windSpeed: Double) -> Int {
        var effective = temperature
        if temperature <= 10, windSpeed > 4.8 {
            let wind = pow(windSpeed, 0.16)
            effective = 13.12 + 0.6215 * temperature - 11.37 * wind + 0.3965 * temperature * wind
        } else if temperature < 20 {
            effective = temperature - windSpeed * 0.1
        }
        if effective >= 30 { return 1 }
        if effective >= 22 { return 2 }
        if effective >= 15 { return 3 }
        if effective >= 5 { return 4 }
        return 5
    }

    private static func warmthScore(_ warmth: Int, target: Int) -> Int {
        switch abs(warmth - target) {
        case 0: return 100
        case 1: return 75
        case 2: return 40
        default: return 10
        }
    }

    private static func pickBest<G: RandomNumberGenerator>(_ pieces: [OutfitPiece], target: Int, count: Int = 3,
                                                           using rng: inout G) -> [OutfitPiece] {
        // `sort` di Swift non promette di tenere l'ordine a parità: l'indice lo rende uguale al sito.
        let sorted = pieces.enumerated()
            .map { (offset: $0.offset, piece: $0.element, score: warmthScore($0.element.warmth, target: target)) }
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.offset < $1.offset }
            .map(\.piece)
        let top = sorted.prefix(min(sorted.count, max(count * 2, 5)))
        return Array(top.shuffled(using: &rng).prefix(count))
    }

    private static func pick<G: RandomNumberGenerator>(_ pieces: [OutfitPiece], target: Int, using rng: inout G) -> OutfitPiece? {
        pickBest(pieces, target: target, using: &rng).randomElement(using: &rng)
    }

    private static func weatherMatch(_ outfit: GeneratedOutfit, target: Int, weather: DayForecast) -> Int {
        let core = outfit.corePieces
        let average = Double(core.map(\.warmth).reduce(0, +)) / Double(core.count)
        var score = max(0, 100 - abs(average - Double(target)) * 25)
        if weather.rain {
            let hasRainGear = outfit.outerwear?.subcategory == "raincoat"
                || outfit.accessories.contains { $0.subcategory == "umbrella" }
            score = hasRainGear ? min(100, score + 15) : max(0, score - 10)
        }
        if weather.uvIndex >= 6, outfit.accessories.contains(where: { $0.subcategory == "sunglasses" }) {
            score = min(100, score + 5)
        }
        if weather.temperature < 5, (outfit.outerwear?.warmthLevel ?? 0) >= 4 {
            score = min(100, score + 10)
        }
        return jsRound(score)
    }

    private static func colorHarmony(_ outfit: GeneratedOutfit) -> Int {
        let colors = outfit.pieces.flatMap(hexColors)
        return colors.isEmpty ? 70 : ColorHarmony.score(colors)
    }

    private static func penalties(_ recentWear: [RecentWear], reference: String) -> [String: Double] {
        var result: [String: Double] = [:]
        for wear in recentWear {
            guard let days = CalendarMath.daysBetween(wear.date, and: reference), (0...7).contains(days) else { continue }
            result[wear.itemID] = max(result[wear.itemID] ?? 0, max(0, 12 - 1.5 * Double(days)))
        }
        return result
    }

    private struct Locked {
        var top: OutfitPiece?
        var bottom: OutfitPiece?
        var shoes: OutfitPiece?
        var outerwear: OutfitPiece?

        init(_ pieces: [OutfitPiece]) {
            for piece in pieces {
                switch piece.category {
                case "tops", "dresses": top = piece
                case "bottoms": bottom = piece
                case "shoes": shoes = piece
                case "outerwear": outerwear = piece
                default: break
                }
            }
        }
    }

    public static func generate<G: RandomNumberGenerator>(
        items: [OutfitPiece], weather: DayForecast, occasion: String = "all", count: Int = 3,
        locked lockedItems: [OutfitPiece] = [], recentWear: [RecentWear] = [], referenceDate: String? = nil,
        using rng: inout G
    ) -> [GeneratedOutfit] {
        guard !items.isEmpty else { return [] }
        let locked = Locked(lockedItems)
        let penaltyMap = penalties(recentWear, reference: referenceDate ?? weather.date)
        let currentSeason = season(of: weather.date)
        let target = warmthTarget(temperature: weather.temperature, windSpeed: weather.windSpeed)
        let filtered = items.filter { matchesSeason($0, currentSeason) && matchesOccasion($0, occasion) }

        // Se per la stagione e l'occasione non c'è niente, tutti quelli della categoria:
        // meglio un outfit fuori stagione che nessuno.
        func pool(_ category: String) -> [OutfitPiece] {
            let fit = filtered.filter { $0.category == category }
            return fit.isEmpty ? items.filter { $0.category == category } : fit
        }
        let tops = pool("tops")
        let bottoms = pool("bottoms")
        let shoes = pool("shoes")
        let anyDresses = pool("dresses")
        let outerwear = filtered.filter { $0.category == "outerwear" }
        let accessories = filtered.filter { $0.category == "accessories" }
        let dresses = filtered.filter { $0.category == "dresses" }
        let canUseDress = (occasion == "formal" || occasion == "evening") && !dresses.isEmpty

        var outfits: [GeneratedOutfit] = []
        var attempts = 0
        while outfits.count < count, attempts < count * 5 {
            attempts += 1
            var outfit = GeneratedOutfit()

            let lockedDress = locked.top?.category == "dresses" ? locked.top : nil
            let missingSeparates = tops.isEmpty || bottoms.isEmpty
            let chance = Double.random(in: 0..<1, using: &rng)
            let useDress = lockedDress != nil
                || (locked.bottom == nil && locked.top == nil && !anyDresses.isEmpty
                    && ((canUseDress && (chance > 0.5 || missingSeparates)) || (tops.isEmpty && bottoms.isEmpty)))

            if useDress {
                guard let dress = lockedDress ?? pickBest(canUseDress ? dresses : anyDresses, target: target, using: &rng)
                    .randomElement(using: &rng) else { continue }
                outfit.top = dress
            } else {
                outfit.top = locked.top ?? pick(tops, target: target, using: &rng)
                outfit.bottom = locked.bottom ?? pick(bottoms, target: target, using: &rng)
            }
            outfit.shoes = locked.shoes ?? pick(shoes, target: target, using: &rng)

            if let lockedOuter = locked.outerwear {
                outfit.outerwear = lockedOuter
            } else if weather.temperature < 18 || weather.rain {
                outfit.outerwear = pick(outerwear, target: target, using: &rng)
            }

            var chosen: [OutfitPiece] = []
            func add(_ subcategory: String) {
                if let piece = accessories.filter({ $0.subcategory == subcategory }).randomElement(using: &rng) {
                    chosen.append(piece)
                }
            }
            if weather.rain { add("umbrella") }
            if weather.uvIndex >= 5, !weather.rain { add("sunglasses") }
            if weather.temperature < 10 { add("scarf") }
            if weather.temperature < 5 || weather.uvIndex >= 8 { add("hat") }
            let style = accessories.filter {
                !chosen.contains($0) && ["bag", "watch", "jewelry", "belt"].contains($0.subcategory ?? "")
            }
            if !style.isEmpty, Double.random(in: 0..<1, using: &rng) > 0.4, let piece = style.randomElement(using: &rng) {
                chosen.append(piece)
            }
            outfit.accessories = chosen

            // I soli accessori non fanno un outfit.
            guard !outfit.corePieces.isEmpty else { continue }

            outfit.weatherMatch = weatherMatch(outfit, target: target, weather: weather)
            outfit.colorHarmony = colorHarmony(outfit)
            let base = Double(outfit.weatherMatch) * 0.5 + Double(outfit.colorHarmony) * 0.5
            let penalty = outfit.pieces.reduce(0) { $0 + (penaltyMap[$1.id] ?? 0) }
            outfit.repetitionPenalty = jsRound(penalty)
            outfit.score = max(0, jsRound(base - penalty))

            if !outfits.contains(where: { $0.duplicateKey == outfit.duplicateKey }) { outfits.append(outfit) }
        }
        return outfits.enumerated()
            .sorted { $0.element.score != $1.element.score ? $0.element.score > $1.element.score : $0.offset < $1.offset }
            .map(\.element)
            .prefix(count)
            .map { $0 }
    }
}
