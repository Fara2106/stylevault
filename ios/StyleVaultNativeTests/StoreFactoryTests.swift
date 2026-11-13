import XCTest
import SwiftData
@testable import StyleVaultNative

@MainActor final class StoreFactoryTests: XCTestCase {
    func testNormaleUsaIlCloud() {
        XCTAssertEqual(StoreFactory.open(build: { try StoreFactory.build($0 == .cloud ? .memory : $0) }).health, .cloud)
    }

    func testSeIlCloudFallisceSalvaInLocale() {
        let opened = StoreFactory.open(build: { mode in
            if mode == .cloud { throw CocoaError(.coreData) }
            return try StoreFactory.build(.memory)
        })
        XCTAssertEqual(opened.health, .localOnly)
    }

    func testSeFallisceAncheIlLocaleLAppParteLoStesso() {
        let opened = StoreFactory.open(build: { mode in
            if mode != .memory { throw CocoaError(.coreData) }
            return try StoreFactory.build(.memory)
        })
        XCTAssertEqual(opened.health, .temporary)
    }

    func testIModelliSonoCompatibiliConCloudKit() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).store")
        XCTAssertNoThrow(try StoreFactory.build(.cloud, url: url))
    }

    func testDatiScrittiInCloudRestanoLeggibiliInLocale() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).store")
        let size = 2_000_000

        var container: ModelContainer? = try StoreFactory.build(.cloud, url: url)
        let item = Item(); item.name = "Giacca"; item.photoFront = Data(repeating: 3, count: size)
        container!.mainContext.insert(item)
        try container!.mainContext.save()
        container = nil

        container = try StoreFactory.build(.local, url: url)
        let local = try XCTUnwrap(try container!.mainContext.fetch(FetchDescriptor<Item>()).first)
        XCTAssertEqual(local.name, "Giacca")
        XCTAssertEqual(local.photoFront?.count, size)
        local.name = "Giacca blu"
        try container!.mainContext.save()
        container = nil

        let again = try StoreFactory.build(.cloud, url: url)
        let items = try again.mainContext.fetch(FetchDescriptor<Item>())
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.name, "Giacca blu")
        XCTAssertEqual(items.first?.photoFront?.count, size)
    }
}
