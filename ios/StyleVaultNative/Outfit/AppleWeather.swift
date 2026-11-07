import CoreLocation
import Foundation
import MapKit
import StyleVaultCore
import WeatherKit

/// Meteo di Apple (WeatherKit). Se non risponde restano l'ultima previsione salvata o il meteo a mano.
enum AppleWeather {
    static let legalURL = URL(string: "https://weatherkit.apple.com/legal-attribution.html")!

    private struct TimedOut: Error {}

    @Sendable static func days(for place: ForecastPlace, now: Date) async throws -> [DayForecast] {
        // A due decimali: al meteo non serve sapere dove si è di preciso.
        let location = CLLocation(latitude: (place.latitude * 100).rounded() / 100,
                                  longitude: (place.longitude * 100).rounded() / 100)
        return try await withThrowingTaskGroup(of: [DayForecast].self) { group in
            group.addTask { try await fetch(location, city: place.name, now: now) }
            group.addTask {
                try await Task.sleep(for: .seconds(8))
                throw TimedOut()
            }
            guard let days = try await group.next() else { throw TimedOut() }
            group.cancelAll()
            return days
        }
    }

    private static func fetch(_ location: CLLocation, city: String, now: Date) async throws -> [DayForecast] {
        let zone = await timeZone(for: location)
        let range = AppleWeatherPayload.hourlyRange(now: now, zone: zone)
        let (daily, hourly) = try await WeatherService.shared.weather(
            for: location, including: .daily, .hourly(startDate: range.start, endDate: range.end))
        let payload = convert(daily: Array(daily.forecast.prefix(7)), hourly: hourly.forecast, zone: zone, now: now)
        return try Forecast.parse(JSONSerialization.data(withJSONObject: payload), city: city, now: now)
    }

    private static func convert(daily: [DayWeather], hourly: [HourWeather], zone: TimeZone, now: Date) -> [String: Any] {
        let dayFormat = formatter("yyyy-MM-dd", zone)
        let hourFormat = formatter("yyyy-MM-dd'T'HH:00", zone)
        let days = daily.map { day in
            AppleDay(date: dayFormat.string(from: day.date),
                     high: day.highTemperature.converted(to: .celsius).value,
                     low: day.lowTemperature.converted(to: .celsius).value,
                     apparentHigh: nil, apparentLow: nil,
                     precipitationChance: day.precipitationChance,
                     condition: day.condition,
                     windKmh: day.wind.speed.converted(to: .kilometersPerHour).value,
                     uv: Double(day.uvIndex.value))
        }
        let dates = Set(days.map(\.date))
        let hours = hourly.compactMap { hour -> AppleHour? in
            let time = hourFormat.string(from: hour.date)
            guard dates.contains(String(time.prefix(10))) else { return nil }
            return AppleHour(time: time,
                             apparent: hour.apparentTemperature.converted(to: .celsius).value,
                             precipitationChance: hour.precipitationChance,
                             condition: hour.condition)
        }
        return AppleWeatherPayload.payload(days: days, hours: hours, utcOffsetSeconds: zone.secondsFromGMT(for: now))
    }

    private static func formatter(_ format: String, _ zone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = zone
        formatter.dateFormat = format
        return formatter
    }

    /// Fuso del luogo: una città scelta a mano può essere lontana dal telefono.
    private static func timeZone(for location: CLLocation) async -> TimeZone {
        if #available(iOS 26.0, *) {
            if let request = MKReverseGeocodingRequest(location: location),
               let zone = try? await request.mapItems.first?.timeZone {
                return zone
            }
        } else if let zone = try? await CLGeocoder().reverseGeocodeLocation(location).first?.timeZone {
            return zone
        }
        return .current
    }
}
