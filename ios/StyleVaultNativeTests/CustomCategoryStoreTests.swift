import XCTest
import SwiftData
@testable import StyleVaultNative

@MainActor final class CustomCategoryStoreTests: XCTestCase {
    private var container: ModelContainer?

    private func context() throws -> ModelContext {
        let built = try StoreFactory.build(.memory)
        container = built
        return built.mainContext
    }
    private func count(_ c: ModelContext) throws -> Int { try c.fetchCount(FetchDescriptor<CustomCategory>()) }

    func testNomeVuotoNonCreaNulla() throws {
        let c = try context()
        XCTAssertNil(try CustomCategoryStore.add(name: "   ", in: c))
        XCTAssertEqual(try count(c), 0)
    }

    func testNomeDoppioRendeQuellaCheCe() throws {
        let c = try context()
        let first = try XCTUnwrap(CustomCategoryStore.add(name: "Sport", in: c))
        let second = try XCTUnwrap(CustomCategoryStore.add(name: " sport ", in: c))
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(try count(c), 1)
    }

    func testLIdIniziaConCustom() throws {
        let c = try context()
        let category = try XCTUnwrap(CustomCategoryStore.add(name: " Mare ", in: c))
        XCTAssertTrue(category.id.hasPrefix("custom_"))
        XCTAssertEqual(category.name, "Mare")
    }

    func testNonSiCancellaSeUsata() throws {
        let c = try context()
        let category = try XCTUnwrap(CustomCategoryStore.add(name: "Mare", in: c))
        let item = Item(); item.category = category.id
        c.insert(item); try c.save()
        XCTAssertTrue(try CustomCategoryStore.isUsed(category, in: c))
        XCTAssertFalse(try CustomCategoryStore.delete(category, in: c))
        XCTAssertEqual(try count(c), 1)
    }

    func testNonSiCancellaSeUsataDaUnDesiderio() throws {
        let c = try context()
        let category = try XCTUnwrap(CustomCategoryStore.add(name: "Mare", in: c))
        let wish = WishlistItem(); wish.category = category.id
        c.insert(wish); try c.save()
        XCTAssertFalse(try CustomCategoryStore.delete(category, in: c))
        XCTAssertEqual(try count(c), 1)
    }

    func testSiCancellaSeLibera() throws {
        let c = try context()
        let category = try XCTUnwrap(CustomCategoryStore.add(name: "Mare", in: c))
        XCTAssertTrue(try CustomCategoryStore.delete(category, in: c))
        XCTAssertEqual(try count(c), 0)
    }

    func testCategoriaSconosciutaNonSiTrova() {
        XCTAssertNil(CategoryChoice.find("custom_sparita", custom: []))
        XCTAssertEqual(CategoryChoice.find("tops", custom: [])?.id, "tops")
    }

    func testPrimaIlCatalogoPoiLePersonalizzate() throws {
        let c = try context()
        let older = try XCTUnwrap(CustomCategoryStore.add(name: "Zzz", in: c))
        older.createdAt = Date(timeIntervalSince1970: 1)
        let newer = try XCTUnwrap(CustomCategoryStore.add(name: "Aaa", in: c))
        newer.createdAt = Date(timeIntervalSince1970: 2)
        let all = CategoryChoice.all(custom: [newer, older])
        XCTAssertEqual(all.count, 9)
        XCTAssertEqual(all.first?.id, "tops")
        XCTAssertEqual(all[7].title, .custom("Zzz"))
        XCTAssertEqual(all[8].title, .custom("Aaa"))
    }
}
