@testable import StyleVaultCore

func mk(_ id: String, _ category: String, subcategory: String? = nil, colors: [String] = ["black"],
        season: String = "all", occasion: String = "casual", warmth: Int = 2, price: Double? = nil) -> OutfitPiece {
    OutfitPiece(id: id, category: category, subcategory: subcategory, colors: colors, season: season,
                occasion: occasion, warmthLevel: warmth, price: price)
}

func weatherOf(temperature: Double = 20, windSpeed: Double = 5, rain: Bool = false, uvIndex: Double = 3,
               date: String = "2026-07-08", parts: [DayPart]? = nil, rainFrom: Int? = nil,
               rainFromStart: Bool = false) -> DayForecast {
    DayForecast(city: "Milano", date: date, tMin: nil, tMax: nil, temperature: temperature, windSpeed: windSpeed,
                uvIndex: uvIndex, precipProb: nil, icon: .sun, descriptionKey: "weather.clear", rain: rain, snow: false,
                parts: parts, rainFrom: rainFrom, rainFromStart: rainFromStart)
}

/// Generatore fisso: i test sono ripetibili.
struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(_ seed: UInt64 = 42) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
