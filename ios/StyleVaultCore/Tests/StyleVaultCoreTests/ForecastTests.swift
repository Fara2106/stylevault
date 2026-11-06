import XCTest
@testable import StyleVaultCore

/// Stessi casi di `dayParts.test.js` e `weather.test.js` (tag `archivio-ibrida-e-sito`).
final class ForecastTests: XCTestCase {
    private func day(_ over: (Int) -> HourForecast? = { _ in nil }) -> [HourForecast] {
        (0..<24).map { over($0) ?? HourForecast(hour: $0, apparent: Double($0), precipProb: 0, code: 0) }
    }

    func testFasceSulleOreOttoVenti() {
        let s = DayParts.summarize(day(), nowHour: nil)
        XCTAssertEqual(s.temperature, 13.5)
        XCTAssertEqual(s.parts.map(\.key), [.morning, .afternoon, .evening])
        XCTAssertEqual(s.parts.map(\.temperature), [9.5, 14, 18])
        XCTAssertFalse(s.parts.contains(where: \.past))
    }

    func testOggiAlleQuindiciContaDaAdesso() {
        let s = DayParts.summarize(day(), nowHour: 15)
        XCTAssertEqual(s.temperature, 17)
        XCTAssertEqual(s.parts.map(\.past), [true, false, false])
    }

    func testDopoLeVentiContaTuttaLaGiornata() {
        for now in [21, 6] {
            let s = DayParts.summarize(day(), nowHour: now)
            XCTAssertEqual(s.temperature, 13.5)
            XCTAssertFalse(s.parts.contains(where: \.past))
        }
    }

    func testPrimaOraDiPioggia() {
        let evening = DayParts.summarize(day { HourForecast(hour: $0, apparent: 0, precipProb: $0 >= 18 ? 50 : 10, code: 0) }, nowHour: nil)
        XCTAssertEqual(evening.rainFrom, 18)
        XCTAssertFalse(evening.rainFromStart)
        let morning = DayParts.summarize(day { HourForecast(hour: $0, apparent: 0, precipProb: 50, code: 0) }, nowHour: nil)
        XCTAssertEqual(morning.rainFrom, 8)
        XCTAssertTrue(morning.rainFromStart)
        let today = DayParts.summarize(day { HourForecast(hour: $0, apparent: 0, precipProb: 50, code: 0) }, nowHour: 15)
        XCTAssertEqual(today.rainFrom, 15)
        XCTAssertTrue(today.rainFromStart)
        XCTAssertNil(DayParts.summarize(day(), nowHour: nil).rainFrom)
    }

    func testCodiceEPioggiaSonoIMassimi() {
        let s = DayParts.summarize(day { HourForecast(hour: $0, apparent: 0, precipProb: $0 == 14 ? 70 : 5, code: $0 == 13 ? 61 : 3) }, nowHour: nil)
        XCTAssertEqual(s.parts[1].code, 61)
        XCTAssertEqual(s.parts[1].precipProb, 70)
        XCTAssertEqual(s.parts[0].code, 3)
    }

    func testOreSenzaDati() {
        let s = DayParts.summarize(day { HourForecast(hour: $0, apparent: nil, precipProb: nil, code: nil) }, nowHour: nil)
        XCTAssertNil(s.temperature)
        for p in s.parts {
            XCTAssertNil(p.temperature)
            XCTAssertNil(p.code)
            XCTAssertNil(p.precipProb)
        }
        XCTAssertNil(s.rainFrom)
    }

    func testCodiciMeteo() {
        XCTAssertEqual(Forecast.mapCode(0).icon, .sun)
        XCTAssertEqual(Forecast.mapCode(0).descriptionKey, "weather.clear")
        XCTAssertTrue(Forecast.mapCode(61).rain)
        XCTAssertTrue(Forecast.mapCode(80).rain)
        XCTAssertTrue(Forecast.mapCode(71).snow)
        XCTAssertFalse(Forecast.mapCode(71).rain)
        XCTAssertTrue(Forecast.mapCode(95).rain)
        XCTAssertEqual(Forecast.mapCode(1234).descriptionKey, "weather.cloudy")
        XCTAssertEqual(Forecast.mapCode(nil).descriptionKey, "weather.cloudy")
    }

