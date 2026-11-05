# App nativa, fase 2: Guardaroba. Piano di implementazione

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** nell'app nativa si aggiungono capi da fotocamera, libreria o link, si sfogliano con filtri e preferiti, si modificano, si cancellano, e la wishlist funziona; tutto arriva sull'altro dispositivo con iCloud.

**Architecture:** la logica senza interfaccia (filtri, testi dei link, prezzo, immagini, scontorno) sta in `StyleVaultCore` e si prova sul Mac con `swift test`, perché Vision non gira nel simulatore iOS 27. Le scritture su SwiftData passano da `WardrobeStore`, come il Profilo passa da `ProfileStore`. Le viste stanno in `ios/StyleVaultNative/Wardrobe/`.

**Tech Stack:** Swift, SwiftUI, SwiftData con CloudKit, Vision, ImageIO, LinkPresentation, PhotosUI, XCTest, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-11-04-app-nativa-icloud-design.md`, fase 2, "Architettura" e rischi. Da portare: `src/pages/WardrobePage`, `AddItemPage`, `ItemDetailPage`, `src/services/linkMetadata.js`.

## Global Constraints

- Ramo `feat/app-nativa`. Prima di commit e prove guardare `git log`, `git status` e `MEMORIA.md`.
- iOS 17, iPhone e iPad. Solo API Apple, niente Supabase, niente microlink.
- CloudKit: ogni proprietà facoltativa o con default, niente `unique`.
- Niente login, niente funzioni nascoste nella Release. Gli argomenti di prova stanno dentro `#if DEBUG`.
- Foto: 1600 px sul lato lungo, JPEG 0,85, come dice il design.
- L'aggiunta non si blocca mai: se foto, scontorno o link non riescono, il capo si salva lo stesso.
- Italiano e inglese. `Localizable.xcstrings` è generato da `tools/nativa/export-strings.mjs`: non si tocca a mano.
- Non è un nuovo design: Palette, `Font.display` e disposizione del sito.
- `Info.plist` è rigenerato da xcodegen: i valori stanno in `ios/project.yml`.
- Simulatori: iPhone 18 Pro `18361580-2FC8-4A18-AED3-7461008C6569`; iPad Pro 11" M5 `B04B93AB-9CE8-425C-B2B5-BC10A2BD0559` solo se libero. Non toccare `0ED66ECB` e `1C8ED7D7`, niente `pkill` o `killall`.
- Mai due `xcodebuild` insieme: il Mac ha 16 GB ed è condiviso.
- Commit in italiano, con riga finale `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Commit locali sì, push solo con l'ok di Lorenzo.

**Comandi di prova:**

```bash
cd ios/StyleVaultCore && swift test
cd ios && xcodegen generate && xcodebuild test -project StyleVault.xcodeproj -scheme StyleVaultNative -destination 'platform=iOS Simulator,id=18361580-2FC8-4A18-AED3-7461008C6569' -derivedDataPath build/dd-native
```

Con `-only-testing:StyleVaultNativeTests/<Classe>` si lancia una classe sola.

## Scelte di questo piano

Non sono nel design. Stanno qui perché Lorenzo possa rovesciarle.

- **Scontorno a 1024 px, PNG.** Il design fissa solo le foto. Il PNG con trasparenza pesa, e l'avatar non chiede di più. Lo scontorno non si fa sulla wishlist, solo quando un desiderio diventa un capo.
- **Il salvataggio non aspetta lo scontorno.** Il foglio si chiude subito e lo scontorno arriva dopo. Se l'app viene chiusa prima, il capo resta senza: la fase 6 lo calcolerà al bisogno, come fa già l'ibrida.
- **Le foto nel dettaglio si sfogliano:** davanti, retro, scontorno. Griglia e dettaglio aprono sulla foto, come il sito. Il sito non mostra il retro né lo scontorno, ma altrimenti non si vedrebbero mai.
- **Capo senza foto:** nessun JPEG generato, la vista disegna l'iniziale. Niente da caricare su iCloud.
- **Categorie personalizzate:** nel sito esiste solo la funzione, senza schermate. Qui si creano dal modulo con "Nuova categoria" e si cancellano tenendo premuto il filtro, solo se nessun capo le usa.
- **Modulo:** il selettore Foto/Link resta visibile anche in modifica, e il link si salva anche senza premere Analizza. Nel sito, in modifica, si perde.
- **Modifica solo per i capi,** come il sito. Un desiderio si apre nel negozio, si compra o si cancella.

**Spostati da questa fase:**

- Doppioni di `BodyPhoto`: alla fase 6, che è la prima a scrivere foto del corpo. Il piano della fase 1 li metteva qui, ma sarebbe codice senza chiamanti.
- `setArmocromia`: alla fase 5, stesso motivo.
- Scheda "usato in N outfit, indossato N volte": alla fase 4, prima non ci sono dati.
- Tasto "Prova outfit" del dettaglio: alla fase 6.

## Review Focus

1. Due foto scelte in fretta, o Salva premuto mentre la foto si sta elaborando: resta l'ultima scelta e il capo non si salva senza. Test in Task 6.
2. Foto davanti cambiata in modifica, o capo cancellato mentre si scontorna: il vecchio scontorno sparisce e uno in ritardo non si scrive sul capo sbagliato. Test in Task 3 e Task 4.
3. Negozio che risponde "Access Denied", che non ha immagine, o nessuna rete: niente titolo sbagliato nel nome, il link resta, il capo si salva. Test in Task 1 e Task 7.
4. Categoria personalizzata cancellata da un altro dispositivo mentre un capo la usa: nessuna chiave grezza, il capo resta in "Tutti". Test in Task 3 e Task 9.
5. Foglio chiuso per sbaglio con una bozza: prima chiede conferma. Foglio vuoto: si chiude e basta. Test in Task 6.

---

## Struttura dei file

```text
ios/StyleVaultCore/Sources/StyleVaultCore/
  WardrobeFilter.swift      filtro di categoria, preferiti e ricerca
  ItemText.swift            iniziale del segnaposto, prezzo digitato
  LinkText.swift            URL valido, titolo pulito, nome del negozio, pagine bloccate
  GarmentImage.swift        foto pronta, miniatura, scontorno Vision
ios/StyleVaultNative/
  Data/Models.swift                 + CustomCategory
  Data/ItemValues.swift             valori puliti del modulo
  Data/WardrobeStore.swift          scritture su capi e wishlist
  Data/CustomCategoryStore.swift    categorie personalizzate
  Data/CutoutWorker.swift           scontorno dopo il salvataggio, uno alla volta
  Wardrobe/WardrobeView.swift       schermata con Guardaroba e Wishlist
  Wardrobe/WishlistSection.swift
  Wardrobe/ItemCard.swift
  Wardrobe/ItemPhotoView.swift      foto o iniziale, con cache delle miniature
  Wardrobe/CategoryChips.swift      filtri e FlowLayout
  Wardrobe/CategoryChoice.swift     categorie del catalogo e personalizzate insieme
  Wardrobe/ItemDetailView.swift
  Wardrobe/ItemFormModel.swift      stato del modulo
  Wardrobe/ItemFormView.swift
  Wardrobe/CameraPicker.swift
  Wardrobe/LinkReader.swift         LPMetadataProvider
