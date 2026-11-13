import XCTest
import SwiftData
@testable import StyleVaultNative

@MainActor final class WardrobeStoreTests: XCTestCase {
    private var container: ModelContainer?

    private func context() throws -> ModelContext {
        let built = try StoreFactory.build(.memory)
        container = built
        return built.mainContext
    }

    private func values(name: String = "Giacca", photo: Data? = nil, back: Data? = nil) -> ItemValues {
        var v = ItemValues()
        v.name = name
        v.category = "outerwear"
        v.photoFront = photo
        v.photoBack = back
        return v
    }

    func testAggiuntaConservaTuttiICampi() throws {
        let c = try context()
        var v = values(photo: Data([1]), back: Data([2]))
        v.subcategory = "blazer"; v.brand = "Zara"; v.size = "M"; v.colors = ["navy", "white"]
        v.season = "winter"; v.occasion = "formal"; v.warmthLevel = 4
        v.sourceURL = "https://zara.com/p"; v.price = 12.5
        let item = try WardrobeStore.addItem(v, in: c)
        XCTAssertEqual(item.name, "Giacca"); XCTAssertEqual(item.category, "outerwear")
        XCTAssertEqual(item.subcategory, "blazer"); XCTAssertEqual(item.brand, "Zara"); XCTAssertEqual(item.size, "M")
        XCTAssertEqual(item.colors, ["navy", "white"]); XCTAssertEqual(item.season, "winter")
        XCTAssertEqual(item.occasion, "formal"); XCTAssertEqual(item.warmthLevel, 4)
        XCTAssertEqual(item.sourceURL, "https://zara.com/p"); XCTAssertEqual(item.price, 12.5)
        XCTAssertEqual(item.photoFront, Data([1])); XCTAssertEqual(item.photoBack, Data([2]))
        XCTAssertFalse(item.favorite)
        XCTAssertFalse(c.hasChanges, "deve aver salvato")
    }

    func testLaFotoCambiataAzzeraLoScontorno() throws {
        let c = try context()
        let item = try WardrobeStore.addItem(values(photo: Data([1])), in: c)
        item.cutout = Data([9])
        XCTAssertTrue(try WardrobeStore.update(item, with: values(photo: Data([2])), in: c))
        XCTAssertNil(item.cutout)
        XCTAssertEqual(item.photoFront, Data([2]))
    }

    func testStessaFotoTieneLoScontorno() throws {
        let c = try context()
        let item = try WardrobeStore.addItem(values(photo: Data([1])), in: c)
        item.cutout = Data([9])
        XCTAssertFalse(try WardrobeStore.update(item, with: values(name: "Nuovo", photo: Data([1])), in: c))
        XCTAssertEqual(item.cutout, Data([9]))
        XCTAssertEqual(item.name, "Nuovo")
    }

    func testPreferito() throws {
        let c = try context()
        let item = try WardrobeStore.addItem(values(), in: c)
        try WardrobeStore.toggleFavorite(item, in: c)
        XCTAssertTrue(item.favorite)
        XCTAssertFalse(c.hasChanges)
        try WardrobeStore.toggleFavorite(item, in: c)
        XCTAssertFalse(item.favorite)
    }

    func testUnaModificaNonToccaPreferitoEData() throws {
        let c = try context()
        let item = try WardrobeStore.addItem(values(), in: c)
        try WardrobeStore.toggleFavorite(item, in: c)
        let created = item.createdAt
        let id = item.id
        try WardrobeStore.update(item, with: values(name: "Altro"), in: c)
        XCTAssertTrue(item.favorite)
        XCTAssertEqual(item.createdAt, created)
        XCTAssertEqual(item.id, id)
    }

    func testCancellazione() throws {
        let c = try context()
        let item = try WardrobeStore.addItem(values(), in: c)
        let wish = try WardrobeStore.addWish(values(), in: c)
        try WardrobeStore.delete(item, in: c)
        try WardrobeStore.delete(wish, in: c)
        XCTAssertEqual(try c.fetchCount(FetchDescriptor<Item>()), 0)
        XCTAssertEqual(try c.fetchCount(FetchDescriptor<WishlistItem>()), 0)
    }

    func testCompratoPortaTuttoNelGuardaroba() throws {
        let c = try context()
        var v = values(photo: Data([1]), back: Data([2]))
        v.brand = "Zara"; v.price = 30; v.sourceURL = "https://zara.com/p"
        let wish = try WardrobeStore.addWish(v, in: c)
        let wishID = wish.id
        let item = try WardrobeStore.moveToWardrobe(wish, in: c)
        XCTAssertEqual(item.photoFront, Data([1])); XCTAssertEqual(item.photoBack, Data([2]))
        XCTAssertEqual(item.brand, "Zara"); XCTAssertEqual(item.price, 30)
        XCTAssertEqual(item.sourceURL, "https://zara.com/p")
        XCTAssertFalse(item.favorite)
        XCTAssertNotEqual(item.id, wishID)
        XCTAssertEqual(try c.fetchCount(FetchDescriptor<WishlistItem>()), 0)
        XCTAssertEqual(try c.fetchCount(FetchDescriptor<Item>()), 1)
    }
}
