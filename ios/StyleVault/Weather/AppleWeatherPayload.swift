import Foundation
import WeatherKit

/// Un giorno del Meteo di Apple, già nel fuso del luogo (i tipi di WeatherKit
/// non si possono costruire nei test: si passa da queste strutture).
struct AppleDay: Equatable {
    let date: String              // "2026-11-04"
    let high: Double
    let low: Double
    let apparentHigh: Double?
    let apparentLow: Double?
    let precipitationChance: Double // 0–1
    let condition: WeatherCondition
    let windKmh: Double
    let uv: Double
}

/// Un'ora del Meteo di Apple, ora locale del luogo.
struct AppleHour: Equatable {
    let time: String              // "2026-11-04T08:00"
    let apparent: Double
    let precipitationChance: Double // 0–1
    let condition: WeatherCondition
}

/// Il Meteo di Apple nella stessa forma del payload di Open-Meteo: il sito lo
/// legge con lo stesso parseForecastPayload (fasce, pioggia, consigli).
enum AppleWeatherPayload {
    /// Condizione Apple → codice WMO usato dal sito per icona e descrizione.
    /// Le ore da chiedere a WeatherKit: da mezzanotte di oggi (ora del luogo) per
    /// 7 giorni. Senza intervallo WeatherKit dà solo ~25 ore da adesso.
    static func hourlyRange(now: Date, zone: TimeZone) -> (start: Date, end: Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start.addingTimeInterval(7 * 86_400)
        return (start, end)
    }

    static func wmoCode(_ condition: WeatherCondition) -> Int {
        switch condition {
        case .clear, .mostlyClear: return 0
        case .partlyCloudy: return 2
        case .mostlyCloudy, .cloudy: return 3
        case .foggy, .haze, .smoky: return 45
        case .drizzle, .freezingDrizzle: return 51
        case .rain, .sunShowers, .freezingRain: return 61
        case .heavyRain: return 65
        case .snow, .heavySnow, .flurries, .sunFlurries, .sleet, .hail, .blizzard, .blowingSnow,
             .wintryMix:
            return 71
        case .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms,
             .tropicalStorm, .hurricane:
            return 95
        default: return 3
        }
    }

    static func openMeteoPayload(days: [AppleDay], hours: [AppleHour], utcOffsetSeconds: Int) -> [String: Any] {
        func optional(_ values: [Double?]) -> [Any] { values.map { $0.map { $0 as Any } ?? NSNull() } }
        func percent(_ chance: Double) -> Int { Int((chance * 100).rounded()) }
        return [
            "utc_offset_seconds": utcOffsetSeconds,
            "daily": [
                "time": days.map(\.date),
                "temperature_2m_max": days.map(\.high),
                "temperature_2m_min": days.map(\.low),
                "apparent_temperature_max": optional(days.map(\.apparentHigh)),
                "apparent_temperature_min": optional(days.map(\.apparentLow)),
                "precipitation_probability_max": days.map { percent($0.precipitationChance) },
                "weather_code": days.map { wmoCode($0.condition) },
                "wind_speed_10m_max": days.map(\.windKmh),
                "uv_index_max": days.map(\.uv),
            ] as [String: Any],
            "hourly": [
                "time": hours.map(\.time),
                "apparent_temperature": hours.map(\.apparent),
                "precipitation_probability": hours.map { percent($0.precipitationChance) },
                "weather_code": hours.map { wmoCode($0.condition) },
            ] as [String: Any],
        ]
    }
}
