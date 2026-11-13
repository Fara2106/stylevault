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

    func testUnProfiloNuovoPerdeControUnoPiuVecchioMaModificato() throws {
        let c = try context()
        // Primo avvio su un dispositivo dove iCloud non ha ancora consegnato nulla.
        let created = try ProfileStore.current(in: c)
        // Poi arriva quello vero, più vecchio ma modificato dall'utente.
        let real = Profile(); real.cityName = "Bari"; real.theme = "dark"
        real.updatedAt = Date(timeIntervalSince1970: 1_700_000_000)
        c.insert(real); try c.save()
        let kept = try ProfileStore.current(in: c)
        XCTAssertEqual(kept.id, real.id)
        XCTAssertEqual(kept.cityName, "Bari")
        XCTAssertEqual(kept.theme, "dark")
        XCTAssertNotEqual(kept.id, created.id)
        XCTAssertEqual(try count(c), 1)
    }

    func testDueCreazioniSuDueDispositiviConvergonoSulloStessoRecord() throws {
        let c = try context()
        let first = try ProfileStore.current(in: c)
        XCTAssertEqual(first.updatedAt, Date(timeIntervalSince1970: 0))
        // Il secondo dispositivo ha creato il suo, anch'esso mai modificato.
        let second = Profile(); second.updatedAt = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(ProfileStore.survivor(of: [first, second])?.id, ProfileStore.survivor(of: [second, first])?.id)
    }
}
