import XCTest
@testable import StyleVaultCore

final class TemperatureTests: XCTestCase {
    func testGradiCentigradi() {
        XCTAssertEqual(Temperature.value(18.4, unit: .celsius), 18)
    }

    func testGradiFahrenheit() {
        XCTAssertEqual(Temperature.value(0, unit: .fahrenheit), 32)
        XCTAssertEqual(Temperature.value(20, unit: .fahrenheit), 68)
        XCTAssertEqual(Temperature.value(-40, unit: .fahrenheit), -40)
    }

    func testAutomaticoSegueIlPaese() {
        XCTAssertEqual(TemperatureUnit.resolve("auto", usesFahrenheit: true), .fahrenheit)
        XCTAssertEqual(TemperatureUnit.resolve("auto", usesFahrenheit: false), .celsius)
        XCTAssertEqual(TemperatureUnit.resolve("celsius", usesFahrenheit: true), .celsius)
        XCTAssertEqual(TemperatureUnit.resolve("fahrenheit", usesFahrenheit: false), .fahrenheit)
    }
}
