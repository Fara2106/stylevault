import StyleVaultCore
import SwiftData
import XCTest
@testable import StyleVaultNative

@MainActor final class DataTransferTests: XCTestCase {
    private var containers: [ModelContainer] = []

    private func context() throws -> ModelContext {
        let built = try StoreFactory.build(.memory)
        containers.append(built)
        return built.mainContext
    }

    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func fill(_ c: ModelContext) throws -> (Item, Outfit) {
        let item = Item()
        item.name = "Maglia rossa"
        item.category = "tops"
        item.colors = ["red"]
        item.favorite = true
        item.photoFront = Data([1, 2, 3])
        item.cutout = Data([4])
        c.insert(item)
        let wish = WishlistItem()
        wish.name = "Scarpe"
        wish.category = "shoes"
        wish.photoFront = Data([5])
        c.insert(wish)
        let category = CustomCategory()
        category.id = "custom_a"
        category.name = "Costumi"
        c.insert(category)
        let outfit = Outfit()
        outfit.itemIDs = [item.id]
        c.insert(outfit)
        let entry = CalendarEntry()
        entry.day = "2026-11-06"
        entry.outfitID = outfit.id
        entry.itemIDs = [item.id]
        c.insert(entry)
        try BodyPhotoStore.save(Data([9]), view: .front, in: c)
        let profile = try ProfileStore.current(in: c)
        profile.armocromia = try ArmocromiaVerdict(season: "deep-winter").encoded()
        try c.save()
        return (item, outfit)
    }

    /// CloudKit non ha vincoli `unique`: lo stesso file importato su due dispositivi dà due record con lo stesso id.
    func testDueCapiConLoStessoIdNonChiudonoLApp() throws {
        let c = try context()
        let id = UUID()
        let items = (0..<2).map { _ -> Item in
            let item = Item()
            item.id = id
            c.insert(item)
            return item
        }
        XCTAssertEqual(Item.byID(items).count, 1)
    }

    func testUnGuardarobaGrandePassaIntero() async throws {
        let source = try context()
        for index in 0..<(TransferBatch.size * 2 + 5) {
            let item = Item()
            item.name = "Capo \(index)"
            item.photoFront = Data([UInt8(index)])
            source.insert(item)
        }
        try source.save()
        let url = try await DataExporter.export(from: source, to: folder())

        let target = try context()
        let summary = try await DataImporter.apply(try ExportArchive.read(url), to: target)
        XCTAssertEqual(summary.items, TransferBatch.size * 2 + 5)
        let items = try target.fetch(FetchDescriptor<Item>())
        XCTAssertEqual(items.count, TransferBatch.size * 2 + 5)
        XCTAssertEqual(Set(items.compactMap(\.photoFront)).count, TransferBatch.size * 2 + 5)
    }

    func testTuttoPassaDaUnTelefonoAllAltro() async throws {
        let source = try context()
        let (item, outfit) = try fill(source)
        let url = try await DataExporter.export(from: source, to: folder())

        let target = try context()
        let summary = try await DataImporter.apply(try ExportArchive.read(url), to: target)
        XCTAssertEqual(summary, ImportSummary(items: 1, wishlist: 1, outfits: 1, calendar: 1, skipped: 0))

        let items = try target.fetch(FetchDescriptor<Item>())
        XCTAssertEqual(items.first?.id, item.id)
        XCTAssertEqual(items.first?.name, "Maglia rossa")
        XCTAssertEqual(items.first?.favorite, true)
        XCTAssertEqual(items.first?.photoFront, Data([1, 2, 3]))
        XCTAssertEqual(items.first?.cutout, Data([4]))
        XCTAssertEqual(try target.fetch(FetchDescriptor<WishlistItem>()).first?.photoFront, Data([5]))
        XCTAssertEqual(try target.fetch(FetchDescriptor<CustomCategory>()).first?.name, "Costumi")
        XCTAssertEqual(try target.fetch(FetchDescriptor<Outfit>()).first?.id, outfit.id)
        XCTAssertEqual(try target.fetch(FetchDescriptor<CalendarEntry>()).first?.outfitID, outfit.id)
        XCTAssertEqual(try target.fetch(FetchDescriptor<BodyPhoto>()).first?.photo, Data([9]))
        XCTAssertEqual(ArmocromiaVerdict.decode(try ProfileStore.current(in: target).armocromia)?.season, "deep-winter")
    }

    func testImportareDueVolteNonCreaDoppioni() async throws {
        let source = try context()
        _ = try fill(source)
        let url = try await DataExporter.export(from: source, to: folder())
        let target = try context()
        _ = try await DataImporter.apply(try ExportArchive.read(url), to: target)
        let again = try await DataImporter.apply(try ExportArchive.read(url), to: target)
        XCTAssertEqual(again.added, 0)
        XCTAssertEqual(again.skipped, 4)
        XCTAssertEqual(try target.fetchCount(FetchDescriptor<Item>()), 1)
        XCTAssertEqual(try target.fetchCount(FetchDescriptor<BodyPhoto>()), 1)
    }

    func testImportareNonToccaCiòCheCèGià() async throws {
        let source = try context()
        let (item, _) = try fill(source)
        let url = try await DataExporter.export(from: source, to: folder())
        item.name = "Rinominata"
        try source.save()
        let summary = try await DataImporter.apply(try ExportArchive.read(url), to: source)
        XCTAssertEqual(summary.items, 0)
        XCTAssertEqual(try source.fetch(FetchDescriptor<Item>()).first?.name, "Rinominata")
    }

    func testIlProfiloDiChiImportaVince() async throws {
        let source = try context()
        _ = try fill(source)
        let profile = try ProfileStore.current(in: source)
        profile.cityName = "Roma"
        profile.updatedAt = .now
        try source.save()
        let url = try await DataExporter.export(from: source, to: folder())

        let target = try context()
        let mine = try ProfileStore.current(in: target)
        mine.cityName = "Torino"
        mine.updatedAt = .now
        try target.save()
        _ = try await DataImporter.apply(try ExportArchive.read(url), to: target)
        XCTAssertEqual(try ProfileStore.current(in: target).cityName, "Torino")
    }

    func testChiavidiAltriSistemiRestanoCollegate() async throws {
        var bundle = ExportBundle()
        bundle.items = [ExportGarment(id: "capo-1", name: "Capo", category: "tops", subcategory: nil, brand: nil, size: nil,
                                      colors: [], season: "all", occasion: "casual", warmthLevel: 2, sourceURL: nil,
                                      price: nil, favorite: nil, createdAt: .now, photoFront: nil, photoBack: nil, cutout: nil)]
        bundle.outfits = [ExportOutfit(id: "outfit-1", occasion: nil, score: nil, itemIDs: ["capo-1"], createdAt: .now)]
        let url = try folder().appendingPathComponent("altro.zip")
        try ExportArchive.write(bundle, photos: [:], to: url)
        let target = try context()
        _ = try await DataImporter.apply(try ExportArchive.read(url), to: target)
        let item = try XCTUnwrap(target.fetch(FetchDescriptor<Item>()).first)
        XCTAssertEqual(try target.fetch(FetchDescriptor<Outfit>()).first?.itemIDs, [item.id])
    }
}
