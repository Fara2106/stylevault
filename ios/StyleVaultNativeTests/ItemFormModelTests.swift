import XCTest
import SwiftData
@testable import StyleVaultNative

/// Tiene sospeso chi lo aspetta finché il test non apre.
private actor Gate {
    private var held: [CheckedContinuation<Void, Never>] = []
    var waiting: Int { held.count }
    func wait() async { await withCheckedContinuation { held.append($0) } }
    func open() { held.forEach { $0.resume() }; held = [] }
}

@MainActor final class ItemFormModelTests: XCTestCase {
    private var container: ModelContainer?

    private func filled() -> ItemFormModel {
        let m = ItemFormModel(mode: .add(.wardrobe), prepare: { $0 })
        m.name = "Giacca"
        m.selectCategory("outerwear")
        return m
    }

    private func held(_ gate: Gate) async {
        while await gate.waiting == 0 { await Task.yield() }
    }

    func testSenzaNomeECategoriaNonSalva() {
        let m = ItemFormModel(mode: .add(.wardrobe))
        XCTAssertNil(m.validatedValues())
        XCTAssertEqual(m.errors, [.name, .category])
    }

    func testIlPrimoErroreSegueLOrdineDelModulo() {
        let m = ItemFormModel(mode: .add(.wardrobe))
        XCTAssertNil(m.firstError)
        m.priceText = "abc"
        _ = m.validatedValues()
        XCTAssertEqual(m.firstError, .name)
        m.name = "Giacca"
        _ = m.validatedValues()
        XCTAssertEqual(m.firstError, .category)
        m.selectCategory("outerwear")
        _ = m.validatedValues()
        XCTAssertEqual(m.firstError, .price)
    }

    func testLErroreSparisceQuandoSiCorreggeIlCampo() {
        let m = ItemFormModel(mode: .add(.wardrobe))
        m.priceText = "abc"
        _ = m.validatedValues()
        XCTAssertEqual(m.errors, [.name, .category, .price])
        m.name = "Giacca"
        XCTAssertEqual(m.errors, [.category, .price])
        m.selectCategory("outerwear")
        XCTAssertEqual(m.errors, [.price])
        m.priceText = "12"
        XCTAssertEqual(m.errors, [])
    }

    func testSoloSpaziNonENome() {
        let m = filled()
        m.name = "   "
        XCTAssertNil(m.validatedValues())
        XCTAssertEqual(m.errors, [.name])
    }

    func testValoriPuliti() {
        let m = filled()
        m.name = "  Giacca "; m.brand = "  "; m.priceText = "12,5"; m.linkText = " https://zara.com/p "
        let v = m.validatedValues()
        XCTAssertEqual(v?.name, "Giacca")
        XCTAssertNil(v?.brand)
        XCTAssertEqual(v?.price, 12.5)
        XCTAssertEqual(v?.sourceURL, "https://zara.com/p")
        XCTAssertEqual(m.errors, [])
    }

    func testPrezzoSbagliatoFerma() {
        let m = filled()
        m.priceText = "abc"
        XCTAssertNil(m.validatedValues())
        XCTAssertEqual(m.errors, [.price])
    }

    func testLinkNonValidoNonSiSalvaMaNonFerma() {
        let m = filled()
        m.linkText = "boh"
        XCTAssertNotNil(m.validatedValues())
        XCTAssertNil(m.validatedValues()?.sourceURL)
    }

    func testCambiareCategoriaAzzeraLaSottocategoria() {
        let m = filled()
        m.subcategory = "blazer"
        m.selectCategory("shoes")
        XCTAssertNil(m.subcategory)
        XCTAssertEqual(m.category, "shoes")
    }

    func testIlCaloreParteDalTipoDiCapo() {
        let m = ItemFormModel(mode: .add(.wardrobe), prepare: { $0 })
        XCTAssertEqual(m.warmthLevel, 2)
        m.name = "Cappotto"
        m.selectCategory("outerwear")
        XCTAssertEqual(m.warmthLevel, 4)
        m.subcategory = "coat"
        XCTAssertEqual(m.warmthLevel, 5)
        XCTAssertEqual(m.validatedValues()?.warmthLevel, 5)
    }

    func testIlCaloreSceltoNonCambiaConIlTipo() {
        let m = filled()
        m.warmthLevel = 1
        m.subcategory = "puffer"
        m.selectCategory("tops")
        XCTAssertEqual(m.warmthLevel, 1)
        XCTAssertEqual(m.validatedValues()?.warmthLevel, 1)
    }

