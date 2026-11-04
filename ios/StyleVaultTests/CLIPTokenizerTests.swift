import XCTest
@testable import StyleVault

final class CLIPTokenizerTests: XCTestCase {
    private struct Case: Decodable {
        let text: String
        let ids: [Int32]
        let ids2: [Int32]
    }

    private var fixtures: URL {
        Bundle(for: CLIPTokenizerTests.self).resourceURL!.appendingPathComponent("realistic")
    }

    private func cases() throws -> [Case] {
        let data = try Data(contentsOf: fixtures.appendingPathComponent("tokenizer-cases.json"))
        return try JSONDecoder().decode([Case].self, from: data)
    }

    private func tokenizer(pad: String) throws -> CLIPTokenizer {
        let dir = fixtures.appendingPathComponent("tokenizer")
        return try CLIPTokenizer(vocab: dir.appendingPathComponent("vocab.json"),
                                 merges: dir.appendingPathComponent("merges.txt"),
                                 padToken: pad)
    }

    func testMatchesPythonCases() throws {
        let all = try cases()
        XCTAssertEqual(all.count, 6)
        let t1 = try tokenizer(pad: "<|endoftext|>")
        let t2 = try tokenizer(pad: "!")
        for (i, c) in all.enumerated() {
            XCTAssertEqual(t1.ids(c.text), c.ids, "caso \(i) con pad <|endoftext|>")
            XCTAssertEqual(t2.ids(c.text), c.ids2, "caso \(i) con pad !")
            XCTAssertEqual(t1.ids(c.text).count, 77)
        }
    }

    func testCaptionFallbacks() {
        func item(name: String, descriptor: String?) -> AvatarItem {
            AvatarItem(id: "1", category: "tops", slot: "top", photo: "", name: name,
                       photoBack: nil, descriptor: descriptor)
        }
        XCTAssertEqual(GarmentCaption.cloth(item(name: "Maglione", descriptor: "cream sweater")),
                       "The item is a cream sweater.")
        XCTAssertEqual(GarmentCaption.cloth(item(name: "Maglione", descriptor: nil)),
                       "The item is a Maglione.")
        XCTAssertEqual(GarmentCaption.cloth(item(name: "Maglione", descriptor: "")),
                       "The item is a Maglione.")
        XCTAssertEqual(GarmentCaption.cloth(item(name: "", descriptor: nil)),
                       "The item is a garment.")
        XCTAssertTrue(GarmentCaption.person(item(name: "Maglione", descriptor: "cream sweater"))
            .hasPrefix("Replace the upper body with item is a "))
        XCTAssertEqual(GarmentCaption.person(item(name: "x", descriptor: "cream sweater")),
                       "Replace the upper body with item is a cream sweater.")
    }

    func testNegativeMatchesPythonText() throws {
        XCTAssertEqual(GarmentCaption.negative, try cases()[0].text)
    }
}
