import ImageIO
import StyleVaultCore
import SwiftData
import UniformTypeIdentifiers
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

    /// Una foto vera e piccola: l'importazione accetta solo ciò che riconosce come foto. Il lato la rende diversa dalle altre.
    private static func picture(_ side: Int = 8, type: UTType = .jpeg) -> Data {
        let context = CGContext(data: nil, width: side, height: 8, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 0.6, green: 0.2, blue: 0.2, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: side, height: 8))
        let output = NSMutableData()
        let destination = CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        CGImageDestinationFinalize(destination)
        return output as Data
    }

    private static let front = picture(8)
    private static let wished = picture(9)
    private static let body = picture(10)
    private static let cut = picture(8, type: .png)

    private func fill(_ c: ModelContext) throws -> (Item, Outfit) {
        let item = Item()
        item.name = "Maglia rossa"
        item.category = "tops"
        item.colors = ["red"]
        item.favorite = true
        item.photoFront = Self.front
        item.cutout = Self.cut
        c.insert(item)
        let wish = WishlistItem()
        wish.name = "Scarpe"
        wish.category = "shoes"
        wish.photoFront = Self.wished
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
        try BodyPhotoStore.save(Self.body, view: .front, in: c)
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
            item.photoFront = Self.picture(8 + index)
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
        XCTAssertEqual(items.first?.photoFront, Self.front)
        XCTAssertEqual(items.first?.cutout, Self.cut)
        XCTAssertEqual(try target.fetch(FetchDescriptor<WishlistItem>()).first?.photoFront, Self.wished)
        XCTAssertEqual(try target.fetch(FetchDescriptor<CustomCategory>()).first?.name, "Costumi")
        XCTAssertEqual(try target.fetch(FetchDescriptor<Outfit>()).first?.id, outfit.id)
        XCTAssertEqual(try target.fetch(FetchDescriptor<CalendarEntry>()).first?.outfitID, outfit.id)
        XCTAssertEqual(try target.fetch(FetchDescriptor<BodyPhoto>()).first?.photo, Self.body)
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

        let second = try await DataImporter.apply(try archive(bundle, photos: ["photos/a.jpg": Self.front]), to: target)
        XCTAssertEqual(second.items, 0)
        XCTAssertEqual(second.missingPhotos, 0)
        XCTAssertEqual(second.recoveredPhotos, 1)
        let items = try target.fetch(FetchDescriptor<Item>())
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.photoFront, Self.front)
    }

    // MARK: Un file che viene da qualcun altro

    func testImportareNonCompletaUnCapoCheHaGiaLaFoto() async throws {
        let id = UUID()
        let target = try context()
        let mine = Item()
        mine.id = id
        mine.photoFront = Self.front
        target.insert(mine)
        try target.save()
        var bundle = ExportBundle()
        bundle.items = [ExportGarment(id: id.uuidString, name: "Altro", category: "tops", subcategory: nil, brand: nil, size: nil,
                                      colors: [], season: "all", occasion: "casual", warmthLevel: 2, sourceURL: nil, price: nil,
                                      favorite: false, createdAt: .now, photoFront: "photos/f.jpg", photoBack: "photos/b.jpg",
                                      cutout: "photos/c.png")]
        let photos = ["photos/f.jpg": Self.wished, "photos/b.jpg": Self.wished, "photos/c.png": Self.cut]
        let summary = try await DataImporter.apply(try archive(bundle, photos: photos), to: target)
        XCTAssertEqual(summary.recoveredPhotos, 0)
        let item = try XCTUnwrap(try target.fetch(FetchDescriptor<Item>()).first)
        // «Ciò che hai già resta com'è»: né il retro né lo scontorno arrivano dal file
        XCTAssertEqual(item.photoFront, Self.front)
        XCTAssertNil(item.photoBack)
        XCTAssertNil(item.cutout)
    }

    func testLaStessaFotoCitataDaTantiRecordSiSalvaUnaVoltaSola() async throws {
        var bundle = ExportBundle()
        bundle.items = (0..<5).map { garment("capo-\($0)", photo: "photos/a.jpg") }
        let target = try context()
        let summary = try await DataImporter.apply(try archive(bundle, photos: ["photos/a.jpg": Self.front]), to: target)
        XCTAssertEqual(summary.items, 5)
        XCTAssertEqual(summary.missingPhotos, 4)
        XCTAssertEqual(try target.fetch(FetchDescriptor<Item>()).compactMap(\.photoFront).count, 1)
    }

    func testUnOutfitOUnGiornoConMigliaiaDiCapiSiTaglia() async throws {
        var bundle = ExportBundle()
        let many = (0..<10_000).map { "capo-\($0 % 3)" }
        bundle.outfits = [ExportOutfit(id: "o", occasion: String(repeating: "x", count: 10_000), score: nil, itemIDs: many, createdAt: .now),
                          ExportOutfit(id: "p", occasion: nil, score: nil, itemIDs: (0..<10_000).map { "capo-\($0)" }, createdAt: .now)]
        let worn = (0..<10_000).map { WornItem(id: "capo-\($0)", name: String(repeating: "n", count: 5_000), category: "tops") }
        bundle.calendar = [ExportCalendarEntry(id: "g", day: "2026-11-12", worn: true, outfitID: nil, itemIDs: many, createdAt: .now,
                                               snapshot: worn)]
        let target = try context()
        let summary = try await DataImporter.apply(try archive(bundle), to: target)
        XCTAssertEqual(summary.outfits, 2)
        XCTAssertEqual(summary.calendar, 1)
        let outfits = try target.fetch(FetchDescriptor<Outfit>())
        // Gli stessi tre capi ripetuti restano tre; diecimila capi diversi restano quanti ne porta un outfit vero
        XCTAssertEqual(Set(outfits.map(\.itemIDs.count)), [3, DataImporter.piecesLimit])
        XCTAssertEqual(outfits.compactMap(\.occasion).first?.count, DataImporter.textLimit)
        let entry = try XCTUnwrap(try target.fetch(FetchDescriptor<CalendarEntry>()).first)
        XCTAssertEqual(entry.itemIDs.count, 3)
        let kept = try JSONDecoder().decode([WornItem].self, from: try XCTUnwrap(entry.snapshot))
        XCTAssertEqual(kept.count, DataImporter.piecesLimit)
        XCTAssertEqual(kept.first?.name.count, DataImporter.textLimit)
    }

    func testUnGiornoNonPuoAvereMigliaiaDiVoci() async throws {
        var bundle = ExportBundle()
        bundle.calendar = (0..<100).map {
            ExportCalendarEntry(id: "g-\($0)", day: "2026-11-12", worn: true, outfitID: nil, itemIDs: [], createdAt: .now)
        }
        let target = try context()
        let summary = try await DataImporter.apply(try archive(bundle), to: target)
        XCTAssertEqual(summary.calendar, DataImporter.entriesPerDayLimit)
        XCTAssertEqual(summary.skipped, 100 - DataImporter.entriesPerDayLimit)
        // Il giorno è pieno: ripetere non aggiunge altro
        let again = try await DataImporter.apply(try archive(bundle), to: target)
        XCTAssertEqual(again.calendar, 0)
        XCTAssertEqual(try target.fetchCount(FetchDescriptor<CalendarEntry>()), DataImporter.entriesPerDayLimit)
    }

    func testTestiEColoriSenzaFineSiTagliano() async throws {
        var bundle = ExportBundle()
        bundle.items = [ExportGarment(id: "capo", name: String(repeating: "a", count: 100_000), category: "tops", subcategory: nil,
                                      brand: String(repeating: "b", count: 100_000), size: nil,
                                      colors: (0..<1_000).map { "colore-\($0)" }, season: "all", occasion: "casual", warmthLevel: 2,
                                      sourceURL: "https://esempio.it/" + String(repeating: "c", count: 100_000), price: nil,
                                      favorite: false, createdAt: .now, photoFront: nil, photoBack: nil, cutout: nil)]
        let target = try context()
        _ = try await DataImporter.apply(try archive(bundle), to: target)
        let item = try XCTUnwrap(try target.fetch(FetchDescriptor<Item>()).first)
        XCTAssertEqual(item.name.count, DataImporter.textLimit)
        XCTAssertEqual(item.brand?.count, DataImporter.textLimit)
        XCTAssertEqual(item.colors.count, DataImporter.colorsLimit)
        XCTAssertEqual(item.sourceURL?.count, DataImporter.linkLimit)
    }

    func testLoStessoIdRipetutoNelFileNonCreaDueRecord() async throws {
        var bundle = ExportBundle()
        bundle.items = [garment("capo"), garment("capo")]
        bundle.outfits = Array(repeating: ExportOutfit(id: "o", occasion: nil, score: nil, itemIDs: ["capo"], createdAt: .now), count: 2)
        let target = try context()
        let summary = try await DataImporter.apply(try archive(bundle), to: target)
        XCTAssertEqual(summary.items, 1)
        XCTAssertEqual(summary.outfits, 1)
        XCTAssertEqual(summary.skipped, 2)
        XCTAssertEqual(try target.fetchCount(FetchDescriptor<Item>()), 1)
        XCTAssertEqual(try target.fetchCount(FetchDescriptor<Outfit>()), 1)
    }

    func testCiòCheNonEUnaFotoNonEntra() async throws {
        var bundle = ExportBundle()
        bundle.items = [ExportGarment(id: UUID().uuidString, name: "Capo", category: "tops", subcategory: nil, brand: nil, size: nil,
                                      colors: [], season: "all", occasion: "casual", warmthLevel: 2, sourceURL: nil, price: nil,
                                      favorite: false, createdAt: .now, photoFront: "photos/f.jpg", photoBack: nil,
                                      cutout: "photos/c.png")]
        let target = try context()
        let photos = ["photos/f.jpg": Data([1, 2, 3]), "photos/c.png": Data([4])]
        let summary = try await DataImporter.apply(try archive(bundle, photos: photos), to: target)
        XCTAssertEqual(summary.items, 1)
        // Lo scontorno che non convince non si conta: l'app lo rifà
        XCTAssertEqual(summary.missingPhotos, 1)
        let item = try XCTUnwrap(try target.fetch(FetchDescriptor<Item>()).first)
        XCTAssertNil(item.photoFront)
        XCTAssertNil(item.cutout)
    }

    func testLeFotoDelCorpoEntranoSoloPerLeVisteCheLAppConosce() async throws {
        var bundle = ExportBundle()
        bundle.bodyPhotos = [ExportBodyPhoto(kind: "x", file: "photos/a.jpg"),
                             ExportBodyPhoto(kind: String(repeating: "A", count: 70_000), file: "photos/a.jpg"),
                             ExportBodyPhoto(kind: "front", file: "photos/rotta.jpg"),
                             ExportBodyPhoto(kind: "front", file: "photos/a.jpg"),
                             ExportBodyPhoto(kind: "front", file: "photos/b.jpg")]
        let target = try context()
        let photos = ["photos/a.jpg": Self.body, "photos/b.jpg": Self.wished, "photos/rotta.jpg": Data([9])]
        _ = try await DataImporter.apply(try archive(bundle, photos: photos), to: target)
        let stored = try target.fetch(FetchDescriptor<BodyPhoto>())
        XCTAssertEqual(stored.map(\.kind), ["front"])
        XCTAssertEqual(stored.first?.photo, Self.body)
    }

    func testUnaFotoDelCorpoNascostaNonFinisceNelFileEsportato() async throws {
        let source = try context()
        let hidden = BodyPhoto()
        hidden.kind = "x/../y"
        hidden.photo = Self.body
        source.insert(hidden)
        try BodyPhotoStore.save(Self.body, view: .side, in: source)
        let contents = try ExportArchive.read(try await DataExporter.export(from: source, to: folder()))
        XCTAssertEqual(contents.bundle.bodyPhotos.map(\.kind), ["side"])
        XCTAssertEqual(contents.bundle.bodyPhotos.map(\.file), ["photos/body-side.jpg"])
    }

    func testIlVerdettoImportatoSiRiscrive() async throws {
        var bundle = ExportBundle()
        bundle.profile = ExportProfile(theme: "system", cityName: "Milano", cityLatitude: 45, cityLongitude: 9, cityCountry: nil,
                                       armocromia: #"{"season":"deep-winter","confidence":1e18,"altro":"x"}"#)
        let target = try context()
        _ = try await DataImporter.apply(try archive(bundle), to: target)
        let stored = try XCTUnwrap(try ProfileStore.current(in: target).armocromia)
        XCTAssertEqual(ArmocromiaVerdict.decode(stored)?.confidence, 1)
        XCTAssertFalse(String(decoding: stored, as: UTF8.self).contains("altro"))
    }

    func testUnFileConTroppiRecordSiRifiutaSenzaCambiareNulla() async throws {
        var bundle = ExportBundle()
        let day = ExportCalendarEntry(id: "c", day: "2026-11-12", worn: true, outfitID: nil, itemIDs: [], createdAt: .now)
        bundle.calendar = Array(repeating: day, count: DataImporter.recordLimit + 1)
        let target = try context()
        do {
            _ = try await DataImporter.apply(try archive(bundle), to: target)
            XCTFail("Doveva rifiutarlo")
        } catch {
            XCTAssertTrue(error is DataImporter.TooManyRecords)
        }
        XCTAssertEqual(try target.fetchCount(FetchDescriptor<CalendarEntry>()), 0)
    }

    func testCancellataUnaFotoDelCorpoSparisconoLeCopieConLeFoto() throws {
        let tmp = try folder()
        for name in ["importa-1.zip", "StyleVault-2026-11-07.zip", "altro.txt"] {
            FileManager.default.createFile(atPath: tmp.appendingPathComponent(name).path, contents: Data())
        }
        try FileManager.default.createDirectory(at: tmp.appendingPathComponent("prova"), withIntermediateDirectories: true)
        let told = expectation(forNotification: TemporaryFiles.photosForgotten, object: nil)
        TemporaryFiles.forgetPhotos(in: tmp)
        wait(for: [told], timeout: 2)
        // L'importazione in corso resta: la sua copia serve ancora
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: tmp.path).sorted(), ["altro.txt", "importa-1.zip"])
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
