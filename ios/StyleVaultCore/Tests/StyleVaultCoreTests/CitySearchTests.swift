import XCTest
@testable import StyleVaultCore

final class CitySearchTests: XCTestCase {
    func testUrlComeIlSito() {
        XCTAssertEqual(CitySearch.url(query: "mila", language: "it")?.absoluteString,
            "https://geocoding-api.open-meteo.com/v1/search?name=mila&count=6&language=it&format=json")
    }

    func testAccentiESpaziCodificati() {
        let url = CitySearch.url(query: "São Paulo", language: "it")!.absoluteString
        XCTAssertTrue(url.contains("name=S%C3%A3o%20Paulo"), url)
        XCTAssertNotNil(CitySearch.url(query: "Forlì & Cesena?", language: "en"))
    }

    func testSeparatoriNelTestoNonSpezzanoLaQuery() {
        let url = CitySearch.url(query: "Forlì & Cesena?", language: "en")!.absoluteString
        XCTAssertTrue(url.contains("name=Forl%C3%AC%20%26%20Cesena%3F&count=6"), url)
    }

    func testMappaLaRisposta() throws {
        let json = #"{"results":[{"id":1,"name":"Milano","latitude":45.46,"longitude":9.19,"country":"Italia","admin1":"Lombardia"}]}"#
        XCTAssertEqual(try CitySearch.parse(Data(json.utf8)),
            [City(id: 1, name: "Milano", latitude: 45.46, longitude: 9.19, country: "Italia", region: "Lombardia")])
    }

    func testNessunRisultatoEListaVuota() throws {
        XCTAssertEqual(try CitySearch.parse(Data("{}".utf8)), [])
    }

    func testPaeseERegioneSonoFacoltativi() throws {
        let json = #"{"results":[{"id":2,"name":"Atlantis","latitude":1,"longitude":2}]}"#
        let city = try CitySearch.parse(Data(json.utf8)).first
        XCTAssertNil(city?.country)
        XCTAssertNil(city?.region)
    }
}
