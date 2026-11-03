import SwiftUI
import XCTest
@testable import StyleVault

final class ThemeStoreTests: XCTestCase {
    func testLaSceltaDelProfiloValeAncheNelleSchermateNative() {
        XCTAssertEqual(ThemeStore.colorScheme(for: "light"), .light)
        XCTAssertEqual(ThemeStore.colorScheme(for: "dark"), .dark)
        XCTAssertNil(ThemeStore.colorScheme(for: "system"), "Sistema = segue l'iPhone")
        XCTAssertNil(ThemeStore.colorScheme(for: "boh"))
    }
}
