import WeatherKit
import XCTest
@testable import StyleVaultNative
import StyleVaultCore

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

    func testIlPayloadPassaDalloStessoLettoreDiOpenMeteo() throws {
        let day = AppleDay(date: "2026-11-04", high: 15, low: 8, apparentHigh: nil, apparentLow: nil,
                           precipitationChance: 0.6, condition: .rain, windKmh: 12, uv: 2)
        let hours = (0..<24).map {
            AppleHour(time: String(format: "2026-11-04T%02d:00", $0), apparent: 10, precipitationChance: 0.1, condition: .cloudy)
        }
        let payload = AppleWeatherPayload.openMeteoPayload(days: [day], hours: hours, utcOffsetSeconds: 3600)
        let days = try Forecast.parse(JSONSerialization.data(withJSONObject: payload), city: "Roma",
                                      now: Date(timeIntervalSince1970: 1_793_000_000))
        XCTAssertEqual(days.first?.date, "2026-11-04")
        XCTAssertEqual(days.first?.tMax, 15)
        XCTAssertEqual(days.first?.rain, true)
        XCTAssertEqual(days.first?.parts?.count, 3)
    }
}

private let roma = ForecastPlace(name: "Roma", latitude: 41.9, longitude: 12.5, isPosition: false)
private struct Rotto: Error {}

final class WeatherLoaderTests: XCTestCase {
    private let suite = "WeatherLoaderTests"

    override func setUp() { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }

    private func day(_ date: String) -> DayForecast {
        DayForecast(city: "Roma", date: date, tMin: 1, tMax: 2, temperature: 2, windSpeed: 1, uvIndex: 1, precipProb: 0,
                    icon: .sun, descriptionKey: "weather.clear", rain: false, snow: false)
    }

    func testPrimaIlMeteoDiApple() async throws {
        let days = [day("2026-11-07")]
        let loader = WeatherLoader(apple: { _, _ in days }, openMeteo: { _, _ in XCTFail("non serve"); return [] }, defaultsSuite: suite)
        let result = try await loader.load(place: roma)
        XCTAssertEqual(result.source, .apple)
        XCTAssertFalse(result.stale)
    }

    func testSeAppleNonRispondeRestaOpenMeteo() async throws {
        let days = [day("2026-11-07")]
        let loader = WeatherLoader(apple: { _, _ in throw Rotto() }, openMeteo: { _, _ in days }, defaultsSuite: suite)
        let result = try await loader.load(place: roma)
        XCTAssertEqual(result.source, .openMeteo)
        XCTAssertEqual(result.days, days)
    }

    func testSenzaReteTornaLUltimaPrevisioneConLaSuaFonte() async throws {
        let days = [day("2026-11-07")]
        _ = try await WeatherLoader(apple: { _, _ in days }, openMeteo: { _, _ in [] }, defaultsSuite: suite).load(place: roma)
        let offline = WeatherLoader(apple: { _, _ in throw Rotto() }, openMeteo: { _, _ in throw Rotto() }, defaultsSuite: suite)
        let result = try await offline.load(place: roma)
        XCTAssertTrue(result.stale)
        XCTAssertEqual(result.source, .apple)
    }

    func testSenzaNienteSiSegnalaLErrore() async {
        let offline = WeatherLoader(apple: { _, _ in throw Rotto() }, openMeteo: { _, _ in throw Rotto() }, defaultsSuite: suite)
        do {
            _ = try await offline.load(place: roma)
            XCTFail("doveva fallire")
        } catch {}
    }
}

final class LegalContentTests: XCTestCase {
    func testOgniDocumentoCèInTutteLeLingue() throws {
        for kind in LegalDocument.Kind.allCases {
            let it = try XCTUnwrap(LegalDocument.document(kind, language: "it"))
            let en = try XCTUnwrap(LegalDocument.document(kind, language: "en"))
            XCTAssertEqual(it.sections.count, en.sections.count, kind.rawValue)
            XCTAssertEqual(it.sections.map(\.paragraphs.count), en.sections.map(\.paragraphs.count), kind.rawValue)
        }
    }

    func testITestiDescrivonoLAppENonIlVecchioSito() throws {
        let all = LegalDocument.Kind.allCases.compactMap { LegalDocument.document($0, language: "it") }
            .flatMap(\.sections).flatMap(\.paragraphs).joined(separator: " ")
        for old in ["microlink", "MediaPipe", "Mobile-VTON", "jsDelivr", "GitHub", "1,3 GB"] {
            XCTAssertFalse(all.contains(old), old)
        }
        XCTAssertTrue(all.contains("iCloud"))
        XCTAssertTrue(all.contains(AppConfig.supportEmail))
    }
}
