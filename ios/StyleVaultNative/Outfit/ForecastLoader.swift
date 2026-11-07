import Foundation
import StyleVaultCore
import SwiftUI

/// Il luogo delle previsioni: la posizione del telefono o una città.
struct ForecastPlace: Equatable, Sendable {
    let name: String
    let latitude: Double
    let longitude: Double
    let isPosition: Bool
}

enum ForecastSource: String, Codable, Sendable { case apple, openMeteo }

struct ForecastResult: Equatable, Sendable {
    let days: [DayForecast]
    /// Viene dalla cache: la rete non ha risposto.
    let stale: Bool
    let fetchedAt: Date
    var source: ForecastSource = .openMeteo
}

protocol ForecastLoading: Sendable {
    func load(place: ForecastPlace) async throws -> ForecastResult
}

/// L'ultima previsione per luogo. La posizione ha una chiave sola e senza coordinate:
/// niente storico dei posti sul dispositivo.
struct ForecastCache {
    private struct Entry: Codable {
        let fetchedAt: Date
        let days: [DayForecast]
        /// Assente nelle previsioni salvate prima del Meteo di Apple.
        var source: ForecastSource?
    }

    let defaults: UserDefaults

    private func key(_ place: ForecastPlace) -> String {
        if place.isPosition { return "forecast.position" }
        return String(format: "forecast.%.2f_%.2f", locale: Locale(identifier: "en_US_POSIX"), place.latitude, place.longitude)
    }

    func save(_ days: [DayForecast], source: ForecastSource = .openMeteo, for place: ForecastPlace, at date: Date) {
        guard let data = try? JSONEncoder().encode(Entry(fetchedAt: date, days: days, source: source)) else { return }
        defaults.set(data, forKey: key(place))
    }

    func read(for place: ForecastPlace) -> ForecastResult? {
        guard let data = defaults.data(forKey: key(place)),
              let entry = try? JSONDecoder().decode(Entry.self, from: data) else { return nil }
        return ForecastResult(days: entry.days, stale: true, fetchedAt: entry.fetchedAt, source: entry.source ?? .openMeteo)
    }
}

/// Prima il Meteo di Apple, poi Open-Meteo, poi l'ultima previsione salvata. Senza nessuno dei tre si imposta a mano.
struct WeatherLoader: ForecastLoading {
    typealias Source = @Sendable (ForecastPlace, Date) async throws -> [DayForecast]

    private struct NoDays: Error {}

    var apple: Source = AppleWeather.days
    /// Niente chiave e niente account: riceve solo coordinate arrotondate.
    var openMeteo: Source = { place, now in
        try await Forecast.fetch(latitude: place.latitude, longitude: place.longitude, city: place.name, now: now)
    }
    var defaultsSuite: String?

    private var cache: ForecastCache {
        ForecastCache(defaults: defaultsSuite.flatMap(UserDefaults.init(suiteName:)) ?? .standard)
    }

    func load(place: ForecastPlace) async throws -> ForecastResult {
        let now = Date.now
        for (source, fetch) in [(ForecastSource.apple, apple), (.openMeteo, openMeteo)] {
            guard let days = try? await fetch(place, now), !days.isEmpty else { continue }
            cache.save(days, source: source, for: place, at: now)
            return ForecastResult(days: days, stale: false, fetchedAt: now, source: source)
        }
        if let saved = cache.read(for: place) { return saved }
        throw NoDays()
    }
}

protocol PositionProviding: Sendable {
    /// `nil` se il permesso è negato o la posizione non arriva.
    @MainActor func currentPlace(fallbackName: String) async -> ForecastPlace?
}

struct SystemPositionProvider: PositionProviding {
    @MainActor private static let provider = LocationProvider()

    @MainActor func currentPlace(fallbackName: String) async -> ForecastPlace? {
        guard let place = await Self.provider.currentPlace(fallbackName: fallbackName) else { return nil }
        return ForecastPlace(name: place.name, latitude: place.latitude, longitude: place.longitude, isPosition: true)
    }
}

#if DEBUG
/// Per i test UI: niente rete e niente permessi.
struct FakeForecastLoader: ForecastLoading {
    let fails: Bool
    private struct Offline: Error {}

    func load(place: ForecastPlace) async throws -> ForecastResult {
        if fails { throw Offline() }
        let today = CalendarMath.iso(.now)
        let days = (0..<7).map { i in
            DayForecast(city: place.name, date: DayText.adding(i, to: today), tMin: 8, tMax: 16, temperature: 12,
                        windSpeed: 6, uvIndex: 2, precipProb: 10, icon: .cloud, descriptionKey: "weather.cloudy",
                        rain: false, snow: false,
                        parts: [DayPart(key: .morning, temperature: 9, code: 3, precipProb: 10, past: false, icon: .cloud, descriptionKey: "weather.cloudy"),
                                DayPart(key: .afternoon, temperature: 18, code: 1, precipProb: 0, past: false, icon: .sun, descriptionKey: "weather.partlyCloudy"),
                                DayPart(key: .evening, temperature: 12, code: 3, precipProb: 0, past: false, icon: .cloud, descriptionKey: "weather.cloudy")])
        }
        return ForecastResult(days: days, stale: false, fetchedAt: .now)
    }
}

struct FakePositionProvider: PositionProviding {
    let denied: Bool

    @MainActor func currentPlace(fallbackName: String) async -> ForecastPlace? {
        denied ? nil : ForecastPlace(name: "Roma", latitude: 41.9, longitude: 12.5, isPosition: true)
    }
}
#endif

private struct ForecastLoaderKey: EnvironmentKey {
    static let defaultValue: any ForecastLoading = WeatherLoader()
}

private struct PositionProviderKey: EnvironmentKey {
    static let defaultValue: any PositionProviding = SystemPositionProvider()
}

extension EnvironmentValues {
    var forecastLoader: any ForecastLoading {
        get { self[ForecastLoaderKey.self] }
        set { self[ForecastLoaderKey.self] = newValue }
    }

    var positionProvider: any PositionProviding {
        get { self[PositionProviderKey.self] }
        set { self[PositionProviderKey.self] = newValue }
    }
}
