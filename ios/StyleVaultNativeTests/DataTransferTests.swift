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

    private func garment(_ id: String, name: String = "Capo", warmth: Int = 2, photo: String? = nil) -> ExportGarment {
        ExportGarment(id: id, name: name, category: "tops", subcategory: nil, brand: nil, size: nil, colors: [], season: "all",
                      occasion: "casual", warmthLevel: warmth, sourceURL: nil, price: nil, favorite: false, createdAt: .now,
                      photoFront: photo, photoBack: nil, cutout: nil)
    }

    private func archive(_ bundle: ExportBundle, photos: [String: Data] = [:]) throws -> ExportArchive.Contents {
        let url = try folder().appendingPathComponent("prova.zip")
        try ExportArchive.write(bundle, photos: photos, to: url)
        return try ExportArchive.read(url)
    }

    func testUnFileStranoNonPortaValoriPericolosi() async throws {
        var bundle = ExportBundle()
        bundle.items = [garment(UUID().uuidString, warmth: Int.max)]
        bundle.calendar = [ExportCalendarEntry(id: UUID().uuidString, day: "domani", worn: true, outfitID: nil, itemIDs: [], createdAt: .now)]
        bundle.profile = ExportProfile(theme: "system", cityName: "Milano", cityLatitude: 45, cityLongitude: 9, cityCountry: nil,
                                       armocromia: try String(decoding: ArmocromiaVerdict(season: "inventata").encoded(), as: UTF8.self))
        let target = try context()
        let summary = try await DataImporter.apply(try archive(bundle), to: target)
        XCTAssertEqual(try target.fetch(FetchDescriptor<Item>()).first?.warmthLevel, 5)
        XCTAssertEqual(summary.calendar, 0)
        XCTAssertEqual(summary.skipped, 1)
        XCTAssertNil(try ProfileStore.current(in: target).armocromia)
    }

    func testUnaFotoMancataSiRecuperaRipetendoLImport() async throws {
        let id = UUID().uuidString
        var bundle = ExportBundle()
        bundle.items = [garment(id, photo: "photos/a.jpg")]
        let target = try context()
        let first = try await DataImporter.apply(try archive(bundle), to: target)
        XCTAssertEqual(first.missingPhotos, 1)
        XCTAssertNil(try target.fetch(FetchDescriptor<Item>()).first?.photoFront)

        let second = try await DataImporter.apply(try archive(bundle, photos: ["photos/a.jpg": Data([7])]), to: target)
        XCTAssertEqual(second.items, 0)
        XCTAssertEqual(second.missingPhotos, 0)
        let items = try target.fetch(FetchDescriptor<Item>())
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.photoFront, Data([7]))
    }

    func testChiaviNonUUIDNonCreanoDoppioni() async throws {
        var bundle = ExportBundle()
        bundle.items = [garment("capo-1")]
        let target = try context()
        _ = try await DataImporter.apply(try archive(bundle), to: target)
        let again = try await DataImporter.apply(try archive(bundle), to: target)
        XCTAssertEqual(again.items, 0)
        XCTAssertEqual(try target.fetchCount(FetchDescriptor<Item>()), 1)
    }

    func testICapiCancellatiRestanoNelloStoricoAncheNelFile() async throws {
        let source = try context()
        let (item, _) = try fill(source)
        try WardrobeStore.delete(item, in: source)
        let entry = try XCTUnwrap(try source.fetch(FetchDescriptor<CalendarEntry>()).first)
        XCTAssertEqual(entry.deletedNames(in: []), ["Maglia rossa"])
        XCTAssertTrue(entry.hasDeletedItems(in: []))
        XCTAssertTrue(entry.present(in: []).isEmpty)

        let url = try await DataExporter.export(from: source, to: folder())
        let target = try context()
        _ = try await DataImporter.apply(try ExportArchive.read(url), to: target)
        let imported = try XCTUnwrap(try target.fetch(FetchDescriptor<CalendarEntry>()).first)
        XCTAssertEqual(imported.deletedNames(in: []), ["Maglia rossa"])
    }

    func testLeCopieTemporaneeSparisconoEGliAltriFileNo() throws {
        let tmp = try folder()
        for name in ["importa-1.zip", "StyleVault-2026-11-07.zip", "altro.txt"] {
            FileManager.default.createFile(atPath: tmp.appendingPathComponent(name).path, contents: Data())
        }
        try FileManager.default.createDirectory(at: tmp.appendingPathComponent("prova"), withIntermediateDirectories: true)
        TemporaryFiles.sweep(tmp)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: tmp.path), ["altro.txt"])
    }

    // MARK: Doppioni

    private func copies(_ c: ModelContext, id: UUID = UUID(), stamps: [UUID?]) throws -> [Item] {
        let items = stamps.map { stamp -> Item in
            let item = Item()
            item.id = id
            item.stamp = stamp
            c.insert(item)
            return item
        }
        try c.save()
        return items
    }

    func testDueDispositiviTengonoLaStessaCopia() throws {
        let (low, high) = (UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, UUID(uuidString: "FFFFFFFF-0000-0000-0000-000000000001")!)
        for order in [[low, high], [high, low]] {
            let c = try context()
            _ = try copies(c, stamps: order)
            XCTAssertEqual(try DuplicateStore.clean(in: c), 1)
            XCTAssertEqual(try c.fetch(FetchDescriptor<Item>()).map(\.stamp), [high])
        }
    }

    func testLaCopiaCheRestaPrendeLeFotoDellAltra() throws {
        let c = try context()
        let (low, high) = (UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, UUID(uuidString: "FFFFFFFF-0000-0000-0000-000000000001")!)
        let items = try copies(c, stamps: [low, high])
        items[0].photoFront = Data([1])
        items[0].favorite = true
        try c.save()
        try DuplicateStore.clean(in: c)
        let kept = try XCTUnwrap(try c.fetch(FetchDescriptor<Item>()).first)
        XCTAssertEqual(kept.photoFront, Data([1]))
        XCTAssertTrue(kept.favorite)
    }

    func testSenzaUnaSceltaSicuraRestanoEntrambe() throws {
        let c = try context()
        let same = UUID()
        _ = try copies(c, stamps: [nil, nil])
        _ = try copies(c, stamps: [same, same])
        XCTAssertEqual(try DuplicateStore.clean(in: c), 0)
        XCTAssertEqual(try c.fetchCount(FetchDescriptor<Item>()), 4)
    }

    func testCapiDiversiNonSiToccano() throws {
        let c = try context()
        _ = try copies(c, stamps: [UUID()])
        _ = try copies(c, stamps: [UUID()])
        XCTAssertEqual(try DuplicateStore.clean(in: c), 0)
        XCTAssertEqual(try c.fetchCount(FetchDescriptor<Item>()), 2)
    }
}
