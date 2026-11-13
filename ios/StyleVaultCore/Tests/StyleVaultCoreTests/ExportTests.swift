import XCTest
@testable import StyleVaultCore

final class ExportTests: XCTestCase {
    private func temporaryURL(_ name: String = "prova.zip") throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return folder.appendingPathComponent(name)
    }

    func testAndataERitornoDelloZip() throws {
        let url = try temporaryURL()
        let writer = try ZipWriter(url: url)
        try writer.add(name: "a.json", data: Data("ciao".utf8))
        try writer.add(name: "photos/b.jpg", data: Data([0, 1, 2, 255]))
        try writer.close()
        let reader = try ZipReader(url: url)
        XCTAssertEqual(Set(reader.names), ["a.json", "photos/b.jpg"])
        XCTAssertEqual(try reader.data(name: "a.json"), Data("ciao".utf8))
        XCTAssertEqual(try reader.data(name: "photos/b.jpg"), Data([0, 1, 2, 255]))
        XCTAssertNil(try reader.data(name: "manca"))
    }

    func testLoZipSiApreConGliStrumentiStandard() throws {
        let url = try temporaryURL()
        let writer = try ZipWriter(url: url)
        try writer.add(name: "a.txt", data: Data(repeating: 65, count: 5000))
        try writer.close()
        let check = Process()
        check.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        check.arguments = ["-tq", url.path]
        check.standardOutput = Pipe()
        try check.run()
        check.waitUntilExit()
        XCTAssertEqual(check.terminationStatus, 0)
    }

    func testLeggeUnoZipCompressoDaAltri() throws {
        let source = try temporaryURL("testo.txt")
        let text = String(repeating: "StyleVault ", count: 500)
        try Data(text.utf8).write(to: source)
        let zip = source.deletingLastPathComponent().appendingPathComponent("altro.zip")
        let make = Process()
        make.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        make.currentDirectoryURL = source.deletingLastPathComponent()
        make.arguments = ["-q", "altro.zip", "testo.txt"]
        try make.run()
        make.waitUntilExit()
        XCTAssertEqual(try ZipReader(url: zip).data(name: "testo.txt"), Data(text.utf8))
    }

    func testUnFileQualsiasiNonEUnoZip() throws {
        let url = try temporaryURL()
        try Data("non sono uno zip".utf8).write(to: url)
        XCTAssertThrowsError(try ZipReader(url: url))
    }

    func testIlDocumentoSopravviveAlPassaggio() throws {
        let garment = ExportGarment(id: "A", name: "Maglia", category: "tops", subcategory: "tshirt", brand: nil, size: "M",
                                    colors: ["red"], season: "all", occasion: "casual", warmthLevel: 2, sourceURL: nil,
                                    price: 12.5, favorite: true, createdAt: Date(timeIntervalSince1970: 100),
                                    photoFront: "photos/A-front.jpg", photoBack: nil, cutout: nil)
        var bundle = ExportBundle(exportedAt: Date(timeIntervalSince1970: 200))
        bundle.items = [garment]
        bundle.profile = ExportProfile(theme: "dark", cityName: "Roma", cityLatitude: 41.9, cityLongitude: 12.5,
                                       cityCountry: "Italia", armocromia: "{}")
        XCTAssertEqual(try ExportBundle.decode(bundle.encoded()), bundle)
    }

    func testUnaVersioneFuturaSiRifiuta() throws {
        let data = Data(#"{"version":99,"exportedAt":"2026-11-06T10:00:00Z"}"#.utf8)
        XCTAssertThrowsError(try ExportBundle.decode(data)) { error in
            XCTAssertEqual(error as? ExportError, .newerVersion)
        }
    }

    func testIlFileEsportatoHaDocumentoEFoto() throws {
        let url = try temporaryURL()
        var bundle = ExportBundle(exportedAt: Date(timeIntervalSince1970: 200))
        bundle.bodyPhotos = [ExportBodyPhoto(kind: "front", file: "photos/body-front.jpg")]
        try ExportArchive.write(bundle, photos: ["photos/body-front.jpg": Data([9, 9])], to: url)
        let read = try ExportArchive.read(url)
        XCTAssertEqual(read.bundle, bundle)
        XCTAssertEqual(try read.photo("photos/body-front.jpg"), Data([9, 9]))
    }

    func testUnoZipSenzaDocumentoNonEUnaEsportazione() throws {
        let url = try temporaryURL()
        let writer = try ZipWriter(url: url)
        try writer.add(name: "altro.txt", data: Data("x".utf8))
        try writer.close()
        XCTAssertThrowsError(try ExportArchive.read(url)) { error in
            XCTAssertEqual(error as? ExportError, .notAnExport)
        }
    }

    /// Prodotto da `scripts/esporta-da-supabase.mjs`: il formato dello script e quello dell'app devono coincidere.
    func testLeggeIlFileDelloScriptDaSupabase() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "da-supabase", withExtension: "zip", subdirectory: "Fixtures"))
        let read = try ExportArchive.read(url)
        XCTAssertEqual(read.bundle.items.first?.id, "capo-1")
        XCTAssertEqual(try read.photo(read.bundle.items.first?.photoFront), Data([7, 8]))
    }

    func testIlNomeDelFileHaLaData() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Rome")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 11, day: 6))!
        XCTAssertEqual(ExportArchive.fileName(date: date, calendar: calendar), "StyleVault-2026-11-06.zip")
    }

    private func zipFile(_ entries: [String: Data]) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).zip")
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        let writer = try ZipWriter(url: url)
        for (name, data) in entries { try writer.add(name: name, data: data) }
        try writer.close()
        return url
    }

    func testUnaFotoRovinataNonPassaPerBuona() throws {
        let url = try zipFile(["a.jpg": Data([1, 2, 3, 4])])
        var bytes = try Data(contentsOf: url)
        let start = try XCTUnwrap(bytes.range(of: Data([1, 2, 3, 4]))).lowerBound
        bytes[start] = 9
        try bytes.write(to: url)
        XCTAssertThrowsError(try ZipReader(url: url).data(name: "a.jpg")) { XCTAssertEqual($0 as? ZipError, .damaged) }
    }

    func testIlLimiteValeAncheSenzaCompressione() throws {
        let url = try zipFile(["a.jpg": Data(repeating: 1, count: 100)])
        XCTAssertThrowsError(try ZipReader(url: url, entryLimit: 10).data(name: "a.jpg")) { XCTAssertEqual($0 as? ZipError, .tooLarge) }
        XCTAssertEqual(try ZipReader(url: url, entryLimit: 100).data(name: "a.jpg")?.count, 100)
    }

    func testIlCalendarioRicordaICapiPerNome() throws {
        var bundle = ExportBundle()
        bundle.calendar = [ExportCalendarEntry(id: "c", day: "2026-11-06", worn: true, outfitID: nil, itemIDs: [], createdAt: .now,
                                               snapshot: [WornItem(id: "a", name: "Maglia", category: "tops")])]
        let decoded = try ExportBundle.decode(bundle.encoded())
        XCTAssertEqual(decoded.calendar.first?.snapshot, [WornItem(id: "a", name: "Maglia", category: "tops")])
    }

    func testUnFileSenzaIlRicordoDeiCapiSiLeggeUgualmente() throws {
        var bundle = ExportBundle()
        bundle.calendar = [ExportCalendarEntry(id: "c", day: "2026-11-06", worn: true, outfitID: nil, itemIDs: [], createdAt: .now)]
        XCTAssertNil(try ExportBundle.decode(bundle.encoded()).calendar.first?.snapshot)
    }

    func testLeDateDeiFileSiControllano() {
        XCTAssertTrue(CalendarMath.isValid("2026-11-07"))
        XCTAssertFalse(CalendarMath.isValid("2026-13-40"))
        XCTAssertFalse(CalendarMath.isValid("domani"))
        XCTAssertEqual(CalendarMath.local.identifier, .gregorian)
    }


    func testUnaFotoHaUnTettoPiuBassoDelDocumento() throws {
        let url = try zipFile(["a.jpg": Data(repeating: 1, count: 100)])
        let reader = try ZipReader(url: url)
        XCTAssertThrowsError(try reader.data(name: "a.jpg", limit: 10)) { XCTAssertEqual($0 as? ZipError, .tooLarge) }
        XCTAssertEqual(try reader.data(name: "a.jpg", limit: 100)?.count, 100)
        // Il tetto per voce non alza mai quello del lettore
        XCTAssertThrowsError(try ZipReader(url: url, entryLimit: 10).data(name: "a.jpg", limit: 1000))
    }

    func testUnNomeCheNonStaNelCampoSiRifiuta() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("lungo.zip")
        let writer = try ZipWriter(url: url)
        // Troncato a 16 bit darebbe un file che l'app stessa non riesce a rileggere
        XCTAssertThrowsError(try writer.add(name: String(repeating: "A", count: 65_536), data: Data([1]))) {
            XCTAssertEqual($0 as? ZipError, .tooLarge)
        }
        try writer.add(name: String(repeating: "A", count: 65_535), data: Data([1]))
        try writer.add(name: "b", data: Data([2]))
        try writer.close()
        XCTAssertEqual(try ZipReader(url: url).data(name: "b"), Data([2]))
    }
}
