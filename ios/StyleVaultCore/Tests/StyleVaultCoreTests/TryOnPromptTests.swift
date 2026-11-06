import XCTest
@testable import StyleVaultCore

/// Gli stessi casi di `tryOnPrompt.test.js` del sito.
final class TryOnPromptTests: XCTestCase {
    private func garment(_ subcategory: String?, _ colors: [String], name: String = "", category: String = "tops") -> PromptGarment {
        PromptGarment(name: name, category: category, subcategory: subcategory, colors: colors)
    }

    func testUnisceColoreIngleseECapo() {
        XCTAssertEqual(TryOnPrompt.descriptor(garment("shirt", ["white"])), "white button-up shirt")
        XCTAssertEqual(TryOnPrompt.descriptor(garment("jeans", ["denim"])), "denim-blue jeans")
    }

    func testColoreSconosciutoSoloIlCapo() {
        XCTAssertEqual(TryOnPrompt.descriptor(garment("sneakers", ["fuxia"])), "sneakers")
    }

    func testSottocategoriaSconosciutaRipiegaSulNome() {
        XCTAssertEqual(TryOnPrompt.descriptor(garment("zzz", ["black"], name: "Kimono")), "black Kimono")
    }

    func testNumeraICapiPartendoDaImage2() {
        let text = TryOnPrompt.build([garment("shirt", ["white"]), garment("trousers", ["navy"]), garment("sneakers", ["white"])])
        XCTAssertTrue(text.contains("1. white button-up shirt (Image 2)"))
        XCTAssertTrue(text.contains("2. navy-blue trousers (Image 3)"))
        XCTAssertTrue(text.contains("3. white sneakers (Image 4)"))
        XCTAssertTrue(text.contains("preserve their exact face"))
        XCTAssertTrue(text.contains("Return only the final edited photograph"))
        XCTAssertTrue(text.contains("single numbered contact sheet"))
    }

    func testSenzaCapiResteValido() {
        XCTAssertTrue(TryOnPrompt.build([]).contains("Photorealistic virtual try-on"))
    }

    func testRiconosceIlCostumeDalNome() {
        for (name, category) in [("Costume intero blu", "underwear"), ("COSTUMI mare", "custom_1"), ("Bikini a righe", "tops"),
                                 ("Black swimsuit", "underwear"), ("Pantaloncini da bagno", "bottoms")] {
            XCTAssertTrue(TryOnPrompt.hasSwimwear([garment(nil, [], name: name, category: category)]), name)
        }
    }

    func testScarpeEAccessoriNonSonoCostumi() {
        XCTAssertFalse(TryOnPrompt.hasSwimwear([garment(nil, [], name: "Sandali da bagno", category: "shoes"),
                                                garment(nil, [], name: "Costume jewelry", category: "accessories")]))
        XCTAssertFalse(TryOnPrompt.hasSwimwear([garment(nil, [], name: "Maglione", category: "tops")]))
        XCTAssertFalse(TryOnPrompt.hasSwimwear([garment(nil, [], name: "Accostumato", category: "tops")]))
    }
}
