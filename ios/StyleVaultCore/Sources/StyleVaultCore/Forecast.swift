import Foundation

public enum WeatherIcon: String, Codable, Sendable { case sun, cloud, rain, snow }

public enum DayPartKey: String, Codable, Sendable { case morning, afternoon, evening }

/// Un'ora delle previsioni, nell'ora locale del luogo.
public struct HourForecast: Equatable, Sendable {
    public let hour: Int
    public let apparent: Double?
    public let precipProb: Int?
    public let code: Int?

    public init(hour: Int, apparent: Double?, precipProb: Int?, code: Int?) {
        self.hour = hour
        self.apparent = apparent
        self.precipProb = precipProb
        self.code = code
    }
}

public struct DayPart: Equatable, Codable, Sendable {
    public let key: DayPartKey
    public let temperature: Double?
    public let code: Int?
    public let precipProb: Int?
    public let past: Bool
    public let icon: WeatherIcon
    public let descriptionKey: String

    public init(key: DayPartKey, temperature: Double?, code: Int?, precipProb: Int?, past: Bool,
                icon: WeatherIcon, descriptionKey: String) {
        self.key = key
        self.temperature = temperature
        self.code = code
        self.precipProb = precipProb
        self.past = past
        self.icon = icon
        self.descriptionKey = descriptionKey
    }
}

/// Il meteo di un giorno: quello che servono la scheda e l'algoritmo degli outfit.
public struct DayForecast: Equatable, Codable, Sendable {
    public var city: String
    public var date: String
    public var tMin: Double?
    public var tMax: Double?
    /// La temperatura "di lavoro" dell'algoritmo, percepita.
    public var temperature: Double
    public var windSpeed: Double
    public var uvIndex: Double
    public var precipProb: Int?
    public var icon: WeatherIcon
    public var descriptionKey: String
    public var rain: Bool
    public var snow: Bool
    public var parts: [DayPart]?
    public var rainFrom: Int?
    public var rainFromStart: Bool

    public init(city: String, date: String, tMin: Double?, tMax: Double?, temperature: Double, windSpeed: Double,
                uvIndex: Double, precipProb: Int?, icon: WeatherIcon, descriptionKey: String, rain: Bool, snow: Bool,
                parts: [DayPart]? = nil, rainFrom: Int? = nil, rainFromStart: Bool = false) {
        self.city = city
        self.date = date
        self.tMin = tMin
        self.tMax = tMax
        self.temperature = temperature
        self.windSpeed = windSpeed
        self.uvIndex = uvIndex
        self.precipProb = precipProb
        self.icon = icon
        self.descriptionKey = descriptionKey
        self.rain = rain
        self.snow = snow
        self.parts = parts
        self.rainFrom = rainFrom
        self.rainFromStart = rainFromStart
    }
}

/// La giornata in tre fasce. Contano le ore "fuori casa", dalle 8 alle 20;
/// per oggi solo quelle da adesso in poi.
public enum DayParts {
    public static let rainThreshold = 45
    private static let dayStart = 8
    private static let dayEnd = 20
    private static let ranges: [(key: DayPartKey, from: Int, to: Int)] = [(.morning, 8, 12), (.afternoon, 12, 17), (.evening, 17, 20)]

    public struct Summary: Equatable, Sendable {
        public let temperature: Double?
        public let parts: [DayPart]
        public let rainFrom: Int?
        public let rainFromStart: Bool
    }

    private static func average(_ values: [Double?]) -> Double? {
        let numbers = values.compactMap { $0 }
        return numbers.isEmpty ? nil : numbers.reduce(0, +) / Double(numbers.count)
    }

    public static func summarize(_ hours: [HourForecast], nowHour: Int?) -> Summary {
        let start = nowHour.flatMap { $0 >= dayStart && $0 < dayEnd ? $0 : nil } ?? dayStart
        let counted = hours.filter { $0.hour >= start && $0.hour < dayEnd }.sorted { $0.hour < $1.hour }
        let parts = ranges.map { range -> DayPart in
            let inPart = hours.filter { $0.hour >= range.from && $0.hour < range.to }
            let code = inPart.compactMap(\.code).max()
            let mapped = Forecast.mapCode(code)
            return DayPart(key: range.key, temperature: average(inPart.map(\.apparent)), code: code,
                           precipProb: inPart.compactMap(\.precipProb).max(), past: range.to <= start,
                           icon: mapped.icon, descriptionKey: mapped.descriptionKey)
        }
        let rainFrom = counted.first { ($0.precipProb ?? -1) >= rainThreshold }?.hour
        return Summary(temperature: average(counted.map(\.apparent)), parts: parts, rainFrom: rainFrom,
                       rainFromStart: rainFrom == start)
    }
}

