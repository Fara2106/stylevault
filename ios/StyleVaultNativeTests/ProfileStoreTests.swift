import XCTest
import SwiftData
@testable import StyleVaultNative

@MainActor final class ProfileStoreTests: XCTestCase {
    /// Il container deve restare vivo quanto il test: se si libera, il suo `mainContext` va in crash.
    private var container: ModelContainer?

    private func context() throws -> ModelContext {
        let built = try StoreFactory.build(.memory)
        container = built
        return built.mainContext
    }
    private func count(_ c: ModelContext) throws -> Int { try c.fetchCount(FetchDescriptor<Profile>()) }

    func testIlPrimoAvvioCreaUnProfilo() throws {
        let c = try context()
        XCTAssertEqual(try ProfileStore.current(in: c).cityName, "Milano")
        XCTAssertEqual(try count(c), 1)
    }

    func testIlSecondoAvvioNonNeCreaUnAltro() throws {
        let c = try context()
        let first = try ProfileStore.current(in: c)
        XCTAssertEqual(try ProfileStore.current(in: c).id, first.id)
        XCTAssertEqual(try count(c), 1)
    }

    func testRestaIlPiuRecente() throws {
        let c = try context()
        let old = Profile(); old.cityName = "Roma"; old.updatedAt = .distantPast
        let new = Profile(); new.cityName = "Torino"; new.updatedAt = .now
        c.insert(old); c.insert(new); try c.save()
        XCTAssertEqual(try ProfileStore.current(in: c).cityName, "Torino")
        XCTAssertEqual(try count(c), 1)
    }

    func testNonPerdeLArmocromia() throws {
        let c = try context()
        let withColors = Profile(); withColors.armocromia = Data([1]); withColors.updatedAt = .distantPast
        let newer = Profile(); newer.updatedAt = .now
        c.insert(withColors); c.insert(newer); try c.save()
        XCTAssertEqual(try ProfileStore.current(in: c).armocromia, Data([1]))
    }

    func testDueDispositiviScelgonoLoStessoRecord() {
        let date = Date.now
        let a = Profile(); a.updatedAt = date
        let b = Profile(); b.updatedAt = date
        XCTAssertEqual(ProfileStore.survivor(of: [a, b])?.id, ProfileStore.survivor(of: [b, a])?.id)
    }
}
