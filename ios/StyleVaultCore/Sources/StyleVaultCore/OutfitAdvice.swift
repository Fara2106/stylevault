import Foundation

public enum OutfitAdvice: Equatable, Sendable {
    case tooManyColors, monochrome, colorsHarmonious, colorsClash
    case tooLight(temp: Int), tooWarm(temp: Int), perfectWarmth
    case layers(cold: Int, coldPart: DayPartKey, warm: Int, warmPart: DayPartKey)
    case rainLater(hour: String), rainShoes, rainOuter
    case uvHigh, windStrong
    case wornRecently(date: String)
    case elevated
}

/// Consigli di stile. Nessuna IA: regole sugli stessi punteggi degli outfit.
public enum OutfitAdvisor {
    private static let neutralColors: Set<String> = ["black", "white", "gray", "beige", "navy", "cream", "brown", "tan",
                                                     "khaki", "denim", "silver"]
    private static let openShoes: Set<String> = ["sandals", "heels", "pumps"]
    private static let elevatingOuterwear: Set<String> = ["blazer", "coat", "trench"]
    private static let layersMinimumSpread = 8.0

    public static func advice(for outfit: GeneratedOutfit, weather: DayForecast, recentWear: [RecentWear] = [],
                              occasion: String? = nil) -> [OutfitAdvice] {
        let pieces = outfit.pieces
        guard !pieces.isEmpty else { return [] }
        var result: [OutfitAdvice] = []

        var uniqueColors: [String] = []
        for color in pieces.flatMap(\.colors) where !uniqueColors.contains(color) { uniqueColors.append(color) }
        let chromatic = uniqueColors.filter { !neutralColors.contains($0) }
        if chromatic.count > 3 {
            result.append(.tooManyColors)
        } else if outfit.colorHarmony >= 80 {
            result.append(uniqueColors.filter { Catalog.color(id: $0) != nil }.count <= 1 ? .monochrome : .colorsHarmonious)
        } else if outfit.colorHarmony < 50 {
            result.append(.colorsClash)
        }

        let target = Double(OutfitEngine.warmthTarget(temperature: weather.temperature, windSpeed: weather.windSpeed))
        let core = outfit.corePieces
        if !core.isEmpty {
            let average = Double(core.map(\.warmth).reduce(0, +)) / Double(core.count)
            let temperature = jsRound(weather.temperature)
            if average < target - 1 {
                result.append(.tooLight(temp: temperature))
            } else if average > target + 1 {
                result.append(.tooWarm(temp: temperature))
            } else if abs(average - target) <= 0.5 {
                result.append(.perfectWarmth)
            }
        }

        if let layers = layers(weather.parts) { result.append(layers) }
        if weather.parts != nil, let from = weather.rainFrom, !weather.rainFromStart {
            result.append(.rainLater(hour: String(format: "%02d:00", from)))
        }

        if weather.rain {
            if let shoes = outfit.shoes, openShoes.contains(shoes.subcategory ?? "") { result.append(.rainShoes) }
            if outfit.outerwear == nil, weather.temperature < 22 { result.append(.rainOuter) }
        }
        if weather.uvIndex >= 8, !weather.rain { result.append(.uvHigh) }
        if weather.windSpeed > 25 { result.append(.windStrong) }

        let ids = Set(pieces.map(\.id))
        if let recent = recentWear.filter({ ids.contains($0.itemID) }).max(by: { $0.date < $1.date }) {
            result.append(.wornRecently(date: recent.date))
        }

        if let subcategory = outfit.outerwear?.subcategory, elevatingOuterwear.contains(subcategory),
           occasion == "casual" || occasion == nil || occasion?.isEmpty == true {
            result.append(.elevated)
        }
        return result
    }

    private static func layers(_ parts: [DayPart]?) -> OutfitAdvice? {
        let upcoming = (parts ?? []).compactMap { part in
            part.past ? nil : part.temperature.map { (key: part.key, temperature: $0) }
        }
        guard upcoming.count >= 2,
              let cold = upcoming.reduce(nil, { (a: (key: DayPartKey, temperature: Double)?, b) in
                  a.map { b.temperature < $0.temperature ? b : $0 } ?? b
              }),
              let warm = upcoming.reduce(nil, { (a: (key: DayPartKey, temperature: Double)?, b) in
                  a.map { b.temperature > $0.temperature ? b : $0 } ?? b
              }),
              warm.temperature - cold.temperature >= layersMinimumSpread else { return nil }
        return .layers(cold: jsRound(cold.temperature), coldPart: cold.key, warm: jsRound(warm.temperature), warmPart: warm.key)
    }
}
