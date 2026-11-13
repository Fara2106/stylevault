import XCTest
import SwiftData
@testable import StyleVaultNative

@MainActor final class ModelsTests: XCTestCase {
    func testIDefaultDelProfiloComeIlSito() {
        let p = Profile()
        XCTAssertEqual(p.theme, "system")
        XCTAssertEqual(p.cityName, "Milano")
        XCTAssertEqual(p.cityLatitude, 45.4642)
    }

    func testFotoGrandeSopravviveAllaRiapertura() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).store")
        let photo = Data(repeating: 7, count: 3_000_000)
        var container: ModelContainer? = try StoreFactory.build(.local, url: url)
        let item = Item(); item.photoFront = photo
        container!.mainContext.insert(item)
        try container!.mainContext.save()
        container = nil
        let again = try StoreFactory.build(.local, url: url)
        XCTAssertEqual(try again.mainContext.fetch(FetchDescriptor<Item>()).first?.photoFront, photo)
    }
}
