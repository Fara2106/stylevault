import XCTest
@testable import StyleVaultNative

@MainActor private final class StubReader: LinkReading {
    var result: Result<LinkPreview, Error>
    var calls = 0
    var beforeReturning: (() -> Void)?

    init(_ result: Result<LinkPreview, Error>) { self.result = result }

    func read(_ url: URL) async throws -> LinkPreview {
        calls += 1
        beforeReturning?()
        return try result.get()
    }
}

@MainActor final class LinkFormTests: XCTestCase {
    private func filled(link: String = "https://zara.com/p") -> ItemFormModel {
        let m = ItemFormModel(mode: .add(.wardrobe), prepare: { $0 })
        m.linkText = link
        return m
    }

    func testRiempieSoloICampiVuoti() async {
        let m = filled()
        m.name = "Mio"
        await m.analyzeLink(with: StubReader(.success(.init(title: "Camicia", site: "Zara", imageData: nil))))
        XCTAssertEqual(m.name, "Mio")
        XCTAssertEqual(m.brand, "Zara")
        XCTAssertEqual(m.linkState, .success)
    }

    func testRiempieIlNomeVuoto() async {
        let m = filled()
        await m.analyzeLink(with: StubReader(.success(.init(title: "Camicia", site: "Zara", imageData: nil))))
        XCTAssertEqual(m.name, "Camicia")
    }

    func testUsaLaFotoSoloSeNonCeGia() async {
        let m = filled()
        await m.analyzeLink(with: StubReader(.success(.init(title: "A", site: "B", imageData: Data([1])))))
        XCTAssertEqual(m.photoFront, Data([1]))
        await m.analyzeLink(with: StubReader(.success(.init(title: "A", site: "B", imageData: Data([2])))))
        XCTAssertEqual(m.photoFront, Data([1]))
    }

    func testLinkIlleggibileTieneIlLink() async {
        let m = filled(link: "https://blindato.com/p")
        m.name = "Mio"
        m.selectCategory("tops")
        await m.analyzeLink(with: StubReader(.failure(LinkReadError.unreadable)))
        XCTAssertEqual(m.linkState, .failure)
        XCTAssertEqual(m.validatedValues()?.sourceURL, "https://blindato.com/p")
    }

    func testLinkNonValidoNonChiamaIlLettore() async {
        let m = filled(link: "boh")
        let reader = StubReader(.failure(LinkReadError.unreadable))
        await m.analyzeLink(with: reader)
        XCTAssertEqual(reader.calls, 0)
        XCTAssertEqual(m.linkState, .idle)
    }

    func testLinkCambiatoMentreLeggeNonSovrascrive() async {
        let m = filled()
        let reader = StubReader(.success(.init(title: "Vecchio", site: "Zara", imageData: nil)))
        reader.beforeReturning = { m.linkText = "https://altro.com/p" }
        await m.analyzeLink(with: reader)
        XCTAssertEqual(m.name, "")
        XCTAssertEqual(m.brand, "")
        XCTAssertEqual(m.linkState, .idle)
    }

    func testPaginaBloccataEIlleggibile() {
        XCTAssertThrowsError(try SystemLinkReader.preview(title: "Access Denied", host: "www2.hm.com", imageData: nil))
    }

    func testPaginaBloccataConFotoEIlleggibile() {
        XCTAssertThrowsError(try SystemLinkReader.preview(title: "Access Denied", host: "www2.hm.com", imageData: Data([1])))
    }

    func testSenzaTitoloESenzaFotoEIlleggibile() {
        XCTAssertThrowsError(try SystemLinkReader.preview(title: nil, host: "www.zara.com", imageData: nil))
    }

    func testSoloFotoVaBene() throws {
        let preview = try SystemLinkReader.preview(title: nil, host: "www.zara.com", imageData: Data([1]))
        XCTAssertEqual(preview, LinkPreview(title: "", site: "Zara", imageData: Data([1])))
    }

    func testTitoloPulito() throws {
        let preview = try SystemLinkReader.preview(title: "Camicia - Zara", host: "www.zara.com", imageData: nil)
        XCTAssertEqual(preview.title, "Camicia")
        XCTAssertEqual(preview.site, "Zara")
    }
}
