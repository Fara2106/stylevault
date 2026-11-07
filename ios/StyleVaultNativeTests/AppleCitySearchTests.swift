import StyleVaultCore
import XCTest
@testable import StyleVaultNative

final class AppleCitySearchTests: XCTestCase {
    private func city(_ name: String, region: String? = nil) -> City {
        City(id: 0, name: name, latitude: 45, longitude: 9, country: "Italia", region: region)
    }

    func testToglieIDoppioniEDaUnIdDiverso() {
        let cities = AppleCitySearch.unique([city("Milano"), city("Milano"), city("Roma")])
        XCTAssertEqual(cities.map(\.name), ["Milano", "Roma"])
        XCTAssertEqual(cities.map(\.id), [0, 1])
    }

    func testStessoNomeInRegioniDiverseRestano() {
        XCTAssertEqual(AppleCitySearch.unique([city("San Giorgio", region: "Lombardia"), city("San Giorgio", region: "Veneto")]).count, 2)
    }

    func testAlMassimoSeiCitta() {
        XCTAssertEqual(AppleCitySearch.unique((1...9).map { city("Città \($0)") }).count, 6)
    }
}
