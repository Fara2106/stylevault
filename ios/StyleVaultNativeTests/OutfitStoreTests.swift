import StyleVaultCore
import SwiftData
import XCTest
@testable import StyleVaultNative

@MainActor final class OutfitStoreTests: XCTestCase {
    private var container: ModelContainer?

    private func context() throws -> ModelContext {
        let built = try StoreFactory.build(.memory)
        container = built
        return built.mainContext
    }

    func testSalvaUnOutfit() throws {
        let c = try context()
        let ids = [UUID(), UUID()]
        let outfit = try OutfitStore.save(itemIDs: ids, occasion: "casual", score: 81, in: c)
        XCTAssertEqual(outfit.itemIDs, ids)
        XCTAssertEqual(outfit.occasion, "casual")
        XCTAssertEqual(outfit.score, 81)
        XCTAssertEqual(try c.fetch(FetchDescriptor<Outfit>()).count, 1)
    }

    func testTuttiINonVaNellOccasione() throws {
        let c = try context()
        XCTAssertNil(try OutfitStore.save(itemIDs: [UUID()], occasion: "all", score: nil, in: c).occasion)
    }

    func testOggiEIndossatoDomaniPianificato() throws {
        let c = try context()
        let past = try OutfitStore.log(itemIDs: [UUID()], outfitID: nil, day: "2026-11-06", today: "2026-11-06", in: c)
        let future = try OutfitStore.log(itemIDs: [UUID()], outfitID: nil, day: "2026-11-07", today: "2026-11-06", in: c)
        XCTAssertTrue(past.worn)
        XCTAssertFalse(future.worn)
    }

    func testLoStessoOutfitNonSiAssegnaDueVolteAlloStessoGiorno() throws {
        let c = try context()
        let ids = [UUID(), UUID()]
        let first = try OutfitStore.log(itemIDs: ids, outfitID: nil, day: "2026-11-06", today: "2026-11-06", in: c)
        let second = try OutfitStore.log(itemIDs: ids.reversed(), outfitID: nil, day: "2026-11-06", today: "2026-11-06", in: c)
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(try c.fetchCount(FetchDescriptor<CalendarEntry>()), 1)
        try OutfitStore.log(itemIDs: ids, outfitID: nil, day: "2026-11-07", today: "2026-11-06", in: c)
        XCTAssertEqual(try c.fetchCount(FetchDescriptor<CalendarEntry>()), 2)
    }

    func testUnGiornoFuturoNonSiSegnaIndossato() throws {
        let c = try context()
        let future = try OutfitStore.log(itemIDs: [UUID()], outfitID: nil, day: "2026-11-07", today: "2026-11-06", in: c)
        XCTAssertFalse(OutfitStore.canMarkWorn(future, today: "2026-11-06"))
        XCTAssertTrue(OutfitStore.canMarkWorn(future, today: "2026-11-07"))
    }

    func testSegnaIndossatoERimuovi() throws {
        let c = try context()
        let entry = try OutfitStore.log(itemIDs: [UUID()], outfitID: nil, day: "2026-11-07", today: "2026-11-06", in: c)
        try OutfitStore.markWorn(entry, in: c)
        XCTAssertTrue(entry.worn)
        try OutfitStore.remove(entry, in: c)
        XCTAssertTrue(try c.fetch(FetchDescriptor<CalendarEntry>()).isEmpty)
    }

    func testCancellaUnOutfitSalvatoLasciaIlCalendario() throws {
        let c = try context()
        let outfit = try OutfitStore.save(itemIDs: [UUID()], occasion: nil, score: nil, in: c)
        _ = try OutfitStore.log(itemIDs: outfit.itemIDs, outfitID: outfit.id, day: "2026-11-06", today: "2026-11-06", in: c)
        try OutfitStore.delete(outfit, in: c)
        XCTAssertTrue(try c.fetch(FetchDescriptor<Outfit>()).isEmpty)
        XCTAssertEqual(try c.fetch(FetchDescriptor<CalendarEntry>()).count, 1)
    }

    func testIlCapoDiventaUnPezzoDellAlgoritmo() throws {
        let c = try context()
        var v = ItemValues()
        v.name = "Sandali"
        v.category = "shoes"
        v.subcategory = "sandals"
        v.colors = ["red"]
        v.season = "summer"
        v.occasion = "sport"
        v.warmthLevel = 1
        v.price = 40
        let item = try WardrobeStore.addItem(v, in: c)
        XCTAssertEqual(item.piece, OutfitPiece(id: item.id.uuidString, category: "shoes", subcategory: "sandals", colors: ["red"],
                                               season: "summer", occasion: "sport", warmthLevel: 1, price: 40))
    }

    func testStoricoSoloDalleVociIndossate() {
        let worn = CalendarEntry()
        worn.day = "2026-11-01"
        let id = UUID()
        worn.itemIDs = [id]
        let planned = CalendarEntry()
        planned.day = "2026-11-08"
        planned.worn = false
        planned.itemIDs = [UUID()]
        XCTAssertEqual(OutfitStore.recentWear(from: [worn, planned]), [RecentWear(itemID: id.uuidString, date: "2026-11-01")])
    }
}