```

---

### Task 1: Logica di testo in StyleVaultCore

**Files:**
- Create: `ios/StyleVaultCore/Sources/StyleVaultCore/WardrobeFilter.swift`, `ItemText.swift`, `LinkText.swift`
- Test: `ios/StyleVaultCore/Tests/StyleVaultCoreTests/WardrobeFilterTests.swift`, `ItemTextTests.swift`, `LinkTextTests.swift`

**Interfaces:**
- Produces:

```swift
public struct WardrobeFilter: Equatable, Sendable {
    public var category: String?          // nil = tutte
    public var onlyFavorites: Bool
    public var search: String
    public init(category: String? = nil, onlyFavorites: Bool = false, search: String = "")
    public func matches(name: String, brand: String?, category: String, favorite: Bool) -> Bool
}
public enum PriceInput: Equatable, Sendable { case empty, value(Double), invalid }
public enum ItemText {
    public static func placeholderInitial(_ name: String?) -> String
    public static func parsePrice(_ text: String) -> PriceInput
}
public enum LinkText {
    public static func httpURL(from text: String) -> URL?
    public static func stripShopSuffix(_ title: String, site: String) -> String
    public static func siteName(host: String) -> String
    public static func isBlockedTitle(_ title: String) -> Bool
}
```

- [ ] **Step 1: Scrivere i test**

`WardrobeFilterTests`: come `WardrobePage.jsx`.

```swift
func testRicercaSuNomeEBrandSenzaMaiuscole() {
    let f = WardrobeFilter(search: "  ZARA ")
    XCTAssertTrue(f.matches(name: "Camicia", brand: "Zara", category: "tops", favorite: false))
    XCTAssertTrue(f.matches(name: "zara basic", brand: nil, category: "tops", favorite: false))
    XCTAssertFalse(f.matches(name: "Camicia", brand: nil, category: "tops", favorite: false))
}
func testCategoriaEPreferitiSiSommano() {
    let f = WardrobeFilter(category: "shoes", onlyFavorites: true)
    XCTAssertTrue(f.matches(name: "A", brand: nil, category: "shoes", favorite: true))
    XCTAssertFalse(f.matches(name: "A", brand: nil, category: "shoes", favorite: false))
    XCTAssertFalse(f.matches(name: "A", brand: nil, category: "tops", favorite: true))
}
func testFiltroVuotoPrendeTutto() {
    XCTAssertTrue(WardrobeFilter().matches(name: "", brand: nil, category: "", favorite: false))
}
```

`ItemTextTests`:

```swift
func testIniziale() {
    XCTAssertEqual(ItemText.placeholderInitial("maglione blu"), "M")
    XCTAssertEqual(ItemText.placeholderInitial("  èlite"), "È")
    XCTAssertEqual(ItemText.placeholderInitial(""), "·")
    XCTAssertEqual(ItemText.placeholderInitial(nil), "·")
}
func testPrezzo() {
    XCTAssertEqual(ItemText.parsePrice(""), .empty)
    XCTAssertEqual(ItemText.parsePrice("  "), .empty)
    XCTAssertEqual(ItemText.parsePrice("12"), .value(12))
    XCTAssertEqual(ItemText.parsePrice("12,50"), .value(12.5))
    XCTAssertEqual(ItemText.parsePrice("12.50"), .value(12.5))
    XCTAssertEqual(ItemText.parsePrice("0"), .value(0))
    XCTAssertEqual(ItemText.parsePrice("abc"), .invalid)
    XCTAssertEqual(ItemText.parsePrice("-5"), .invalid)
    XCTAssertEqual(ItemText.parsePrice("1.234,50"), .invalid)
}
```

`LinkTextTests`, con i casi di `linkMetadata.test.js`:

```swift
func testURL() {
    XCTAssertEqual(LinkText.httpURL(from: " https://zara.com/p/1\n")?.absoluteString, "https://zara.com/p/1")
    XCTAssertNotNil(LinkText.httpURL(from: "http://example.com"))
    XCTAssertNil(LinkText.httpURL(from: "ftp://x.com"))
    XCTAssertNil(LinkText.httpURL(from: "non-un-url"))
    XCTAssertNil(LinkText.httpURL(from: "https://"))
    XCTAssertNil(LinkText.httpURL(from: ""))
}
func testTitoloSenzaNegozio() {
    XCTAssertEqual(LinkText.stripShopSuffix("Camicia in lino - Zara", site: "Zara"), "Camicia in lino")
    XCTAssertEqual(LinkText.stripShopSuffix("Polo Club RIGBY GO U - Maglione - ecru/bianco - Zalando.it", site: "zalando.it"),
                   "Polo Club RIGBY GO U - Maglione - ecru/bianco")
    XCTAssertEqual(LinkText.stripShopSuffix("Pantaloni chino", site: "Shop"), "Pantaloni chino")
    XCTAssertEqual(LinkText.stripShopSuffix("T-shirt - Blu", site: "Zara"), "T-shirt - Blu")
}
func testNomeDelNegozio() {
    XCTAssertEqual(LinkText.siteName(host: "www.zalando.it"), "Zalando")
    XCTAssertEqual(LinkText.siteName(host: "www2.hm.com"), "Hm")
    XCTAssertEqual(LinkText.siteName(host: "www.zalando.co.uk"), "Zalando")
    XCTAssertEqual(LinkText.siteName(host: "shop.example.com"), "Example")
    XCTAssertEqual(LinkText.siteName(host: "localhost"), "Localhost")
}
func testPagineBloccate() {
    XCTAssertTrue(LinkText.isBlockedTitle("Access Denied"))
    XCTAssertTrue(LinkText.isBlockedTitle("  just a moment..."))
    XCTAssertTrue(LinkText.isBlockedTitle("403 Forbidden"))
    XCTAssertTrue(LinkText.isBlockedTitle("Page not found"))
    XCTAssertFalse(LinkText.isBlockedTitle("Maglione a trecce"))
}
```

- [ ] **Step 2: Lanciarli**

Run: `cd ios/StyleVaultCore && swift test`
Expected: FAIL, i tipi non esistono.

- [ ] **Step 3: Implementare**

- `stripShopSuffix`: come `linkMetadata.js`. Separatori `\s+[-|–]\s+`, negozio = primo pezzo di `site` senza `www.`, confronto in minuscolo. Con `site` vuoto il titolo non cambia.
- `siteName`: togli `^www\d*\.`; se restano almeno 3 pezzi e il penultimo è lungo al massimo 3, prendi il terzultimo, altrimenti il penultimo; con un pezzo solo prendi quello. Prima lettera maiuscola.
- `isBlockedTitle`: confronto in minuscolo sull'inizio del titolo con `access denied`, `just a moment`, `attention required`, `forbidden`, `403`, `404`, `page not found`, `pagina non trovata`, `robot check`.
- `parsePrice`: `,` diventa `.`, poi `Double`. Più di un separatore, valore negativo o non finito: `.invalid`.
- `placeholderInitial`: maiuscola con `Locale(identifier: "it")`.

- [ ] **Step 4: Rilanciarli**

Run: `cd ios/StyleVaultCore && swift test`
Expected: tutti verdi, compresi gli 8 di prima.

- [ ] **Step 5: Commit**

```bash
git add ios/StyleVaultCore
git commit -m "feat(nativa): filtri, prezzo e testi dei link in StyleVaultCore"
```

---

### Task 2: Immagini e scontorno in StyleVaultCore

**Files:**
- Create: `ios/StyleVaultCore/Sources/StyleVaultCore/GarmentImage.swift`
- Copy: `ios/StyleVaultTests/Fixtures/maglione.jpg` e `sneakers.jpg` in `ios/StyleVaultCore/Tests/StyleVaultCoreTests/Fixtures/`
- Test: `ios/StyleVaultCore/Tests/StyleVaultCoreTests/GarmentImageTests.swift`

**Interfaces:**
- Produces:

```swift
public enum GarmentImage {
    public static let photoMaxSide = 1600
    public static let jpegQuality = 0.85
    public static let cutoutMaxSide = 1024
    public static let thumbnailMaxSide = 400
    /// JPEG raddrizzato e ridotto; nil se i dati non sono un'immagine.
    public static func prepared(_ data: Data) -> Data?
    public static func thumbnail(_ data: Data, maxSide: Int = thumbnailMaxSide) -> CGImage?
    /// PNG con sfondo trasparente; nil se non trova un soggetto o Vision non è disponibile.
    public static func cutout(_ data: Data) async -> Data?
}
```

- [ ] **Step 1: Scrivere i test**

Aiutanti nel file di test: `makeImage(width:height:color:alpha:)` e `encode(_:type:orientation:)` con ImageIO; `decode(_:)` per leggere dimensioni e pixel.

```swift
func testRiduceIlLatoLungo() throws {
    let out = try XCTUnwrap(GarmentImage.prepared(encode(makeImage(width: 3000, height: 2000), type: .png)))
    let image = try decode(out)
    XCTAssertEqual(image.width, 1600); XCTAssertEqual(image.height, 1067)
}
func testNonIngrandisce() throws {
    let image = try decode(XCTUnwrap(GarmentImage.prepared(encode(makeImage(width: 300, height: 200), type: .png))))
    XCTAssertEqual(image.width, 300)
}
func testRaddrizzaConLEXIF() throws {
    let rotated = encode(makeImage(width: 400, height: 200), type: .jpeg, orientation: 6)
    let image = try decode(XCTUnwrap(GarmentImage.prepared(rotated)))
    XCTAssertEqual(image.width, 200); XCTAssertEqual(image.height, 400)
}
func testIlTrasparenteDiventaBianco() throws {
    let out = try XCTUnwrap(GarmentImage.prepared(encode(makeImage(width: 50, height: 50, alpha: 0), type: .png)))
    XCTAssertGreaterThan(try redComponent(decode(out), x: 25, y: 25), 250)
}
func testDatiNonImmagine() { XCTAssertNil(GarmentImage.prepared(Data("ciao".utf8))) }
func testMiniatura() throws {
    let thumb = try XCTUnwrap(GarmentImage.thumbnail(encode(makeImage(width: 3000, height: 1000), type: .png)))
    XCTAssertEqual(thumb.width, 400)
}
func testScontornoDelCapo() async throws {
    let photo = try fixture("maglione.jpg")
    let png = try await XCTUnwrapAsync(GarmentImage.cutout(photo))
    let image = try decode(png)
    XCTAssertLessThanOrEqual(max(image.width, image.height), GarmentImage.cutoutMaxSide)
    XCTAssertGreaterThan(transparentFraction(image), 0.1)
    XCTAssertLessThan(transparentFraction(image), 0.95)
}
func testIUnPaioDiScarpeRestaIntero() async throws {
    let png = try await XCTUnwrapAsync(GarmentImage.cutout(try fixture("sneakers.jpg")))
    XCTAssertLessThan(transparentFraction(try decode(png)), 0.95)
}
func testTintaUnitaNonHaSoggetto() async {
    let plain = encode(makeImage(width: 600, height: 600), type: .jpeg)
    let out = await GarmentImage.cutout(plain)
    XCTAssertNil(out)
}
```

`XCTUnwrapAsync` non esiste: si assegna il risultato a una costante prima di `XCTUnwrap`.

Nel `testScontornoDelCapo` stampare i byte del PNG e della foto: il numero serve a controllare il peso su iCloud.

- [ ] **Step 2: Lanciarli**

Run: `cd ios/StyleVaultCore && swift test --filter GarmentImageTests`
Expected: FAIL, `GarmentImage` non esiste.

- [ ] **Step 3: Implementare**

- Decodifica con `CGImageSourceCreateThumbnailAtIndex`, opzioni `kCGImageSourceCreateThumbnailWithTransform` e `kCGImageSourceCreateThumbnailFromImageAlways`, lato massimo `min(maxSide, lato lungo della foto)` letto da `CGImageSourceCopyPropertiesAtIndex` e corretto per nessun ingrandimento. Così una foto da 48 MP non entra mai intera in memoria.
- `prepared`: disegna su fondo bianco in un `CGContext` RGB, poi JPEG con `CGImageDestination` a qualità 0,85.
- `cutout`: come `ios/StyleVault/Vision/PersonCutout.swift` con tutte le istanze, perché un paio di scarpe sono due soggetti. Lavora dentro `Task.detached`, a 1024 px. Maschera vuota o qualunque errore: `nil`. Sotto `#if targetEnvironment(simulator)` ritorna subito `nil`.

