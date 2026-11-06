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

struct ForecastResult: Equatable, Sendable {
    let days: [DayForecast]
    /// Viene dalla cache: la rete non ha risposto.
    let stale: Bool
    let fetchedAt: Date
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
    }

    let defaults: UserDefaults

    private func key(_ place: ForecastPlace) -> String {
        if place.isPosition { return "forecast.position" }
        return String(format: "forecast.%.2f_%.2f", locale: Locale(identifier: "en_US_POSIX"), place.latitude, place.longitude)
    }

    func save(_ days: [DayForecast], for place: ForecastPlace, at date: Date) {
        guard let data = try? JSONEncoder().encode(Entry(fetchedAt: date, days: days)) else { return }
        defaults.set(data, forKey: key(place))
    }

    func read(for place: ForecastPlace) -> ForecastResult? {
        guard let data = defaults.data(forKey: key(place)),
              let entry = try? JSONDecoder().decode(Entry.self, from: data) else { return nil }
        return ForecastResult(days: entry.days, stale: true, fetchedAt: entry.fetchedAt)
    }
}

/// Open-Meteo: niente chiave e niente account. Riceve solo coordinate arrotondate.
struct OpenMeteoLoader: ForecastLoading {
    private struct NoDays: Error {}

    func load(place: ForecastPlace) async throws -> ForecastResult {
        let cache = ForecastCache(defaults: .standard)
        do {
            let now = Date.now
            let days = try await Forecast.fetch(latitude: place.latitude, longitude: place.longitude, city: place.name, now: now)
            guard !days.isEmpty else { throw NoDays() }
            cache.save(days, for: place, at: now)
            return ForecastResult(days: days, stale: false, fetchedAt: now)
        } catch {
            if let saved = cache.read(for: place) { return saved }
            throw error
        }
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
    static let defaultValue: any ForecastLoading = OpenMeteoLoader()
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
