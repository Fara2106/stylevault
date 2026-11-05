import XCTest
import SwiftData
@testable import StyleVaultNative

final class StoreFactoryTests: XCTestCase {
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
}