Non importare UIKit o AppKit: il pacchetto si prova sul Mac.

- [ ] **Step 4: Rilanciarli**

Run: `cd ios/StyleVaultCore && swift test`
Expected: tutti verdi. Se un test di Vision fallisce, leggere la soglia di `VisionTests.swift` prima di toccarla.

- [ ] **Step 5: Commit**

```bash
git add ios/StyleVaultCore
git commit -m "feat(nativa): foto pronte, miniature e scontorno dei capi con Vision"
```

---

### Task 3: Scritture su capi, wishlist e categorie

**Files:**
- Modify: `ios/StyleVaultNative/Data/Models.swift`, `Data/StoreFactory.swift` (schema)
- Create: `ios/StyleVaultNative/Data/ItemValues.swift`, `WardrobeStore.swift`, `CustomCategoryStore.swift`, `ios/StyleVaultNative/Wardrobe/CategoryChoice.swift`
- Test: `ios/StyleVaultNativeTests/WardrobeStoreTests.swift`, `CustomCategoryStoreTests.swift`

**Interfaces:**
- Produces:

```swift
@Model final class CustomCategory {
    var id: String = ""        // "custom_<uuid>", finisce in Item.category
    var name: String = ""
    var createdAt: Date = Date.now
    init() {}
}
struct ItemValues: Equatable {
    var name = "", category = ""
    var subcategory: String?, brand: String?, size: String?
    var colors: [String] = []
    var season = "all", occasion = "casual"
    var warmthLevel = 2
    var sourceURL: String?, price: Double?
    var photoFront: Data?, photoBack: Data?
}
@MainActor enum WardrobeStore {
    @discardableResult static func addItem(_ values: ItemValues, in context: ModelContext) throws -> Item
    @discardableResult static func addWish(_ values: ItemValues, in context: ModelContext) throws -> WishlistItem
    /// true se la foto davanti è cambiata: lo scontorno è stato azzerato e va rifatto.
    @discardableResult static func update(_ item: Item, with values: ItemValues, in context: ModelContext) throws -> Bool
    static func delete(_ item: Item, in context: ModelContext) throws
    static func delete(_ wish: WishlistItem, in context: ModelContext) throws
    static func toggleFavorite(_ item: Item, in context: ModelContext) throws
    @discardableResult static func moveToWardrobe(_ wish: WishlistItem, in context: ModelContext) throws -> Item
}
@MainActor enum CustomCategoryStore {
    /// Nome vuoto: nil. Nome già presente, anche con altre maiuscole: quella che c'è.
    @discardableResult static func add(name: String, in context: ModelContext) throws -> CustomCategory?
    static func isUsed(_ category: CustomCategory, in context: ModelContext) throws -> Bool
    /// Non cancella se un capo o un desiderio la usa: ritorna false.
    @discardableResult static func delete(_ category: CustomCategory, in context: ModelContext) throws -> Bool
}
struct CategoryChoice: Identifiable, Equatable {
    let id: String
    let title: Title           // .catalog(labelKey) oppure .custom(name)
    static func all(custom: [CustomCategory]) -> [CategoryChoice]
    static func find(_ id: String, custom: [CustomCategory]) -> CategoryChoice?
}
```

