import CoreLocation
import Foundation
import MapKit
import WeatherKit

/// Previsione del Meteo di Apple pronta per svNative.setForecast.
struct AppleForecast: Sendable {
    let json: Data
}

/// Meteo di Apple (WeatherKit). SPENTO finché l'account Apple Developer non è
/// approvato: per accenderlo servono la capability WeatherKit sull'App ID,
/// l'entitlement com.apple.developer.weatherkit in project.yml e isEnabled = true
/// (checklist in MEMORIA.md). Spento, il sito usa Open-Meteo.
enum AppleWeather {
    static let isEnabled = false

    static func forecast(for request: ForecastRequest) async -> AppleForecast? {
        guard isEnabled else { return nil }
        let location = CLLocation(latitude: request.latitude, longitude: request.longitude)
        do {
            let service = WeatherService.shared
            let zone = await timeZone(for: location)
            let range = AppleWeatherPayload.hourlyRange(now: Date(), zone: zone)
            let (daily, hourly) = try await service.weather(
                for: location,
                including: .daily, .hourly(startDate: range.start, endDate: range.end)
            )
            let attribution = try await service.attribution
            let payload = convert(daily: Array(daily.forecast.prefix(7)), hourly: hourly.forecast, zone: zone)
            let body: [String: Any] = [
                "source": "apple",
                "latitude": request.latitude,
                "longitude": request.longitude,
                "payload": payload,
                "attribution": [
                    "logoLight": attribution.combinedMarkLightURL.absoluteString,
                    "logoDark": attribution.combinedMarkDarkURL.absoluteString,
                    "legalURL": attribution.legalPageURL.absoluteString,
                ],
            ]
            return AppleForecast(json: try JSONSerialization.data(withJSONObject: body))
        } catch {
            return nil // il sito resta su Open-Meteo
        }
    }

    private static func convert(daily: [DayWeather], hourly: [HourWeather], zone: TimeZone) -> [String: Any] {
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
        return AppleWeatherPayload.openMeteoPayload(days: days, hours: hours,
                                                    utcOffsetSeconds: zone.secondsFromGMT(for: Date()))
    }

    private static func formatter(_ format: String, _ zone: TimeZone) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = zone
        f.dateFormat = format
        return f
    }

    /// Fuso del luogo (una città scelta a mano può essere lontana dal telefono).
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
