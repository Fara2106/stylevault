import WeatherKit
import XCTest
@testable import StyleVault

final class AppleWeatherPayloadTests: XCTestCase {
    func testCondizioniInCodiciWMO() {
        XCTAssertEqual(AppleWeatherPayload.wmoCode(.clear), 0)
        XCTAssertEqual(AppleWeatherPayload.wmoCode(.mostlyClear), 0)
        XCTAssertEqual(AppleWeatherPayload.wmoCode(.partlyCloudy), 2)
        XCTAssertEqual(AppleWeatherPayload.wmoCode(.cloudy), 3)
        XCTAssertEqual(AppleWeatherPayload.wmoCode(.foggy), 45)
        XCTAssertEqual(AppleWeatherPayload.wmoCode(.drizzle), 51)
        XCTAssertEqual(AppleWeatherPayload.wmoCode(.rain), 61)
        XCTAssertEqual(AppleWeatherPayload.wmoCode(.heavyRain), 65)
        XCTAssertEqual(AppleWeatherPayload.wmoCode(.snow), 71)
        XCTAssertEqual(AppleWeatherPayload.wmoCode(.thunderstorms), 95)
        XCTAssertEqual(AppleWeatherPayload.wmoCode(.hot), 3) // senza corrispondenza: nuvoloso
    }

    func testPayloadComeOpenMeteo() throws {
        let day = AppleDay(date: "2026-11-04", high: 15, low: 8, apparentHigh: 14, apparentLow: 6,
                           precipitationChance: 0.6, condition: .rain, windKmh: 12, uv: 2)
        let hours = [8, 9, 10].map {
            AppleHour(time: String(format: "2026-11-04T%02d:00", $0), apparent: Double($0),
                      precipitationChance: 0.5, condition: .cloudy)
        }
        let payload = AppleWeatherPayload.openMeteoPayload(days: [day], hours: hours, utcOffsetSeconds: 3600)
        XCTAssertTrue(JSONSerialization.isValidJSONObject(payload))
        XCTAssertEqual(payload["utc_offset_seconds"] as? Int, 3600)
        let daily = try XCTUnwrap(payload["daily"] as? [String: Any])
        XCTAssertEqual(daily["time"] as? [String], ["2026-11-04"])
        XCTAssertEqual(daily["precipitation_probability_max"] as? [Int], [60])
        XCTAssertEqual(daily["weather_code"] as? [Int], [61])
        XCTAssertEqual(daily["apparent_temperature_min"] as? [Double], [6])
        let hourly = try XCTUnwrap(payload["hourly"] as? [String: Any])
        XCTAssertEqual(hourly["time"] as? [String], ["2026-11-04T08:00", "2026-11-04T09:00", "2026-11-04T10:00"])
        XCTAssertEqual(hourly["precipitation_probability"] as? [Int], [50, 50, 50])
        XCTAssertEqual(hourly["weather_code"] as? [Int], [3, 3, 3])
    }

    func testSpentoNonChiedeNiente() async {
        XCTAssertFalse(AppleWeather.isEnabled)
        let result = await AppleWeather.forecast(for: ForecastRequest(latitude: 41.9, longitude: 12.5, name: "Roma"))
        XCTAssertNil(result)
    }

    func testOreDaInizioOggiPerSetteGiorni() {
        // Senza un intervallo WeatherKit dà solo ~25 ore da adesso: domani a metà
        // e nessuna ora per gli altri giorni.
        let rome = TimeZone(identifier: "Europe/Rome")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = rome
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 4, hour: 10, minute: 30))!
        let range = AppleWeatherPayload.hourlyRange(now: now, zone: rome)
        XCTAssertEqual(range.start, calendar.date(from: DateComponents(year: 2026, month: 11, day: 4)))
        XCTAssertEqual(range.end, calendar.date(from: DateComponents(year: 2026, month: 11, day: 11)))
    }
}