- [ ] **Step 1: Scrivere i test**

Stesso impianto di `ProfileStoreTests`: il `ModelContainer` tenuto in una proprietà, `StoreFactory.build(.memory)`.

```swift
func testAggiuntaConservaTuttiICampi() throws { /* ogni campo di ItemValues torna uguale, favorite false */ }
func testLaFotoCambiataAzzeraLoScontorno() throws {
    let c = try context()
    let item = try WardrobeStore.addItem(values(photo: Data([1])), in: c)
    item.cutout = Data([9])
    XCTAssertTrue(try WardrobeStore.update(item, with: values(photo: Data([2])), in: c))
    XCTAssertNil(item.cutout)
}
func testStessaFotoTieneLoScontorno() throws {
    let c = try context()
    let item = try WardrobeStore.addItem(values(photo: Data([1])), in: c)
    item.cutout = Data([9])
    XCTAssertFalse(try WardrobeStore.update(item, with: values(photo: Data([1]), name: "Nuovo"), in: c))
    XCTAssertEqual(item.cutout, Data([9]))
    XCTAssertEqual(item.name, "Nuovo")
}
func testPreferito() throws { /* due toggle tornano a false; il valore resta dopo context.save */ }
func testUnaModificaNonToccaPreferitoEData() throws { /* favorite e createdAt invariati */ }
func testCompratoPortaTuttoNelGuardaroba() throws {
    let c = try context()
    let wish = try WardrobeStore.addWish(values(photo: Data([1]), back: Data([2])), in: c)
    let item = try WardrobeStore.moveToWardrobe(wish, in: c)
    XCTAssertEqual(item.photoFront, Data([1])); XCTAssertEqual(item.photoBack, Data([2]))
    XCTAssertFalse(item.favorite)
    XCTAssertNotEqual(item.id, wish.id)
    XCTAssertEqual(try c.fetchCount(FetchDescriptor<WishlistItem>()), 0)
    XCTAssertEqual(try c.fetchCount(FetchDescriptor<Item>()), 1)
}
```

`CustomCategoryStoreTests`:

```swift
func testNomeVuotoNonCreaNulla() { /* "   " → nil, 0 record */ }
func testNomeDoppioRendeQuellaCheCe() { /* "Sport" e " sport " → stesso id, 1 record */ }
func testLIdInizaConCustom() { /* hasPrefix("custom_") */ }
func testNonSiCancellaSeUsata() { /* capo con category == id: delete false, record presente */ }
func testNonSiCancellaSeUsataDaUnDesiderio() { /* idem con WishlistItem */ }
func testSiCancellaSeLibera() { /* delete true */ }
func testCategoriaSconosciutaNonSiTrova() {
    XCTAssertNil(CategoryChoice.find("custom_sparita", custom: []))
    XCTAssertEqual(CategoryChoice.find("tops", custom: [])?.id, "tops")
}
func testPrimaIlCatalogoPoiLePersonalizzate() { /* all(custom:) ha 7 voci di Catalog, poi le custom per createdAt */ }
```

- [ ] **Step 2: Lanciarli**

Run: il comando nativo con `-only-testing:StyleVaultNativeTests/WardrobeStoreTests -only-testing:StyleVaultNativeTests/CustomCategoryStoreTests`
Expected: FAIL in compilazione.

- [ ] **Step 3: Implementare**

Aggiungere `CustomCategory.self` allo schema di `StoreFactory`. Tutte le funzioni salvano prima di tornare. `moveToWardrobe` copia, inserisce e cancella nello stesso salvataggio, così un errore non perde il desiderio. Il confronto del nome usa `trimmingCharacters` e `caseInsensitiveCompare`.

- [ ] **Step 4: Rilanciarli**

Expected: verdi. Lanciare anche `ModelsTests` e `StoreFactoryTests`.

- [ ] **Step 5: Commit**

```bash
git add ios/StyleVaultNative ios/StyleVaultNativeTests
git commit -m "feat(nativa): scritture su capi, wishlist e categorie personalizzate"
```

---

### Task 4: Scontorno dopo il salvataggio

**Files:**
- Create: `ios/StyleVaultNative/Data/CutoutWorker.swift`
- Modify: `ios/StyleVaultNative/App/StyleVaultNativeApp.swift`
- Test: `ios/StyleVaultNativeTests/CutoutWorkerTests.swift`

**Interfaces:**
- Consumes: `GarmentImage.cutout`, modello `Item`.
- Produces:

```swift
@MainActor @Observable final class CutoutWorker {
    init(context: ModelContext, cut: @escaping @Sendable (Data) async -> Data? = { await GarmentImage.cutout($0) })
    func enqueue(_ itemID: UUID)
    func waitUntilIdle() async
}
```

Si inietta nelle viste con `.environment(cutoutWorker)`.

- [ ] **Step 1: Scrivere i test**

```swift
func testScriveLoScontornoSulCapo() async throws { /* cut → Data([7]); dopo waitUntilIdle item.cutout == Data([7]) e il context è salvato */ }
func testRisultatoInRitardoNonFiniscePiuSullaFotoNuova() async throws {
    // cut sospeso; intanto item.photoFront cambia; poi cut torna
    // → item.cutout resta nil
}
func testCapoCancellatoMentreSiScontorna() async throws { /* niente crash, nessun record nuovo */ }
func testCapoSenzaFotoNonChiamaCut() async throws { /* contatore a 0 */ }
func testUnoAllaVolta() async throws { /* tre enqueue: massimo 1 cut in contemporanea */ }
func testScontornoFallitoLasciaIlCapoIntatto() async throws { /* cut → nil, cutout nil, nessun errore */ }
func testStessoCapoAccodatoDueVolteUnaSolaVolta() async throws { /* contatore a 1 finché è in coda */ }
```

Il `cut` finto è un `actor` con contatori e una continuazione per tenerlo sospeso.

- [ ] **Step 2: Lanciarli**

Run: `-only-testing:StyleVaultNativeTests/CutoutWorkerTests`
Expected: FAIL in compilazione.

