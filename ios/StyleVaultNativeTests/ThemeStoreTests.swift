import SwiftUI
import XCTest
@testable import StyleVaultNative

final class ThemeStoreTests: XCTestCase {
    func testLaSceltaDelProfilo() {
        XCTAssertEqual(ThemeStore.colorScheme(for: "light"), .light)
        XCTAssertEqual(ThemeStore.colorScheme(for: "dark"), .dark)
        XCTAssertNil(ThemeStore.colorScheme(for: "system"), "Sistema = segue il dispositivo")
        XCTAssertNil(ThemeStore.colorScheme(for: "boh"))
    }
}