    private let sample = #"""
    {"daily":{"time":["2026-07-08","2026-07-09"],"temperature_2m_max":[31.2,24.0],"temperature_2m_min":[21.5,17.3],
    "apparent_temperature_max":[33.8,22.1],"apparent_temperature_min":[22.0,16.0],"precipitation_probability_max":[10,80],
    "weather_code":[0,61],"wind_speed_10m_max":[12.4,30.1],"uv_index_max":[8.1,3.2]}}
    """#

    func testUnGiornoPerData() throws {
        let days = try Forecast.parse(Data(sample.utf8), city: "Milano", now: Date())
        XCTAssertEqual(days.count, 2)
        XCTAssertEqual(days[0].city, "Milano")
        XCTAssertEqual(days[0].date, "2026-07-08")
        XCTAssertEqual(days[0].tMin, 21.5)
        XCTAssertEqual(days[0].tMax, 31.2)
        XCTAssertEqual(days[0].temperature, (33.8 + 22.0) / 2, accuracy: 0.00001)
        XCTAssertEqual(days[0].windSpeed, 12.4)
        XCTAssertEqual(days[0].uvIndex, 8.1)
        XCTAssertEqual(days[0].precipProb, 10)
        XCTAssertFalse(days[0].rain)
        XCTAssertEqual(days[0].icon, .sun)
        XCTAssertNil(days[0].parts)
        XCTAssertTrue(days[1].rain)
        XCTAssertEqual(days[1].descriptionKey, "weather.rainy")
    }

    func testPioggiaDallaProbabilita() throws {
        let json = sample.replacingOccurrences(of: "[0,61]", with: "[3,3]").replacingOccurrences(of: "[10,80]", with: "[60,10]")
        let days = try Forecast.parse(Data(json.utf8), city: "Oslo", now: Date())
        XCTAssertTrue(days[0].rain)
        XCTAssertFalse(days[1].rain)
    }

    private func hourly(offset: Int) -> Data {
        var times: [String] = [], apparent: [Double] = []
        for date in ["2026-07-08", "2026-07-09"] {
            for h in 0..<24 {
                times.append("\(date)T\(String(format: "%02d", h)):00")
                apparent.append(Double(h))
            }
        }
        let body: [String: Any] = [
            "utc_offset_seconds": offset,
            "daily": ["time": ["2026-07-08", "2026-07-09"], "weather_code": [0, 0]],
            "hourly": ["time": times, "apparent_temperature": apparent,
                       "precipitation_probability": apparent.map { _ in 0 }, "weather_code": apparent.map { _ in 0 }],
        ]
        return try! JSONSerialization.data(withJSONObject: body)
    }

    func testConLeOreAggiungeFasceEMedia() throws {
        let now = ISO8601DateFormatter().date(from: "2026-07-09T05:00:00Z")!
        let days = try Forecast.parse(hourly(offset: 3600), city: "Milano", now: now)
        XCTAssertEqual(days[1].temperature, 13.5)
        XCTAssertEqual(days[1].parts?.count, 3)
        XCTAssertEqual(days[1].parts?[0].icon, .sun)
        XCTAssertEqual(days[1].parts?[0].descriptionKey, "weather.clear")
        XCTAssertNil(days[1].rainFrom)
        XCTAssertEqual(days[0].parts?.count, 3)
    }

    func testIlFusoDelLuogoDecideLeOrePassate() throws {
        let now = ISO8601DateFormatter().date(from: "2026-07-08T20:00:00Z")!
        let days = try Forecast.parse(hourly(offset: -18000), city: "New York", now: now)
        XCTAssertEqual(days[0].parts?[0].past, true)
        XCTAssertEqual(days[0].parts?[1].past, false)
        XCTAssertEqual(days[0].temperature, 17)
        XCTAssertEqual(days[1].parts?.contains(where: \.past), false)
    }

    func testIndirizzoChiedeOreEArrotondaLePosizioni() throws {
        let url = try XCTUnwrap(Forecast.url(latitude: 45.46423, longitude: 9.18951))
        let query = try XCTUnwrap(url.query)
        XCTAssertTrue(query.contains("latitude=45.46"), query)
        XCTAssertTrue(query.contains("longitude=9.19"), query)
        XCTAssertTrue(query.contains("hourly=apparent_temperature,precipitation_probability,weather_code"), query)
        XCTAssertTrue(query.contains("forecast_days=7"), query)
        XCTAssertTrue(query.contains("timezone=auto"), query)
    }

    func testRisposteSenzaGiorni() throws {
        XCTAssertEqual(try Forecast.parse(Data("{}".utf8), city: "X", now: Date()), [])
    }

    func testSiPuoSalvareERileggere() throws {
        let days = try Forecast.parse(hourly(offset: 3600), city: "Milano", now: Date())
        let copy = try JSONDecoder().decode([DayForecast].self, from: JSONEncoder().encode(days))
        XCTAssertEqual(copy, days)
    }
}