- [ ] **Step 3: Implementare**

Coda di `UUID` e un solo `Task` che la svuota. Per ogni id: rilegge il capo con `#Predicate`, salta se non c'è o se non ha foto, chiama `cut`, rilegge il capo, scrive solo se `photoFront` è ancora quello di partenza, salva. Errori di salvataggio nel `Logger` con categoria `cutout`.

In `StyleVaultNativeApp`: `@State private var cutoutWorker`, creato in `init` con `container.mainContext`, passato con `.environment(cutoutWorker)`.

- [ ] **Step 4: Rilanciarli**

Expected: verdi.

- [ ] **Step 5: Commit**

```bash
git add ios/StyleVaultNative ios/StyleVaultNativeTests
git commit -m "feat(nativa): lo scontorno arriva dopo il salvataggio, uno alla volta"
```

---

### Task 5: Testi e permesso della fotocamera

**Files:**
- Modify: `tools/nativa/export-strings.mjs`, `tools/nativa/strings-native.json`, `ios/project.yml`, `ios/StyleVaultNativeTests/LocalizationTests.swift`
- Generated: `ios/StyleVaultNative/Resources/Localizable.xcstrings`, `InfoPlist.xcstrings`

**Interfaces:**
- Produces: le chiavi usate dalle viste dei Task 6-9.

Dal sito:

- `wardrobe`: `title`, `emptyState`, `emptyAction`, `deleteConfirm`, `searchPlaceholder`, `tabWardrobe`, `tabWishlist`
- `wishlist`: `title`, `subtitle`, `bought`, `emptyState`, `emptyAction`, `moveToWardrobe`, `openLink`
- `addItem`: `title`, `photo`, `link`, `uploadPhoto`, `takePhoto`, `pasteLink`, `analyzeLink`, `itemName`, `category`, `subcategory`, `brand`, `size`, `colors`, `season`, `occasion`, `warmth`, `photoHint`, `changePhoto`, `price`, `destination`, `toWardrobe`, `toWishlist`, `linkLoading`, `linkError`, `linkSuccess`, `nameRequired`, `categoryRequired`, `photoBack`, `photoBackHint`, `photoBackAdd`, `photoBackRemove`, `warmthLevels.1` ... `warmthLevels.5`
- `itemDetail`: `title`, `openShop`, `deleteItem`
- `common`: `save`, `cancel`, `delete`, `edit`, `close`, `all`, `favorites`, `noResults`, `optional`

Native, in `strings-native.json`:

| Chiave | Italiano | Inglese |
|---|---|---|
| `native.wardrobe.count %lld` | `%lld capo` / `%lld capi` | `%lld item` / `%lld items` |
| `native.form.priceInvalid` | Scrivi il prezzo in numeri | Enter the price as a number |
| `native.form.photoError` | Non riesco a leggere questa foto | This photo could not be read |
| `native.form.discard.title` | Scartare le modifiche? | Discard your changes? |
| `native.form.discard.confirm` | Scarta | Discard |
| `native.form.discard.keep` | Continua a modificare | Keep editing |
| `native.category.new` | Nuova categoria | New category |
| `native.category.name` | Nome della categoria | Category name |
| `native.category.delete` | Elimina categoria | Delete category |
| `native.category.inUse` | Prima sposta i capi in un'altra categoria | Move the items to another category first |
| `native.detail.photoBack` | Retro | Back |
| `native.detail.cutout` | Scontorno | Cutout |

- [ ] **Step 1: Scrivere il test**

In `LocalizationTests` aggiungere alle chiavi di `testOgniEtichettaHaItalianoEInglese` tutte quelle sopra senza plurale, compresi i cinque `addItem.warmthLevels.N`, poi:

```swift
func testIlContoDeiCapiHaIlPlurale() throws {
    let path = try XCTUnwrap(Bundle.main.path(forResource: "it", ofType: "lproj"))
    let bundle = try XCTUnwrap(Bundle(path: path))
    let format = bundle.localizedString(forKey: "native.wardrobe.count %lld", value: nil, table: nil)
    XCTAssertEqual(String.localizedStringWithFormat(format, 1), "1 capo")
    XCTAssertEqual(String.localizedStringWithFormat(format, 3), "3 capi")
}
func testLaFotocameraHaIlMotivoNelleDueLingue() throws {
    for language in ["it", "en"] {
        let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"))
        let bundle = try XCTUnwrap(Bundle(path: path))
        XCTAssertNotEqual(bundle.localizedString(forKey: "NSCameraUsageDescription", value: nil, table: "InfoPlist"),
                          "NSCameraUsageDescription", language)
    }
}
```

- [ ] **Step 2: Lanciarlo**

Run: `-only-testing:StyleVaultNativeTests/LocalizationTests`
Expected: FAIL sulle chiavi mancanti.

- [ ] **Step 3: Implementare**

- `export-strings.mjs`: elenco esplicito per i gruppi sopra, con percorso a punti (`addItem.warmthLevels.1`). Un valore `{ "it": {"one": ..., "other": ...}, "en": {...} }` in `strings-native.json` diventa una variazione `plural` del catalogo.
- `InfoPlist.xcstrings`: `NSCameraUsageDescription`, it "Per fotografare i tuoi capi.", en "To take photos of your clothes.".
- `project.yml`, target `StyleVaultNative`: `NSCameraUsageDescription: Per fotografare i tuoi capi.`

Run: `node tools/nativa/export-strings.mjs`
Expected: scrive i cataloghi senza errori.

- [ ] **Step 4: Rilanciarlo**

Expected: verde.

- [ ] **Step 5: Commit**

```bash
git add tools/nativa ios/project.yml ios/StyleVaultNative/Resources ios/StyleVaultNativeTests
git commit -m "feat(nativa): testi del guardaroba e permesso della fotocamera"
```

---

### Task 6: Modulo di aggiunta e modifica

**Files:**
- Create: `ios/StyleVaultNative/Wardrobe/ItemFormModel.swift`, `ItemFormView.swift`, `CameraPicker.swift`, `CategoryChips.swift`, `ItemPhotoView.swift`
- Modify: `ios/StyleVaultNative/App/TabRouter.swift`, `App/RootTabView.swift`
- Test: `ios/StyleVaultNativeTests/ItemFormModelTests.swift`, `TabRouterTests.swift`, `ios/StyleVaultNativeUITests/WardrobeFlowTests.swift`

**Interfaces:**
- Consumes: `ItemValues`, `WardrobeStore`, `CutoutWorker`, `CategoryChoice`, `GarmentImage.prepared`, `ItemText.parsePrice`, `LinkText.httpURL`.
- Produces:

```swift
enum AddDestination: Hashable { case wardrobe, wishlist }
// TabRouter
var addDestination: AddDestination = .wardrobe
mutating func openAdd(to destination: AddDestination)   // select(.add) apre verso .wardrobe

enum ItemFormMode { case add(AddDestination), edit(Item) }
enum FormField: Hashable { case name, category, price }

@MainActor @Observable final class ItemFormModel {
    init(mode: ItemFormMode, prepare: @escaping @Sendable (Data) async -> Data? = { GarmentImage.prepared($0) })
    var name, category, brand, size, priceText, linkText: String
    var subcategory: String?
    var colors: [String]
    var season, occasion: String
    var warmthLevel: Int
    var destination: AddDestination
    var showsLink: Bool                     // selettore Foto/Link
    private(set) var photoFront, photoBack: Data?
    private(set) var isProcessingPhoto: Bool
    private(set) var photoFailed: Bool
    private(set) var errors: Set<FormField>
    var isEditing: Bool { get }
    var isDirty: Bool { get }
    var canSave: Bool { get }               // false mentre si elabora una foto
    func selectCategory(_ id: String)       // azzera la sottocategoria
    func toggleColor(_ id: String)
    func setFront(_ raw: Data) async
    func setBack(_ raw: Data) async
    func removeBack()
    func validatedValues() -> ItemValues?   // aggiorna errors
}

struct ItemFormView: View { init(mode: ItemFormMode) }
struct ItemPhotoView: View { init(data: Data?, name: String, maxSide: Int = GarmentImage.thumbnailMaxSide) }
struct FlowLayout: Layout { var spacing: CGFloat }
```

Identificatori di accessibilità: `add-sheet` (contenitore, deve restare negli `otherElements`), `item-name`, `item-price`, `item-save`, `item-close`, `category-<id>`, `destination-wardrobe`, `destination-wishlist`, `mode-photo`, `mode-link`.

- [ ] **Step 1: Scrivere i test del modello**

```swift
func testSenzaNomeECategoriaNonSalva() {
    let m = ItemFormModel(mode: .add(.wardrobe))
    XCTAssertNil(m.validatedValues())
    XCTAssertEqual(m.errors, [.name, .category])
}
func testValoriPuliti() {
    let m = filled(); m.name = "  Giacca "; m.brand = "  "; m.priceText = "12,5"; m.linkText = " https://zara.com/p "
    let v = m.validatedValues()
    XCTAssertEqual(v?.name, "Giacca"); XCTAssertNil(v?.brand)
    XCTAssertEqual(v?.price, 12.5); XCTAssertEqual(v?.sourceURL, "https://zara.com/p")
}
func testPrezzoSbagliatoFerma() { /* "abc" → nil, errors [.price] */ }
func testLinkNonValidoNonSiSalvaMaNonFerma() { /* "boh" → values con sourceURL nil */ }
func testCambiareCategoriaAzzeraLaSottocategoria() { }
func testLeModificheParteDalCapo() { /* edit: tutti i campi precompilati, isDirty false, linkText e showsLink true se c'è sourceURL */ }
func testVuotoNonESporco() { XCTAssertFalse(ItemFormModel(mode: .add(.wardrobe)).isDirty) }
func testBastaUnCampoPerEssereSporco() { /* name = "x" → true */ }
func testDueFotoInFrettaVinceLUltima() async {
    // prepare finto: la prima richiesta resta sospesa, la seconda torna subito;
    // alla fine photoFront è la seconda e isProcessingPhoto false
}
func testMentreSiElaboraNonSiSalva() async { /* prepare sospeso: canSave false; dopo: true */ }
func testFotoIllegibile() async { /* prepare nil: photoFailed true, photoFront invariata, canSave true */ }
```

- [ ] **Step 2: Scrivere i test del router e i test UI**

In `TabRouterTests`: `openAdd(to: .wishlist)` apre il foglio con destinazione wishlist; `select(.add)` dopo torna a `.wardrobe`; la tab selezionata non cambia.

`WardrobeFlowTests`, con gli stessi aiutanti di `ProfileFlowTests` portati in un file comune `ios/StyleVaultNativeUITests/UITestHelpers.swift`:

```swift
func testFoglioVuotoSiChiudeSenzaDomande() { /* Aggiungi, item-close, foglio sparito */ }
func testBozzaChiedeConferma() {
    // Aggiungi, scrive il nome, item-close → compare "Scarta"; "Continua a modificare" lascia il foglio con il testo;
    // item-close, "Scarta" → foglio sparito
}
func testErroriInItaliano() { /* item-save a vuoto: "Dai un nome al capo" e "Scegli una categoria" visibili, foglio aperto */ }
```

- [ ] **Step 3: Lanciarli**

Expected: FAIL in compilazione.

- [ ] **Step 4: Implementare il modello e il router**

Per le foto: una coppia di contatori, uno per lato. Ogni `setFront` incrementa il suo, chiama `prepare` e scrive solo se il contatore è ancora quello. `isProcessingPhoto` è vero finché una richiesta dell'ultimo giro è aperta.

- [ ] **Step 5: Implementare le viste**

`ItemFormView`, nell'ordine di `AddItemPage.jsx`: selettore Foto/Link, sorgente, retro, nome, categoria, sottocategoria, colori, stagione, occasione, calore, brand e taglia, prezzo, destinazione (solo in aggiunta), Salva.

- In questo task il ramo Link mostra solo il campo; il tasto Analizza arriva col Task 7.
- Foto: `Menu` con `addItem.uploadPhoto` (`PhotosPicker`, `.images`) e `addItem.takePhoto` (`CameraPicker`, solo se `UIImagePickerController.isSourceTypeAvailable(.camera)`).
- Sottocategorie solo per le categorie del catalogo.
- Colori: cerchi `Color(hex:)` dal catalogo, bordo `Palette.border` per i chiari, `accessibilityLabel` col nome del colore e tratto `.isSelected`.
- Calore: 5 cerchi, etichetta `addItem.warmthLevels.N`.
- Toolbar: `common.close` a sinistra e titolo. `.interactiveDismissDisabled(model.isDirty)`. Con bozza, Chiudi apre un `confirmationDialog` con `native.form.discard.*`. Un trascinamento bloccato non chiede nulla, resta aperto.
- Salva: `validatedValues()`, poi `WardrobeStore.addItem`, `addWish` o `update`, e se serve `cutoutWorker.enqueue`. Errore di salvataggio: nel `Logger`, il foglio resta aperto.

`ItemPhotoView`: foto da `NSCache<NSData, UIImage>` (limite 200), decodifica in `Task.detached` con `GarmentImage.thumbnail`, dentro `.task(id: data)`. Senza dati: fondo `Palette.surface` e `ItemText.placeholderInitial` in `Font.display`.

`RootTabView`: `.sheet` con `ItemFormView(mode: .add(router.addDestination))`.

- [ ] **Step 6: Rilanciare i test**

Expected: verdi, compresi `testCinqueTabEFoglioAggiungi` e `testIlBloccoCopreIlFoglioAggiungi`.

- [ ] **Step 7: Commit**

```bash
git add ios
git commit -m "feat(nativa): modulo di aggiunta e modifica dei capi"
```

---

### Task 7: Aggiunta da link

**Files:**
- Create: `ios/StyleVaultNative/Wardrobe/LinkReader.swift`
- Modify: `ItemFormModel.swift`, `ItemFormView.swift`, `App/StyleVaultNativeApp.swift`
- Test: `ios/StyleVaultNativeTests/LinkFormTests.swift`, `WardrobeFlowTests.swift`

**Interfaces:**
- Consumes: `LinkText`, `GarmentImage.prepared`.
- Produces:

```swift
struct LinkPreview: Equatable, Sendable { var title: String; var site: String; var imageData: Data? }
enum LinkReadError: Error { case unreadable }
@MainActor protocol LinkReading { func read(_ url: URL) async throws -> LinkPreview }
@MainActor struct SystemLinkReader: LinkReading {}
#if DEBUG
@MainActor struct FakeLinkReader: LinkReading {}   // titolo "Camicia in lino", sito "Zara", nessuna immagine
#endif

enum LinkState: Equatable { case idle, loading, success, failure }
// ItemFormModel
private(set) var linkState: LinkState
func analyzeLink(with reader: LinkReading) async
```

Il lettore arriva alle viste con una voce d'ambiente `\.linkReader`, che vale `SystemLinkReader()` e diventa `FakeLinkReader()` con `-SVFakeLink` in Debug.

- [ ] **Step 1: Scrivere i test**

```swift
func testRiempieSoloICampiVuoti() async {
    let m = filled(); m.name = "Mio"; m.linkText = "https://zara.com/p"
    await m.analyzeLink(with: Stub(.init(title: "Camicia", site: "Zara", imageData: nil)))
    XCTAssertEqual(m.name, "Mio"); XCTAssertEqual(m.brand, "Zara"); XCTAssertEqual(m.linkState, .success)
}
func testUsaLaFotoSoloSeNonCeGia() async { /* foto presente: resta; assente: prepare viene applicato */ }
func testLinkIlleggibileTieneIlLink() async {
    let m = filled(); m.linkText = "https://blindato.com/p"
    await m.analyzeLink(with: Stub(error: LinkReadError.unreadable))
    XCTAssertEqual(m.linkState, .failure)
    XCTAssertEqual(m.validatedValues()?.sourceURL, "https://blindato.com/p")
}
func testLinkNonValidoNonChiamaIlLettore() async { /* contatore 0, stato idle */ }
func testLinkCambiatoMentreLeggeNonSovrascrive() async { /* risposta in ritardo per il vecchio link: campi invariati */ }
```

Per `SystemLinkReader`, una funzione pura `static func preview(title: String?, host: String, imageData: Data?) throws -> LinkPreview`:

```swift
func testPaginaBloccataEIlleggibile() {
    XCTAssertThrowsError(try SystemLinkReader.preview(title: "Access Denied", host: "www2.hm.com", imageData: nil))
}
func testSenzaTitoloESenzaFotoEIlleggibile() { /* title nil, imageData nil → throw */ }
func testSoloFotoVaBene() { /* title nil, imageData presente → title vuoto, site "Zara" */ }
func testTitoloPulito() { /* "Camicia - Zara", "www.zara.com" → "Camicia", "Zara" */ }
```

Test UI, con `-SVFakeLink`:

```swift
func testDaLinkRiempieIlModulo() {
    // Aggiungi, mode-link, scrive https://zara.com/p, Analizza
    // → item-name vale "Camicia in lino", compare "Dati estratti: controlla e completa"
}
```

- [ ] **Step 2: Lanciarli**

Expected: FAIL in compilazione.

- [ ] **Step 3: Implementare**

`SystemLinkReader.read`: `LPMetadataProvider` nuovo a ogni lettura, `timeout = 15`, `startFetchingMetadata(for:)` sul main actor. Immagine da `imageProvider` con `loadDataRepresentation` di `UTType.image`, in una continuazione. **Mai `iconProvider`:** un logo come foto del capo è peggio di nessuna foto. Qualunque errore del provider diventa `.unreadable`.

Nel modulo: campo, tasto `addItem.analyzeLink` attivo solo con URL valido, testi `linkLoading`, `linkSuccess`, `linkError`, anteprima della foto e `addItem.changePhoto`, perché con un link illeggibile la foto si mette a mano.

- [ ] **Step 4: Rilanciarli**

Expected: verdi.

- [ ] **Step 5: Commit**

```bash
git add ios
git commit -m "feat(nativa): aggiunta da link con LinkPresentation"
```

---

### Task 8: Lista del guardaroba e dettaglio

**Files:**
- Create: `ios/StyleVaultNative/Wardrobe/WardrobeView.swift`, `ItemCard.swift`, `ItemDetailView.swift`
- Modify: `App/RootTabView.swift`, `Wardrobe/CategoryChips.swift`
- Test: `ios/StyleVaultNativeUITests/WardrobeFlowTests.swift`

**Interfaces:**
- Consumes: `WardrobeFilter`, `WardrobeStore`, `CategoryChoice`, `ItemPhotoView`, `ItemFormView`.
- Produces:

```swift
enum WardrobeSection: Hashable { case wardrobe, wishlist }
struct WardrobeView: View { init(onAdd: @escaping (AddDestination) -> Void) }
struct ItemDetailView: View { init(item: Item) }
struct CategoryChips: View {
    init(selection: Binding<String?>, choices: [CategoryChoice], onDelete: ((CategoryChoice) -> Void)? = nil)
}
```

Identificatori: `wardrobe-search`, `wardrobe-favorites`, `wardrobe-section-wardrobe`, `wardrobe-section-wishlist`, `item-card`, `item-card-favorite`, `detail-favorite`, `detail-edit`, `detail-delete`.

- [ ] **Step 1: Scrivere i test UI**

Aiutante `addItem(app, name:, category:)`, che passa dal modulo: l'archivio in memoria parte vuoto.

```swift
func testGiroCompleto() {
    // vuoto: compare "Il tuo guardaroba è vuoto" e il tasto apre il modulo
    // aggiunge "Giacca blu" in Giacche: la card compare, "1 capo"
    // la apre: dettaglio con nome e categoria
    // modifica il nome in "Giacca nera": il dettaglio si aggiorna
    // elimina, conferma: torna alla lista vuota
}
func testFiltriERicerca() {
    // due capi in categorie diverse
    // tocca una categoria: una card sola; "Tutti": due
    // cerca il nome dell'altro: una card; un testo a caso: "Nessun risultato"
}
func testPreferiti() {
    // cuore su un capo, filtro preferiti: resta quello
}
```

- [ ] **Step 2: Lanciarli**

Expected: FAIL, le schermate non esistono.

- [ ] **Step 3: Implementare**

`WardrobeView`, come `WardrobePage.jsx`:

- `NavigationStack`, titolo `Font.display` `wardrobe.title` oppure `wishlist.title`, sottotitolo col conto.
- `@Query(sort: \Item.createdAt)`, dal più vecchio, come il sito.
- Griglia `LazyVGrid` con `GridItem(.adaptive(minimum: 150))`, così l'iPad ne mostra di più.
- Vuoto: `wardrobe.emptyState` e `wardrobe.emptyAction` con `onAdd(.wardrobe)`; con filtri attivi `common.noResults`.
- Nel chip delle categorie un capo con categoria sconosciuta resta in "Tutti" e non produce un chip.

`ItemCard`: `ItemPhotoView` in proporzione 3:4, cuore in alto a destra, nome, brand, pallini dei colori. Il cuore usa `WardrobeStore.toggleFavorite` e non apre il dettaglio.

`ItemDetailView`:

- Foto in `TabView` a pagine con quelle presenti: davanti, `native.detail.photoBack`, `native.detail.cutout`. Scontorno su `Palette.surface`.
- Sotto: cuore, nome, brand, colori, fatti come `ItemDetailPage.jsx`. Categoria sconosciuta: la riga non c'è. Prezzo con `formatted(.currency(code: "EUR"))`.
- `itemDetail.openShop` con `Link`, se il capo ha un URL valido.
- `common.edit` apre `ItemFormView(mode: .edit(item))` in un foglio; `itemDetail.deleteItem` con conferma `wardrobe.deleteConfirm`.
- Su iPad (`horizontalSizeClass == .regular`) foto e dati stanno affiancati, come il layout del sito.
- Se il capo sparisce mentre è aperto, perché cancellato da un altro dispositivo, la vista esce: controllare `item.isDeleted` o `modelContext` nullo in `.onChange`, e non leggere campi di un modello cancellato.

In `RootTabView`, la tab Guardaroba diventa `WardrobeView { router.openAdd(to: $0) }`.

- [ ] **Step 4: Rilanciarli**

Expected: verdi su iPhone. Poi guardare griglia e dettaglio con `mcp__Claude_Code_iOS_Simulator__control`, chiaro e scuro, in italiano e in inglese.

- [ ] **Step 5: Commit**

```bash
git add ios
git commit -m "feat(nativa): lista del guardaroba, filtri e dettaglio del capo"
```

---

### Task 9: Wishlist e categorie personalizzate

**Files:**
- Create: `ios/StyleVaultNative/Wardrobe/WishlistSection.swift`
- Modify: `WardrobeView.swift`, `ItemFormView.swift`, `CategoryChips.swift`
- Test: `ios/StyleVaultNativeUITests/WardrobeFlowTests.swift`

**Interfaces:**
- Consumes: `WardrobeStore.moveToWardrobe`, `delete(_: WishlistItem…)`, `CustomCategoryStore`, `CutoutWorker.enqueue`.
- Produces: `struct WishlistSection: View { init(onAdd: @escaping () -> Void) }`.

Identificatori: `wish-card`, `wish-bought`, `wish-delete`, `category-new`, `category-new-name`.

- [ ] **Step 1: Scrivere i test UI**

```swift
func testDesiderioComprato() {
    // sezione Wishlist vuota: il tasto apre il modulo con destinazione Wishlist già scelta
    // salva: la card compare nella wishlist, non nel guardaroba
    // "Comprato!": la wishlist è vuota, il guardaroba ha il capo
}
func testCancellaUnDesiderio() { }
func testNuovaCategoria() {
    // nel modulo, "Nuova categoria", scrive "Mare", conferma: il chip è selezionato e il capo si salva
    // nei filtri c'è "Mare"; filtrando resta quel capo
    // il dettaglio mostra "Mare"
}
func testCategoriaUsataNonSiCancella() {
    // tiene premuto "Mare": "Elimina categoria" mostra "Prima sposta i capi in un'altra categoria", il chip resta
    // cancella il capo, ripete: il chip sparisce
}
```

- [ ] **Step 2: Lanciarli**

Expected: FAIL.

- [ ] **Step 3: Implementare**

`WishlistSection`, come il ramo wishlist di `WardrobePage.jsx`: griglia di `ItemCard` senza cuore, con sotto `Link` al negozio se c'è, `wishlist.bought` e cancella. `ItemCard` lavora su valori semplici (nome, brand, colori, foto, preferito opzionale), così vale per `Item` e `WishlistItem`.

`wishlist.bought`: `moveToWardrobe`, poi `cutoutWorker.enqueue` col nuovo id.

Nel modulo, dopo i chip di categoria: chip `native.category.new` che apre un `alert` con `TextField`. Con nome valido seleziona la categoria creata. Il nome vuoto non fa nulla.

Nei filtri `CategoryChips` riceve `onDelete` solo per le personalizzate: `contextMenu` con `native.category.delete`. Se `isUsed`, mostra un `alert` con `native.category.inUse`. Se il filtro attivo era quella, torna a Tutti.

- [ ] **Step 4: Rilanciare tutta la suite**

Run: il comando nativo completo, poi lo stesso con l'iPad `B04B93AB-…` se è libero, poi `swift test`.
Expected: tutto verde. Controllare prima con `xcrun simctl list devices booted` che l'iPad non sia in uso.

- [ ] **Step 5: Commit**

```bash
git add ios
git commit -m "feat(nativa): wishlist e categorie personalizzate"
```

---

### Task 10: Prova su iPhone e iPad

Serve Lorenzo. Vision non gira nel simulatore, e fotocamera, sincronizzazione delle foto e link veri si vedono solo sui dispositivi.

**Files:**
- Create: `docs/verifiche/2026-11-05-nativa-fase-2/prova-iphone-ipad.md`
- Modify: `MEMORIA.md`

- [ ] **Step 1: Installare su iPhone e iPad**

```bash
cd ios && xcodegen generate
xcodebuild -project StyleVault.xcodeproj -scheme StyleVaultNative -destination 'id=00008160-000661061A200036' -derivedDataPath build/dd-device -allowProvisioningUpdates build
xcrun devicectl device install app --device 00008160-000661061A200036 build/dd-device/Build/Products/Debug-iphoneos/StyleVaultNative.app
```

Ripetere con l'iPad `00008132-000160A61EB9001C`, poi aprire l'app con `xcrun devicectl device process launch`.

- [ ] **Step 2: Far provare a Lorenzo**

1. Sull'iPhone: capo da fotocamera, con retro. Nel dettaglio si sfoglia fino allo scontorno.
2. Capo dalla libreria, con una foto HEIC.
3. Paio di scarpe: lo scontorno tiene tutte e due.
4. Capo da link Zalando, poi da un link H&M: se il negozio blocca, resta il link e l'avviso.
5. Dopo qualche minuto, sull'iPad: stessi capi con foto, retro e scontorno.
6. Dall'iPad: preferito e modifica di un capo; tornano sull'iPhone.
7. Wishlist: aggiunta e "Comprato!".
8. Categoria nuova sull'iPad: compare nel modulo dell'iPhone.
9. Bozza con il blocco Face ID attivo: si esce dall'app, si rientra, la bozza c'è ancora.
10. Griglia su iPad, in verticale e in orizzontale.

- [ ] **Step 3: Scrivere l'esito**

Stesso formato di `docs/verifiche/2026-11-05-nativa-fase-1/prova-iphone-ipad.md`: dispositivi, esito, test, decisioni, dettagli rimandati. Aggiornare `MEMORIA.md`.

```bash
git add docs MEMORIA.md
git commit -m "docs(nativa): esito della prova della fase 2"
```

---

## Per le fasi successive

- **Fase 3:** una categoria personalizzata non occupa nessuno slot dell'outfit. Decidere cosa fare di questi capi nell'algoritmo. Un capo cancellato lascia il suo id in `Outfit.itemIDs`.
- **Fase 4:** scheda di uso del capo nel dettaglio, come `ItemDetailPage.jsx`.
- **Fase 5:** `setArmocromia`, che aggiorna `updatedAt`.
- **Fase 6:** doppioni di `BodyPhoto`, da unire come il Profilo; tasto "Prova outfit"; scontorno calcolato al bisogno per i capi che non l'hanno.
- **Fase 7:** l'import deve portare anche le foto del retro. Le categorie personalizzate del sito non esistono su Supabase, quindi non c'è nulla da migrare.