    func testInModificaIlCaloreSalvatoResta() throws {
        let built = try StoreFactory.build(.memory)
        container = built
        var v = ItemValues()
        v.name = "Cappotto"; v.category = "outerwear"; v.subcategory = "coat"; v.warmthLevel = 2
        let item = try WardrobeStore.addItem(v, in: built.mainContext)
        let m = ItemFormModel(mode: .edit(item), prepare: { $0 })
        XCTAssertEqual(m.warmthLevel, 2)
        XCTAssertFalse(m.isDirty)
        m.subcategory = "puffer"
        XCTAssertEqual(m.warmthLevel, 2)
    }

    func testColoriSiAccendonoESiSpengono() {
        let m = filled()
        m.toggleColor("navy"); m.toggleColor("white"); m.toggleColor("navy")
        XCTAssertEqual(m.colors, ["white"])
    }

    func testLeModificheParteDalCapo() throws {
        let built = try StoreFactory.build(.memory)
        container = built
        var v = ItemValues()
        v.name = "Giacca"; v.category = "outerwear"; v.subcategory = "blazer"; v.brand = "Zara"; v.size = "M"
        v.colors = ["navy"]; v.season = "winter"; v.occasion = "formal"; v.warmthLevel = 4
        v.sourceURL = "https://zara.com/p"; v.price = 12.5
        v.photoFront = Data([1]); v.photoBack = Data([2])
        let item = try WardrobeStore.addItem(v, in: built.mainContext)
        let m = ItemFormModel(mode: .edit(item))
        XCTAssertTrue(m.isEditing)
        XCTAssertFalse(m.isDirty)
        XCTAssertTrue(m.showsLink)
        XCTAssertEqual(m.linkText, "https://zara.com/p")
        XCTAssertEqual(m.validatedValues(), v)
    }

    func testVuotoNonESporco() {
        XCTAssertFalse(ItemFormModel(mode: .add(.wardrobe)).isDirty)
    }

    func testBastaUnCampoPerEssereSporco() {
        let m = ItemFormModel(mode: .add(.wardrobe))
        m.name = "x"
        XCTAssertTrue(m.isDirty)
    }

    func testUnaFotoSporcaIlModulo() async {
        let m = ItemFormModel(mode: .add(.wardrobe), prepare: { $0 })
        await m.setFront(Data([1]))
        XCTAssertTrue(m.isDirty)
        XCTAssertEqual(m.photoFront, Data([1]))
    }

    func testDueFotoInFrettaVinceLUltima() async {
        let gate = Gate()
        let m = ItemFormModel(mode: .add(.wardrobe), prepare: { raw in
            if raw == Data([1]) { await gate.wait() }
            return raw
        })
        let slow = Task { await m.setFront(Data([1])) }
        await held(gate)
        await m.setFront(Data([2]))
        XCTAssertEqual(m.photoFront, Data([2]))
        XCTAssertFalse(m.isProcessingPhoto)
        await gate.open()
        await slow.value
        XCTAssertEqual(m.photoFront, Data([2]))
        XCTAssertFalse(m.isProcessingPhoto)
    }

    func testMentreSiElaboraNonSiSalva() async {
        let gate = Gate()
        let m = ItemFormModel(mode: .add(.wardrobe), prepare: { raw in await gate.wait(); return raw })
        XCTAssertTrue(m.canSave)
        let task = Task { await m.setBack(Data([1])) }
        await held(gate)
        XCTAssertTrue(m.isProcessingPhoto)
        XCTAssertFalse(m.canSave)
        await gate.open()
        await task.value
        XCTAssertTrue(m.canSave)
        XCTAssertEqual(m.photoBack, Data([1]))
    }

    func testMentreSiScaricaDaICloudNonSiSalva() async {
        let gate = Gate()
        let m = ItemFormModel(mode: .add(.wardrobe), prepare: { $0 })
        let task = Task { await m.setFront(loading: { await gate.wait(); return Data([1]) }) }
        await held(gate)
        XCTAssertFalse(m.canSave)
        await gate.open()
        await task.value
        XCTAssertTrue(m.canSave)
        XCTAssertEqual(m.photoFront, Data([1]))
    }

    func testFotoIllegibile() async {
        let m = ItemFormModel(mode: .add(.wardrobe), prepare: { _ in nil })
        await m.setFront(Data([1]))
        XCTAssertTrue(m.photoFailed)
        XCTAssertNil(m.photoFront)
        XCTAssertTrue(m.canSave)
    }

    func testTogliereIlRetro() async {
        let m = ItemFormModel(mode: .add(.wardrobe), prepare: { $0 })
        await m.setBack(Data([1]))
        m.removeBack()
        XCTAssertNil(m.photoBack)
    }
}