/// Le previsioni: i codici WMO e la lettura dei giorni e delle ore.
public enum Forecast {
    public struct CodeInfo: Equatable, Sendable {
        public let icon: WeatherIcon
        public let descriptionKey: String
        public let rain: Bool
        public let snow: Bool

        init(_ icon: WeatherIcon, _ descriptionKey: String, rain: Bool = false, snow: Bool = false) {
            self.icon = icon
            self.descriptionKey = descriptionKey
            self.rain = rain
            self.snow = snow
        }
    }

    public static func mapCode(_ code: Int?) -> CodeInfo {
        guard let code else { return CodeInfo(.cloud, "weather.cloudy") }
        switch code {
        case 0: return CodeInfo(.sun, "weather.clear")
        case 1, 2: return CodeInfo(.sun, "weather.partlyCloudy")
        case 3: return CodeInfo(.cloud, "weather.cloudy")
        case 45, 48: return CodeInfo(.cloud, "weather.fog")
        case 51...57: return CodeInfo(.rain, "weather.drizzle", rain: true)
        case 61...67, 80...82: return CodeInfo(.rain, "weather.rainy", rain: true)
        case 71...77, 85, 86: return CodeInfo(.snow, "weather.snow", snow: true)
        case 95...99: return CodeInfo(.rain, "weather.thunderstorm", rain: true)
        default: return CodeInfo(.cloud, "weather.cloudy")
        }
    }

    private struct Payload: Decodable {
        struct Daily: Decodable {
            let time: [String]?
            let temperature_2m_max: [Double?]?
            let temperature_2m_min: [Double?]?
            let apparent_temperature_max: [Double?]?
            let apparent_temperature_min: [Double?]?
            let precipitation_probability_max: [Int?]?
            let weather_code: [Int?]?
            let wind_speed_10m_max: [Double?]?
            let uv_index_max: [Double?]?
        }
        struct Hourly: Decodable {
            let time: [String]?
            let apparent_temperature: [Double?]?
            let precipitation_probability: [Int?]?
            let weather_code: [Int?]?
        }
        let utc_offset_seconds: Int?
        let daily: Daily?
        let hourly: Hourly?
    }

    private static func value<T>(_ array: [T?]?, _ index: Int) -> T? {
        guard let array, array.indices.contains(index) else { return nil }
        return array[index]
    }

    /// Data e ora "adesso" nel fuso del luogo, non in quello del telefono.
    private static func placeNow(_ now: Date, offset: Int) -> (date: String, hour: Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let parts = calendar.dateComponents([.year, .month, .day, .hour], from: now.addingTimeInterval(Double(offset)))
        let date = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        return (date, parts.hour ?? 0)
    }

    private static func hoursByDate(_ hourly: Payload.Hourly?) -> [String: [HourForecast]] {
        var result: [String: [HourForecast]] = [:]
        for (i, time) in (hourly?.time ?? []).enumerated() {
            let pieces = time.split(separator: "T")
            guard pieces.count == 2, let hour = Int(pieces[1].prefix(2)) else { continue }
            result[String(pieces[0]), default: []].append(
                HourForecast(hour: hour, apparent: value(hourly?.apparent_temperature, i),
                             precipProb: value(hourly?.precipitation_probability, i), code: value(hourly?.weather_code, i)))
        }
        return result
    }

    public static func parse(_ data: Data, city: String, now: Date) throws -> [DayForecast] {
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        guard let daily = payload.daily, let dates = daily.time, !dates.isEmpty else { return [] }
        let hours = hoursByDate(payload.hourly)
        let here = placeNow(now, offset: payload.utc_offset_seconds ?? 0)

        return dates.enumerated().map { i, date in
            let mapped = mapCode(value(daily.weather_code, i))
            let precipProb = value(daily.precipitation_probability_max, i)
            let tMax = value(daily.temperature_2m_max, i)
            var temperature = tMax ?? 20
            if let high = value(daily.apparent_temperature_max, i), let low = value(daily.apparent_temperature_min, i) {
                temperature = (high + low) / 2
            }
            var day = DayForecast(
                city: city, date: date, tMin: value(daily.temperature_2m_min, i), tMax: tMax, temperature: temperature,
                windSpeed: value(daily.wind_speed_10m_max, i) ?? 0, uvIndex: value(daily.uv_index_max, i) ?? 0,
                precipProb: precipProb, icon: mapped.icon, descriptionKey: mapped.descriptionKey,
                rain: mapped.rain || (precipProb ?? -1) >= DayParts.rainThreshold, snow: mapped.snow)
            if let dayHours = hours[date], !dayHours.isEmpty {
                let summary = DayParts.summarize(dayHours, nowHour: date == here.date ? here.hour : nil)
                if let average = summary.temperature { day.temperature = average }
                day.parts = summary.parts
                day.rainFrom = summary.rainFrom
                day.rainFromStart = summary.rainFromStart
            }
            return day
        }
    }
}
