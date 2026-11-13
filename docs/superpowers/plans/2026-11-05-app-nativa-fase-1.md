# App nativa, fase 1: Fondamenta. Piano di implementazione

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** una nuova app SwiftUI, installata accanto all'ibrida, con dati SwiftData sincronizzati da CloudKit, cinque tab e il Profilo con tema, lingua e città; un dato cambiato sull'iPhone compare sull'iPad.

**Architecture:** un nuovo target `StyleVaultNative` in `ios/project.yml`, con sorgenti in `ios/StyleVaultNative/`, e un pacchetto Swift locale `ios/StyleVaultCore/` per la logica senza interfaccia, provato con `swift test` sul Mac. L'ibrida non cambia: i due target condividono solo `Palette.swift` e `ThemeStore.swift`.

**Tech Stack:** Swift, SwiftUI, SwiftData con CloudKit, XCTest, XcodeGen, Node per gli script di esportazione.

**Spec:** `docs/superpowers/specs/2026-11-04-app-nativa-icloud-design.md`, fase 1 e sezione "Correzioni dall'audit".

## Global Constraints

- Ramo: `feat/app-nativa`, creato da `feat/app-ios`. Prima di commit e prove, guardare `git log`, `git status` e `MEMORIA.md`: ci sono sessioni parallele.
- iOS 17, come oggi. `TARGETED_DEVICE_FAMILY "1,2"`.
- Container: `iCloud.it.faraoni.stylevault`. Team: `599MS2BZ63`, già in `ios/project.yml`.
- CloudKit: tutte le proprietà sono facoltative o hanno un valore di default, niente vincoli `unique`.
- Solo API Apple: nessuna dipendenza esterna nel target nuovo, niente Supabase.
- Niente login, nessuna funzione nascosta nella Release (regola 2.5.19). Gli argomenti di prova stanno dentro `#if DEBUG`.
- L'app non si blocca e non chiede di accedere a iCloud se iCloud manca o è pieno. Mostra solo l'avviso "sincronizzazione non attiva".
- Niente avatar realistico: nessun file di `ios/StyleVault/Realistic/` nel target nuovo.
- Italiano e inglese con String Catalog, lingua di origine italiana.
- Simulatori: sempre con device esplicito. iPhone 18 Pro `18361580-2FC8-4A18-AED3-7461008C6569`. Per l'iPad, iPad Pro 11" M5 `B04B93AB-9CE8-425C-B2B5-BC10A2BD0559`, solo se non è acceso da un'altra sessione. Non toccare `0ED66ECB` e `1C8ED7D7`.
- Mai eseguire due `xcodebuild` insieme: il Mac ha 16 GB ed è condiviso.
- Commit in italiano, con riga finale `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Commit locali sì, push solo con l'ok di Lorenzo.
- Dopo ogni task che chiude un passo significativo, aggiornare `MEMORIA.md`.

## Review Focus

1. Due dispositivi creano ognuno il proprio `Profile` prima di sincronizzarsi: alla fine ne resta uno, lo stesso su entrambi, senza perdere l'Armocromia. Test in Task 5.
2. iCloud assente, disattivato o pieno: l'app si apre, salva in locale e mostra l'avviso. Un errore di rete passeggero non mostra l'avviso. Test in Task 6.
3. Il contenitore cloud non si apre: l'app parte lo stesso, prima in locale e poi in memoria. Test in Task 4.
4. Telefono in inglese o in una terza lingua: nessuna etichetta mostra la chiave grezza, come `categories.tops`. Test in Task 7.
5. Ricerca città con accenti, spazi, una sola lettera, nessun risultato o rete assente: nessun blocco, URL codificato bene. Test in Task 2 e Task 8.

---

## Struttura dei file

```text
ios/StyleVaultCore/
  Package.swift
  Sources/StyleVaultCore/Catalog.swift        categorie, stagioni, occasioni, colori
  Sources/StyleVaultCore/CitySearch.swift     ricerca città, URL e risposta
  Tests/StyleVaultCoreTests/CatalogTests.swift
  Tests/StyleVaultCoreTests/CitySearchTests.swift
  Tests/StyleVaultCoreTests/Fixtures/catalog.json   generato dal sito
ios/StyleVaultNative/
  StyleVaultNative.entitlements
  App/StyleVaultNativeApp.swift               avvio e tema
  App/RootTabView.swift, TabRouter.swift      tab
  Data/Models.swift                           modelli SwiftData
  Data/StoreFactory.swift                     apertura del contenitore
  Data/ProfileStore.swift                     il record unico del Profilo
  Data/SyncMonitor.swift                      stato della sincronizzazione
  Profile/ProfileView.swift, CitySearchView.swift, CitySearchModel.swift
  Resources/Localizable.xcstrings, InfoPlist.xcstrings, Assets.xcassets
ios/StyleVaultNativeTests/                    test su simulatore
ios/StyleVaultNativeUITests/                  giro delle schermate
tools/nativa/
  export-core-fixtures.mjs                    catalog.json dal sito
  export-strings.mjs                          Localizable.xcstrings da it.json ed en.json
  strings-native.json                         testi nuovi, solo dell'app nativa
```

---

### Task 1: StyleVaultCore con il catalogo del guardaroba

**Files:**
- Create: `ios/StyleVaultCore/Package.swift`
- Create: `ios/StyleVaultCore/Sources/StyleVaultCore/Catalog.swift`
- Create: `ios/StyleVaultCore/Tests/StyleVaultCoreTests/CatalogTests.swift`
- Create: `tools/nativa/export-core-fixtures.mjs`
- Create: `ios/StyleVaultCore/Tests/StyleVaultCoreTests/Fixtures/catalog.json`, generato

**Interfaces:**
- Produces, in `StyleVaultCore`:
  - `struct Subcategory: Equatable, Sendable { id: String; labelKey: String }`
  - `struct WardrobeCategory: Identifiable, Equatable, Sendable { id: String; icon: String; labelKey: String; subcategories: [Subcategory] }`
  - `struct ChoiceOption: Identifiable, Equatable, Sendable { id: String; labelKey: String; icon: String }`
  - `struct ClothingColor: Identifiable, Equatable, Sendable { id: String; hex: String; labelKey: String }`
  - `enum Catalog { static let categories: [WardrobeCategory]; static let seasons: [ChoiceOption]; static let occasions: [ChoiceOption]; static let colors: [ClothingColor]; static func category(id: String) -> WardrobeCategory? }`

- [ ] **Step 1: Creare il ramo**

```bash
git switch -c feat/app-nativa feat/app-ios
```

- [ ] **Step 2: Scrivere l'esportazione dal sito**

`tools/nativa/export-core-fixtures.mjs` importa `CATEGORIES`, `SEASONS`, `OCCASIONS`, `CLOTHING_COLORS` da `src/utils/categories.js` e scrive `catalog.json` con `categories` come array nell'ordine di `Object.entries`, ognuna con `id`, `icon`, `labelKey`, `subcategories`, più `seasons`, `occasions`, `colors`.

Run: `node tools/nativa/export-core-fixtures.mjs`
Expected: il file esiste, con 7 categorie, 5 stagioni, 5 occasioni e 24 colori.

- [ ] **Step 3: Scrivere il pacchetto e il test che fallisce**

`Package.swift`: tools 5.9, `platforms: [.iOS(.v17), .macOS(.v14)]`, target di test con `resources: [.copy("Fixtures")]`.

```swift
func testCoincideColSito() throws {
    let site = try loadFixture()   // decodifica Fixtures/catalog.json da Bundle.module
    XCTAssertEqual(Catalog.categories, site.categories)
    XCTAssertEqual(Catalog.seasons, site.seasons)
    XCTAssertEqual(Catalog.occasions, site.occasions)
    XCTAssertEqual(Catalog.colors, site.colors)
}

func testCategoriaSconosciutaNonEsiste() {
    XCTAssertNil(Catalog.category(id: "boh"))
    XCTAssertEqual(Catalog.category(id: "shoes")?.icon, "👟")
}
```

Run: `cd ios/StyleVaultCore && swift test`
Expected: FAIL, `Catalog` non esiste.

- [ ] **Step 4: Scrivere `Catalog.swift`**

Dati copiati da `src/utils/categories.js`, stesso ordine. La chiave `subcategories.dressparts` di `dresspants` resta così: è quella che esiste in `it.json` ed `en.json`.

- [ ] **Step 5: Verificare**

Run: `cd ios/StyleVaultCore && swift test`
Expected: PASS, nessun errore.

- [ ] **Step 6: Commit**

```bash
git add ios/StyleVaultCore tools/nativa
git commit -m "feat(nativa): pacchetto StyleVaultCore con il catalogo del guardaroba"
```

---

### Task 2: Ricerca della città in StyleVaultCore

Stessa ricerca del sito, `searchCities` in `src/services/weather.js`. È la sola chiamata esterna della fase 1 e manda solo il testo cercato.

**Files:**
- Create: `ios/StyleVaultCore/Sources/StyleVaultCore/CitySearch.swift`
- Create: `ios/StyleVaultCore/Tests/StyleVaultCoreTests/CitySearchTests.swift`

**Interfaces:**
- Produces:
  - `struct City: Identifiable, Equatable, Sendable { id: Int; name: String; latitude: Double; longitude: Double; country: String?; region: String? }`
  - `enum CitySearch { static func url(query: String, language: String) -> URL?; static func parse(_ data: Data) throws -> [City]; static func search(_ query: String, language: String, session: URLSession = .shared) async throws -> [City]; static let minimumLength = 2 }`

- [ ] **Step 1: Scrivere i test che falliscono**

```swift
func testUrlComeIlSito() {
    XCTAssertEqual(CitySearch.url(query: "mila", language: "it")?.absoluteString,
        "https://geocoding-api.open-meteo.com/v1/search?name=mila&count=6&language=it&format=json")
}
func testAccentiESpaziCodificati() {
    let url = CitySearch.url(query: "São Paulo", language: "it")!.absoluteString
    XCTAssertTrue(url.contains("name=S%C3%A3o%20Paulo"), url)
    XCTAssertNotNil(CitySearch.url(query: "Forlì & Cesena?", language: "en"))
}
func testMappaLaRisposta() throws {
    let json = #"{"results":[{"id":1,"name":"Milano","latitude":45.46,"longitude":9.19,"country":"Italia","admin1":"Lombardia"}]}"#
    XCTAssertEqual(try CitySearch.parse(Data(json.utf8)),
        [City(id: 1, name: "Milano", latitude: 45.46, longitude: 9.19, country: "Italia", region: "Lombardia")])
}
func testNessunRisultatoEListaVuota() throws {
    XCTAssertEqual(try CitySearch.parse(Data("{}".utf8)), [])
}
func testPaeseERegioneSonoFacoltativi() throws {
    let json = #"{"results":[{"id":2,"name":"Atlantis","latitude":1,"longitude":2}]}"#
    XCTAssertNil(try CitySearch.parse(Data(json.utf8)).first?.country)
}
```

Run: `cd ios/StyleVaultCore && swift test`
Expected: FAIL, `CitySearch` non esiste.

- [ ] **Step 2: Scrivere `CitySearch.swift`**

`url` usa `URLComponents` con i parametri nell'ordine del test. `search` lancia un errore se lo stato HTTP non è 2xx.

- [ ] **Step 3: Verificare**

Run: `cd ios/StyleVaultCore && swift test`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add ios/StyleVaultCore
git commit -m "feat(nativa): ricerca della città nel pacchetto Core"
```

---

### Task 3: Target StyleVaultNative

**Files:**
- Modify: `ios/project.yml`
- Create: `ios/StyleVaultNative/StyleVaultNative.entitlements`, generato da XcodeGen
- Create: `ios/StyleVaultNative/App/StyleVaultNativeApp.swift`
- Create: `ios/StyleVaultNative/Resources/Assets.xcassets`
- Create: `ios/StyleVaultNativeTests/SmokeTests.swift`

**Interfaces:**
- Produces: target `StyleVaultNative`, schema `StyleVaultNative`, test `StyleVaultNativeTests`.

- [ ] **Step 1: Aggiungere il target a `ios/project.yml`**

- `options.developmentLanguage: it`.
- `packages.StyleVaultCore.path: StyleVaultCore`.
- Target `StyleVaultNative`, `type: application`, `platform: iOS`:
  - `sources`: `StyleVaultNative`, `StyleVault/Design/Palette.swift`, `StyleVault/App/ThemeStore.swift`;
  - dipendenza: `package: StyleVaultCore`;
  - `PRODUCT_BUNDLE_IDENTIFIER: it.faraoni.stylevault.nativa`;
  - `TARGETED_DEVICE_FAMILY: "1,2"`;
  - `SWIFT_EMIT_LOC_STRINGS: YES`;
  - entitlements:
    - `com.apple.developer.icloud-container-identifiers: [iCloud.it.faraoni.stylevault]`
    - `com.apple.developer.icloud-services: [CloudKit]`
    - `aps-environment: development`
  - info:
    - `CFBundleDisplayName: SV Nativa`
    - `CFBundleLocalizations: [it, en]`
    - `UILaunchScreen: {}`
    - `UIBackgroundModes: [remote-notification]`
    - `UISupportedInterfaceOrientations: [UIInterfaceOrientationPortrait]`
    - `UISupportedInterfaceOrientations~ipad`: tutte e quattro
    - `ITSAppUsesNonExemptEncryption: false`
- Target `StyleVaultNativeTests`, `type: bundle.unit-test`, dipendenza da `StyleVaultNative`, `GENERATE_INFOPLIST_FILE: YES`.
- Schema `StyleVaultNative`, build del target, test `StyleVaultNativeTests`.

- [ ] **Step 2: Scrivere il test che fallisce**

```swift
import StyleVaultCore
final class SmokeTests: XCTestCase {
    func testIlPacchettoCoreERaggiungibile() {
        XCTAssertEqual(Catalog.categories.count, 7)
    }
}
```

Run:
```bash
cd ios && xcodegen generate && xcodebuild test -project StyleVault.xcodeproj -scheme StyleVaultNative -destination 'platform=iOS Simulator,id=18361580-2FC8-4A18-AED3-7461008C6569' -derivedDataPath build/dd-native
```
Expected: FAIL, manca `@main`.

- [ ] **Step 3: Scrivere `StyleVaultNativeApp.swift`**

Un `@main App` con una schermata di solo testo "StyleVault". I task successivi la sostituiscono.

- [ ] **Step 4: Verificare**

Run: lo stesso comando dello Step 2.
Expected: `** TEST SUCCEEDED **`, 1 test.

- [ ] **Step 5: Verificare che l'ibrida compili ancora**

Run:
```bash
cd ios && xcodebuild build -project StyleVault.xcodeproj -scheme StyleVault -destination 'platform=iOS Simulator,id=18361580-2FC8-4A18-AED3-7461008C6569' -derivedDataPath build/dd-native
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add ios/project.yml ios/StyleVaultNative ios/StyleVaultNativeTests
git commit -m "feat(nativa): target StyleVaultNative accanto all'app ibrida"
```

---

### Task 4: Modelli SwiftData e apertura del contenitore

**Files:**
- Create: `ios/StyleVaultNative/Data/Models.swift`
- Create: `ios/StyleVaultNative/Data/StoreFactory.swift`
- Create: `ios/StyleVaultNativeTests/ModelsTests.swift`
- Create: `ios/StyleVaultNativeTests/StoreFactoryTests.swift`

**Interfaces:**
- Produces:
  - `@Model` `Item`, `Outfit`, `CalendarEntry`, `WishlistItem`, `Profile`, `BodyPhoto`
  - `enum StoreMode { case cloud, local, memory }`
  - `enum StoreHealth: Equatable { case cloud, localOnly, temporary }`
  - `struct OpenedStore { let container: ModelContainer; let health: StoreHealth }`
  - `enum StoreFactory { static let containerID = "iCloud.it.faraoni.stylevault"; static let schema: Schema; static func build(_ mode: StoreMode, url: URL? = nil) throws -> ModelContainer; static func open(preferred: StoreMode = .cloud, build: (StoreMode) throws -> ModelContainer = { try StoreFactory.build($0) }) -> OpenedStore }`

**Campi.** Ogni modello ha `id: UUID = UUID()`. Tutte le stringhe hanno default `""` se non è indicato altro.

| Modello | Campi |
|---|---|
| `Item` | `name`, `category`, `subcategory: String?`, `brand: String?`, `size: String?`, `colors: [String] = []`, `season = "all"`, `occasion = "casual"`, `warmthLevel = 2`, `sourceURL: String?`, `price: Double?`, `favorite = false`, `createdAt = Date.now`, e con `.externalStorage`: `photoFront`, `photoBack`, `cutout`, tutte `Data?` |
| `WishlistItem` | come `Item`, senza `favorite` e `cutout` |
| `Outfit` | `occasion: String?`, `score: Int?`, `itemIDs: [UUID] = []`, `createdAt = Date.now` |
| `CalendarEntry` | `day`, nel formato `yyyy-MM-dd`, `worn = true`, `outfitID: UUID?`, `itemIDs: [UUID] = []`, `createdAt = Date.now` |
| `Profile` | `theme = "system"`, `cityName = "Milano"`, `cityLatitude = 45.4642`, `cityLongitude = 9.19`, `cityCountry: String? = "Italia"`, `armocromia: Data?`, `createdAt = Date.now`, `updatedAt = Date.now` |
| `BodyPhoto` | `kind = "front"`, valori `front`, `side`, `back`; `photo: Data?` con `.externalStorage`; `updatedAt = Date.now` |

`season` e `occasion` restano singoli, come nel sito e in `outfitAlgorithm.js`. `day` è una stringa, così un viaggio in un altro fuso non sposta la voce di un giorno.

- [ ] **Step 1: Scrivere i test che falliscono**

```swift
@MainActor final class ModelsTests: XCTestCase {
    func testIDefaultDelProfiloComeIlSito() {
        let p = Profile()
        XCTAssertEqual(p.theme, "system")
        XCTAssertEqual(p.cityName, "Milano")
        XCTAssertEqual(p.cityLatitude, 45.4642)
    }
    func testFotoGrandeSopravviveAllaRiapertura() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).store")
        let photo = Data(repeating: 7, count: 3_000_000)
        var container: ModelContainer? = try StoreFactory.build(.local, url: url)
        let item = Item(); item.photoFront = photo
        container!.mainContext.insert(item)
        try container!.mainContext.save()
        container = nil
        let again = try StoreFactory.build(.local, url: url)
        XCTAssertEqual(try again.mainContext.fetch(FetchDescriptor<Item>()).first?.photoFront, photo)
    }
}

final class StoreFactoryTests: XCTestCase {
    func testNormaleUsaIlCloud() {
        XCTAssertEqual(StoreFactory.open(build: { try StoreFactory.build($0 == .cloud ? .memory : $0) }).health, .cloud)
    }
    func testSeIlCloudFallisceSalvaInLocale() {
        let opened = StoreFactory.open(build: { mode in
            if mode == .cloud { throw CocoaError(.coreData) }
            return try StoreFactory.build(.memory)
        })
        XCTAssertEqual(opened.health, .localOnly)
    }
    func testSeFallisceAncheIlLocaleLAppParteLoStesso() {
        let opened = StoreFactory.open(build: { mode in
            if mode != .memory { throw CocoaError(.coreData) }
            return try StoreFactory.build(.memory)
        })
        XCTAssertEqual(opened.health, .temporary)
    }
    func testIModelliSonoCompatibiliConCloudKit() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).store")
        XCTAssertNoThrow(try StoreFactory.build(.cloud, url: url))
    }
}
```

Run: il comando di test del Task 3.
Expected: FAIL, i tipi non esistono.

- [ ] **Step 2: Scrivere `Models.swift` e `StoreFactory.swift`**

- `build(.cloud)`: `ModelConfiguration("StyleVault", schema:, url:, cloudKitDatabase: .private(containerID))`.
- `build(.local)`: stesso nome e stesso file, `cloudKitDatabase: .none`, così i dati salvati restano.
- `build(.memory)`: `isStoredInMemoryOnly: true`, `cloudKitDatabase: .none`.
- `open`: prova `preferred`, poi `.local`, poi `.memory`. La salute dice dove è arrivata: `.cloud` → `.cloud`, `.local` → `.localOnly`, `.memory` → `.temporary`. Se tutti falliscono, `fatalError` solo per `.memory`, che non tocca il disco.

Senza account iCloud `build(.cloud)` riesce comunque: salva in locale e sincronizza quando l'account torna. La salute resta `.cloud` e l'avviso arriva da `SyncMonitor`.

- [ ] **Step 3: Verificare**

Run: il comando di test del Task 3.
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 4: Controllare che il test CloudKit sappia fallire**

Togliere il default da `Item.name`, cioè `var name: String` con init obbligatorio, e rilanciare solo `testIModelliSonoCompatibiliConCloudKit`.
Expected: FAIL o errore di apertura. Rimettere il default. Se il test passa comunque, sostituirlo con un controllo su `schema.entities` che richieda per ogni attributo `isOptional == true` o `defaultValue != nil`, e ripetere questo step.

- [ ] **Step 5: Commit**

```bash
git add ios/StyleVaultNative ios/StyleVaultNativeTests
git commit -m "feat(nativa): modelli SwiftData con CloudKit e apertura sicura"
```

---

### Task 5: Il Profilo è un record solo

CloudKit non ha vincoli `unique`: due dispositivi possono creare ognuno un `Profile`.

**Files:**
- Create: `ios/StyleVaultNative/Data/ProfileStore.swift`
- Create: `ios/StyleVaultNativeTests/ProfileStoreTests.swift`

**Interfaces:**
- Consumes: `Profile`, `StoreFactory.build(.memory)`
- Produces: `@MainActor enum ProfileStore { @discardableResult static func current(in context: ModelContext) throws -> Profile; static func survivor(of profiles: [Profile]) -> Profile? }`

- [ ] **Step 1: Scrivere i test che falliscono**

```swift
@MainActor final class ProfileStoreTests: XCTestCase {
    private func context() throws -> ModelContext { try StoreFactory.build(.memory).mainContext }
    private func count(_ c: ModelContext) throws -> Int { try c.fetchCount(FetchDescriptor<Profile>()) }

    func testIlPrimoAvvioCreaUnProfilo() throws {
        let c = try context()
        XCTAssertEqual(try ProfileStore.current(in: c).cityName, "Milano")
        XCTAssertEqual(try count(c), 1)
    }
    func testIlSecondoAvvioNonNeCreaUnAltro() throws {
        let c = try context()
        let first = try ProfileStore.current(in: c)
        XCTAssertEqual(try ProfileStore.current(in: c).id, first.id)
        XCTAssertEqual(try count(c), 1)
    }
    func testRestaIlPiuRecente() throws {
        let c = try context()
        let old = Profile(); old.cityName = "Roma"; old.updatedAt = .distantPast
        let new = Profile(); new.cityName = "Torino"; new.updatedAt = .now
        c.insert(old); c.insert(new); try c.save()
        XCTAssertEqual(try ProfileStore.current(in: c).cityName, "Torino")
        XCTAssertEqual(try count(c), 1)
    }
    func testNonPerdeLArmocromia() throws {
        let c = try context()
        let withColors = Profile(); withColors.armocromia = Data([1]); withColors.updatedAt = .distantPast
        let newer = Profile(); newer.updatedAt = .now
        c.insert(withColors); c.insert(newer); try c.save()
        XCTAssertEqual(try ProfileStore.current(in: c).armocromia, Data([1]))
    }
    func testDueDispositiviScelgonoLoStessoRecord() {
        let date = Date.now
        let a = Profile(); a.updatedAt = date
        let b = Profile(); b.updatedAt = date
        XCTAssertEqual(ProfileStore.survivor(of: [a, b])?.id, ProfileStore.survivor(of: [b, a])?.id)
    }
}
```

Run: il comando di test del Task 3.
Expected: FAIL, `ProfileStore` non esiste.

- [ ] **Step 2: Scrivere `ProfileStore.swift`**

`survivor`: il massimo per `updatedAt`, a parità il maggiore per `id.uuidString`, così ogni dispositivo sceglie lo stesso. `current`: se non ci sono record ne crea uno; se ce n'è più di uno, copia l'`armocromia` sul sopravvissuto quando gli manca, cancella gli altri e salva.

- [ ] **Step 3: Verificare**

Run: il comando di test del Task 3.
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add ios/StyleVaultNative ios/StyleVaultNativeTests
git commit -m "feat(nativa): un solo Profilo anche con due dispositivi"
```

---

### Task 6: Stato della sincronizzazione

**Files:**
- Create: `ios/StyleVaultNative/Data/SyncMonitor.swift`
- Create: `ios/StyleVaultNativeTests/SyncMonitorTests.swift`

**Interfaces:**
- Consumes: `StoreHealth`, `StoreFactory.containerID`
- Produces:
  - `enum SyncState: Equatable { case active, unavailable, temporaryStore }`
  - `enum SyncRules { static func state(health: StoreHealth, account: CKAccountStatus, lastError: Error?) -> SyncState }`
  - `@MainActor @Observable final class SyncMonitor { private(set) var state: SyncState; init(health: StoreHealth); func start() }`

- [ ] **Step 1: Scrivere i test che falliscono**

```swift
final class SyncMonitorTests: XCTestCase {
    func testTuttoBene() {
        XCTAssertEqual(SyncRules.state(health: .cloud, account: .available, lastError: nil), .active)
    }
    func testSenzaAccountCompareLAvviso() {
        for status: CKAccountStatus in [.noAccount, .restricted, .couldNotDetermine, .temporarilyUnavailable] {
            XCTAssertEqual(SyncRules.state(health: .cloud, account: status, lastError: nil), .unavailable)
        }
    }
    func testICloudPieno() {
        XCTAssertEqual(SyncRules.state(health: .cloud, account: .available, lastError: CKError(.quotaExceeded)), .unavailable)
    }
    func testSenzaReteNonEUnProblema() {
        for code: CKError.Code in [.networkUnavailable, .networkFailure, .serviceUnavailable] {
            XCTAssertEqual(SyncRules.state(health: .cloud, account: .available, lastError: CKError(code)), .active)
        }
    }
    func testArchivioSoloLocale() {
        XCTAssertEqual(SyncRules.state(health: .localOnly, account: .available, lastError: nil), .unavailable)
    }
    func testArchivioTemporaneo() {
        XCTAssertEqual(SyncRules.state(health: .temporary, account: .available, lastError: nil), .temporaryStore)
    }
}
```

Run: il comando di test del Task 3.
Expected: FAIL, i tipi non esistono.

- [ ] **Step 2: Scrivere `SyncMonitor.swift`**

`start` chiede `CKContainer(identifier:).accountStatus()`, ascolta `.CKAccountChanged` e `NSPersistentCloudKitContainer.eventChangedNotification`. Conserva l'errore dell'ultimo evento concluso e lo azzera al primo evento riuscito. `accountStatus` che fallisce vale `.couldNotDetermine`. In modalità memoria di prova, `.temporary`, non contatta CloudKit.

- [ ] **Step 3: Verificare**

Run: il comando di test del Task 3.
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add ios/StyleVaultNative ios/StyleVaultNativeTests
git commit -m "feat(nativa): stato della sincronizzazione iCloud"
```

---

### Task 7: Tab, tema e testi

**Files:**
- Create: `ios/StyleVaultNative/App/TabRouter.swift`
- Create: `ios/StyleVaultNative/App/RootTabView.swift`
- Modify: `ios/StyleVaultNative/App/StyleVaultNativeApp.swift`
- Create: `tools/nativa/strings-native.json`
- Create: `tools/nativa/export-strings.mjs`
- Create: `ios/StyleVaultNative/Resources/Localizable.xcstrings`, generato
- Create: `ios/StyleVaultNative/Resources/InfoPlist.xcstrings`
- Create: `ios/StyleVaultNativeTests/TabRouterTests.swift`
- Create: `ios/StyleVaultNativeTests/LocalizationTests.swift`

**Interfaces:**
- Consumes: `StoreFactory.open`, `SyncMonitor`, `ProfileStore.current`, `Catalog`, `ThemeStore.colorScheme(for:)`, `Palette`
- Produces:
  - `enum AppTab: Hashable, CaseIterable { case wardrobe, outfit, add, calendar, profile }`
  - `struct TabRouter: Equatable { var selected: AppTab = .wardrobe; var isAddSheetPresented = false; mutating func select(_ tab: AppTab) }`
  - `struct RootTabView: View`
  - `struct SyncNotice: View`, mostrato sopra le tab quando lo stato non è `.active`

**Testi.** `export-strings.mjs` prende da `it.json` ed `en.json` i gruppi `nav`, `categories`, `subcategories`, `seasons`, `occasions`, `colors` e queste chiavi di `profile`: `settings`, `defaultCity`, `language`, `theme`, `themeLight`, `themeDark`, `themeSystem`. Ci aggiunge `strings-native.json` e scrive il catalogo con `sourceLanguage: "it"`, stato `translated`. Testi nuovi:

| Chiave | Italiano | Inglese |
|---|---|---|
| `native.sync.off` | Sincronizzazione non attiva. I dati restano su questo dispositivo. | Sync is off. Your data stays on this device. |
| `native.sync.temporary` | Non riesco ad aprire i dati. Ciò che aggiungi ora non verrà salvato. | Your data could not be opened. What you add now will not be saved. |
| `native.comingSoon` | In arrivo | Coming soon |
| `native.language.system` | Si cambia nelle Impostazioni | Change it in Settings |
| `native.city.search` | Cerca una città | Search for a city |
| `native.city.none` | Nessuna città trovata | No city found |

- [ ] **Step 1: Scrivere i test che falliscono**

```swift
final class TabRouterTests: XCTestCase {
    func testAggiungiApreIlFoglioELasciaLaTab() {
        var r = TabRouter(); r.select(.calendar); r.select(.add)
        XCTAssertEqual(r.selected, .calendar)
        XCTAssertTrue(r.isAddSheetPresented)
    }
    func testLeAltreTabCambianoSoltanto() {
        var r = TabRouter(); r.select(.profile)
        XCTAssertEqual(r.selected, .profile)
        XCTAssertFalse(r.isAddSheetPresented)
    }
}

final class LocalizationTests: XCTestCase {
    func testOgniEtichettaHaItalianoEInglese() throws {
        let keys = Catalog.categories.flatMap { [$0.labelKey] + $0.subcategories.map(\.labelKey) }
            + Catalog.seasons.map(\.labelKey) + Catalog.occasions.map(\.labelKey) + Catalog.colors.map(\.labelKey)
            + ["nav.wardrobe", "nav.outfit", "nav.add", "nav.calendar", "nav.profile", "native.sync.off"]
        for language in ["it", "en"] {
            let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"))
            let bundle = try XCTUnwrap(Bundle(path: path))
            for key in keys {
                XCTAssertNotEqual(bundle.localizedString(forKey: key, value: key, table: nil), key, "\(language): \(key)")
            }
        }
    }
}
```

Run: il comando di test del Task 3.
Expected: FAIL, tipi e catalogo non esistono.

- [ ] **Step 2: Scrivere script e catalogo**

Run: `node tools/nativa/export-strings.mjs`
Expected: il file esiste ed è JSON valido per `plutil -lint`.

- [ ] **Step 3: Scrivere tab e avvio**

- Tab con etichette `nav.*`, simboli `tshirt`, `sparkles`, `plus.circle.fill`, `calendar`, `person`.
- Guardaroba, Outfit e Calendario mostrano `native.comingSoon`, sono segnaposto del ramo.
- L'app apre lo store con `StoreFactory.open`. In `#if DEBUG`, l'argomento `-SVMemoryStore` passa `preferred: .memory`.
- `.preferredColorScheme` legge `Profile.theme`, attraverso una `@Query` di tutti i `Profile`.
- All'avvio e quando il numero dei `Profile` cambia si chiama `ProfileStore.current(in:)`: così i doppioni arrivati da iCloud si uniscono anche ad app aperta.
- Con il tasto + si apre un foglio vuoto, con identificatore di accessibilità `add-sheet`. Lo riempie la fase 2.
- Si usano gli sfondi di `Palette`.

- [ ] **Step 4: Verificare**

Run: il comando di test del Task 3.
Expected: `** TEST SUCCEEDED **`. Controllare anche che `build/dd-native/Build/Products/Debug-iphonesimulator/StyleVaultNative.app` contenga `it.lproj` ed `en.lproj`.

- [ ] **Step 5: Commit**

```bash
git add ios/StyleVaultNative ios/StyleVaultNativeTests tools/nativa
git commit -m "feat(nativa): tab, tema, avviso iCloud e testi in italiano e inglese"
```

---

### Task 8: Profilo con tema, lingua e città

**Files:**
- Create: `ios/StyleVaultNative/Profile/ProfileView.swift`
- Create: `ios/StyleVaultNative/Profile/CitySearchModel.swift`
- Create: `ios/StyleVaultNative/Profile/CitySearchView.swift`
- Modify: `ios/StyleVaultNative/App/RootTabView.swift`
- Modify: `ios/project.yml`
- Create: `ios/StyleVaultNativeTests/CitySearchModelTests.swift`
- Create: `ios/StyleVaultNativeUITests/ProfileFlowTests.swift`

**Interfaces:**
- Consumes: `CitySearch`, `City`, `Profile`, `ProfileStore.current`
- Produces:
  - `extension Profile { func apply(city: City); func setTheme(_ value: String) }`, entrambe aggiornano `updatedAt`
  - `@MainActor @Observable final class CitySearchModel { enum Phase: Equatable { case idle, searching, results([City]), empty }; private(set) var phase: Phase; init(search: @escaping (String) async throws -> [City]); func run(query: String) async }`

- [ ] **Step 1: Scrivere i test che falliscono**

```swift
@MainActor final class CitySearchModelTests: XCTestCase {
    private let milano = City(id: 1, name: "Milano", latitude: 45.46, longitude: 9.19, country: "Italia", region: nil)

    func testUnaLetteraNonCerca() async {
        var called = false
        let m = CitySearchModel(search: { _ in called = true; return [] })
        await m.run(query: " m ")
        XCTAssertEqual(m.phase, .idle)
        XCTAssertFalse(called)
    }
    func testMostraIRisultati() async {
        let m = CitySearchModel(search: { [milano] _ in [milano] })
        await m.run(query: "mila")
        XCTAssertEqual(m.phase, .results([milano]))
    }
    func testReteAssenteComeNessunRisultato() async {
        let m = CitySearchModel(search: { _ in throw URLError(.notConnectedToInternet) })
        await m.run(query: "mila")
        XCTAssertEqual(m.phase, .empty)
    }
    func testLaCittaSceltaAggiornaIlProfilo() {
        let p = Profile(); let before = p.updatedAt
        p.apply(city: milano)
        XCTAssertEqual(p.cityLatitude, 45.46)
        XCTAssertGreaterThanOrEqual(p.updatedAt, before)
    }
}
```

Run: il comando di test del Task 3.
Expected: FAIL.

- [ ] **Step 2: Scrivere le schermate**

- `ProfileView`, sezione `profile.settings`, in quest'ordine:
  - riga `profile.defaultCity`, con il nome della città, che apre `CitySearchView`;
  - riga `profile.language`, con `native.language.system`, che apre `UIApplication.openSettingsURLString`;
  - selettore a segmenti `profile.theme`: Chiaro, Scuro, Sistema, nello stesso ordine del sito. Identificatore di accessibilità `theme-picker`.
- `CitySearchView`: `.searchable`, attesa di 350 ms con `.task(id: query)`, lingua da `Bundle.main.preferredLocalizations.first ?? "it"`. Se la ricerca non dà risultati mostra `native.city.none`. Toccando una città chiama `apply(city:)` e torna indietro.
- Su iPad il contenuto resta centrato, con larghezza massima 600 pt.

- [ ] **Step 3: Aggiungere il target UI**

In `ios/project.yml`: target `StyleVaultNativeUITests`, `type: bundle.ui-testing`, `TEST_TARGET_NAME: StyleVaultNative`, `GENERATE_INFOPLIST_FILE: YES`, aggiunto allo schema.

```swift
final class ProfileFlowTests: XCTestCase {
    func testCinqueTabEFoglioAggiungi() {
        let app = launch(language: "it")
        for label in ["Guardaroba", "Outfit", "Calendario", "Profilo"] {
            XCTAssertTrue(app.tabBars.buttons[label].exists, label)
        }
        app.tabBars.buttons["Aggiungi"].tap()
        XCTAssertTrue(app.otherElements["add-sheet"].waitForExistence(timeout: 3))
    }
    func testInIngleseLeTabSonoTradotte() {
        XCTAssertTrue(launch(language: "en").tabBars.buttons["Wardrobe"].exists)
    }
    func testIlTemaSiCambiaDalProfilo() {
        let app = launch(language: "it")
        app.tabBars.buttons["Profilo"].tap()
        let picker = app.segmentedControls["theme-picker"]
        picker.buttons["Scuro"].tap()
        XCTAssertTrue(picker.buttons["Scuro"].isSelected)
    }
    private func launch(language: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-SVMemoryStore", "-AppleLanguages", "(\(language))"]
        app.launch()
        return app
    }
}
```

- [ ] **Step 4: Verificare su iPhone**

Run: il comando di test del Task 3, dopo `xcodegen generate`.
Expected: `** TEST SUCCEEDED **`, compresi i test UI.

- [ ] **Step 5: Verificare su iPad**

Controllare con `xcrun simctl list devices booted` che l'iPad non sia usato da un'altra sessione.

Run: lo stesso comando, con `id=B04B93AB-9CE8-425C-B2B5-BC10A2BD0559`.
Expected: `** TEST SUCCEEDED **`. Se i test UI falliscono perché su iPad le tab non sono in `tabBars`, correggere il test, non l'app.

- [ ] **Step 6: Guardare le schermate**

Con il simulatore iPhone 18 Pro, tema chiaro e scuro, fare uno screenshot di Guardaroba e Profilo. Avviare poi l'app senza `-SVMemoryStore` su un simulatore senza account iCloud.
Expected: l'app si apre, l'avviso `native.sync.off` è visibile e il Profilo funziona.

- [ ] **Step 7: Commit**

```bash
git add ios/StyleVaultNative ios/StyleVaultNativeTests ios/StyleVaultNativeUITests ios/project.yml
git commit -m "feat(nativa): Profilo con tema, lingua e città"
```

---

### Task 9: Prova vera tra iPhone e iPad

La prova scelta dal design. Serve Lorenzo: stesso Apple ID in iCloud su entrambi, dispositivi sbloccati.

**Attenzione:** al primo build viene creato il container `iCloud.it.faraoni.stylevault`. Apple non permette di cancellare i container, e il nome è quello fissato dal design.

**Files:**
- Modify: `MEMORIA.md`
- Create: `docs/verifiche/2026-11-05-nativa-fase-1/prova-iphone-ipad.md`

- [ ] **Step 1: Installare su iPhone e iPad**

Per l'iPhone, `DEV=00008160-000661061A200036`; per l'iPad, `DEV=00008132-000160A61EB9001C`.

```bash
cd ios && xcodebuild build -project StyleVault.xcodeproj -scheme StyleVaultNative -configuration Debug -destination "id=$DEV" -derivedDataPath build/dd-native -allowProvisioningUpdates
xcrun devicectl device install app --device $DEV build/dd-native/Build/Products/Debug-iphoneos/StyleVaultNative.app
```

Expected: installazione riuscita, l'ibrida resta sul dispositivo. Se Xcode non crea il container da riga di comando, aprire il progetto in Xcode, scheda Signing & Capabilities del target: tocca a Lorenzo solo confermare.

- [ ] **Step 2: Provare la sincronizzazione**

Con Lorenzo:
1. aprire l'app su iPhone e iPad, senza avvisi;
2. sull'iPhone scegliere Torino come città e Scuro come tema;
3. sull'iPad, entro qualche minuto, devono comparire Torino e il tema scuro;
4. sull'iPad scegliere Bari;
5. sull'iPhone deve comparire Bari.

Expected: passano tutti e 5, e in Profilo non compare nulla di doppio.

- [ ] **Step 2b: Provare il blocco**

Con Lorenzo, sull'iPhone:
1. attivare il blocco nel Profilo: chiede Face ID;
2. mandare l'app in background e tornare: chiede Face ID, e nel selettore delle app il contenuto non si vede;
3. annullare Face ID: l'app resta bloccata, con il tasto Sblocca;
4. sbagliare Face ID fino al codice: il codice del dispositivo sblocca;
5. sull'iPad il blocco resta spento, perché non si sincronizza.

Expected: passano tutti e 5.

- [ ] **Step 3: Provare senza rete e senza doppioni**

1. mettere l'iPad in modalità aereo, cambiare città e riattivare la rete: il cambio arriva sull'iPhone;
2. disinstallare l'app dall'iPad, reinstallarla e aspettare: il Profilo torna quello di prima, un record solo, con la città e il tema scelti, e anche l'iPhone li conserva;
3. in Impostazioni → iCloud spegnere SV Nativa sull'iPhone, riaprire l'app: deve comparire l'avviso `native.sync.off`, poi riaccendere. Se non compare, l'errore dell'evento `.setup` va trattato come `.unavailable`.

Expected: passano tutti e 3. Il cambio più recente vince.

- [ ] **Step 4: Scrivere l'esito**

Annotare in `prova-iphone-ipad.md` modello dei dispositivi, versione iOS, tempi di arrivo osservati ed eventuali problemi. Aggiornare `MEMORIA.md`.

- [ ] **Step 5: Ripetere tutti i test**

Run, uno alla volta, ognuno dalla radice del repo:
```bash
cd ios/StyleVaultCore && swift test
cd ios && xcodebuild test -project StyleVault.xcodeproj -scheme StyleVaultNative -destination 'platform=iOS Simulator,id=18361580-2FC8-4A18-AED3-7461008C6569' -derivedDataPath build/dd-native
cd ios && xcodebuild test -project StyleVault.xcodeproj -scheme StyleVault -destination 'platform=iOS Simulator,id=18361580-2FC8-4A18-AED3-7461008C6569' -derivedDataPath build/dd-native
```
Expected: Core e nativa verdi, ibrida 138/138.

- [ ] **Step 6: Commit**

```bash
git add MEMORIA.md docs/verifiche/2026-11-05-nativa-fase-1
git commit -m "docs(nativa): esito della prova tra iPhone e iPad"
```

---

### Task 10: Blocco con Face ID

Aggiunto il 2026-11-05, dopo la decisione 7 del design. Si esegue prima del Task 9.

**Files:**
- Create: `ios/StyleVaultNative/App/AppLock.swift`
- Create: `ios/StyleVaultNative/App/LockView.swift`
- Modify: `ios/StyleVaultNative/App/StyleVaultNativeApp.swift`
- Modify: `ios/StyleVaultNative/Profile/ProfileView.swift`
- Modify: `ios/StyleVaultNative/Info.plist`
- Modify: `tools/nativa/strings-native.json`, `tools/nativa/export-strings.mjs`
- Modify: `ios/StyleVaultNative/Resources/Localizable.xcstrings`, `InfoPlist.xcstrings`, generati
- Create: `ios/StyleVaultNativeTests/AppLockTests.swift`
- Modify: `ios/StyleVaultNativeUITests/ProfileFlowTests.swift`

**Interfaces:**
- Produces:
  - `enum AuthOutcome: Equatable { case success, failed, unavailable }`
  - `protocol DeviceAuthenticating { var isAvailable: Bool { get }; func authenticate(reason: String) async -> AuthOutcome }`
  - `struct SystemAuthenticator: DeviceAuthenticating`, con `LAPolicy.deviceOwnerAuthentication`: Face ID o Touch ID, poi il codice del dispositivo
  - `@MainActor @Observable final class AppLock { private(set) var isEnabled: Bool; private(set) var isLocked: Bool; private(set) var isObscured: Bool; var canEnable: Bool { get }; init(defaults: UserDefaults, authenticator: DeviceAuthenticating); func setEnabled(_ value: Bool, reason: String) async; func unlock(reason: String) async; func sceneDidChange(to phase: ScenePhase) }`

**Regole.**
- La scelta sta in `UserDefaults`, chiave `native.lock.enabled`: vale per il dispositivo e non passa da iCloud.
- All'avvio l'app è bloccata se il blocco è attivo.
- Si blocca in `.background`, non in `.inactive`: il foglio di Face ID porta la scena in `.inactive`, e bloccare lì creerebbe un ciclo.
- `isObscured` è vero se il blocco è attivo e la scena non è `.active`: copre i dati nel selettore delle app senza bloccare.
- Attivare e disattivare richiede un'autenticazione riuscita. Se fallisce, il valore resta com'era.
- `.unavailable` durante `unlock`, per esempio perché il codice è stato tolto: l'app si sblocca e il blocco si spegne. **L'utente non deve mai restare chiuso fuori dai suoi dati.**
- Una seconda `unlock` mentre la prima è in corso non apre un altro foglio.
- `LockView` chiede Face ID una volta quando compare, non in ciclo. Se la persona annulla resta il tasto Sblocca.

**Testi.**

| Chiave | Italiano | Inglese |
|---|---|---|
| `native.lock.toggle` | Blocca l'app | Lock the app |
| `native.lock.footer` | All'apertura chiede Face ID, Touch ID o il codice del dispositivo. Vale solo su questo dispositivo. | Asks for Face ID, Touch ID or your device passcode when opened. Applies to this device only. |
| `native.lock.unavailable` | Imposta un codice sul dispositivo per usare il blocco. | Set a device passcode to use the lock. |
| `native.lock.title` | StyleVault è bloccata | StyleVault is locked |
| `native.lock.unlock` | Sblocca | Unlock |
| `native.lock.reason` | Sblocca StyleVault | Unlock StyleVault |
| `NSFaceIDUsageDescription`, in `InfoPlist.xcstrings` | Serve per sbloccare l'app, se attivi il blocco nel Profilo. | Used to unlock the app when you turn on the lock in Profile. |

- [ ] **Step 1: Scrivere i test che falliscono**

`AppLockTests`, con un autenticatore finto e un `UserDefaults(suiteName:)` dedicato. Un test per ogni riga delle regole:
`testSpentoNonBlocca`, `testAttivoBloccaAllAvvio`, `testAttivareRichiedeAutenticazione`, `testAttivareFallitoRestaSpento`, `testDisattivareRichiedeAutenticazione`, `testInattivoNonBloccaMaCopre`, `testBackgroundBlocca`, `testAnnullareLasciaBloccato`, `testSenzaCodiceSiSbloccaESiSpegne`, `testDueUnlockInsiemeChiedonoUnaVolta`, `testLaSceltaSopravviveAlRiavvio`.

Run: il comando di test del Task 3.
Expected: FAIL, i tipi non esistono.

- [ ] **Step 2: Scrivere blocco e schermate**

- `AppLock` si crea una volta nell'`App`, come `SyncMonitor`, e passa dall'ambiente SwiftUI.
- `LockView` copre tutta la finestra con `Palette.bg`, con identificatore `lock-screen`. Compare se `isLocked` o `isObscured`. Il tasto Sblocca si vede solo se `isLocked`.
- In `ProfileView`, nella sezione `profile.settings` dopo il tema: interruttore `native.lock.toggle`, identificatore `lock-toggle`, con il testo `native.lock.footer`. Se `canEnable` è falso l'interruttore è disattivato e il testo diventa `native.lock.unavailable`.
- In `#if DEBUG`, l'argomento `-SVFakeLock` usa un autenticatore che riesce sempre, per i test UI. Il simulatore non ha Face ID registrato.

- [ ] **Step 3: Aggiungere il test UI**

`testBloccoConAutenticatoreFinto`: con `-SVMemoryStore -SVFakeLock` si attiva l'interruttore, si rilancia l'app senza cancellare i dati, compare `lock-screen`, si tocca Sblocca e si vedono le tab.

- [ ] **Step 4: Verificare**

Run: `node tools/nativa/export-strings.mjs`, poi il comando di test del Task 3, poi lo stesso con l'iPad del Task 8.
Expected: `** TEST SUCCEEDED **` su entrambi. `Info.plist` dell'app costruita contiene `NSFaceIDUsageDescription`.

- [ ] **Step 5: Commit**

```bash
git add ios/StyleVaultNative ios/StyleVaultNativeTests ios/StyleVaultNativeUITests tools/nativa
git commit -m "feat(nativa): blocco facoltativo con Face ID"
```

---

## Scelte fatte in questo piano

Il design non le fissava. Costano poco da cambiare, tranne dove indicato.

- **ID e nome di sviluppo:** `it.faraoni.stylevault.nativa` e "SV Nativa", così l'app ibrida resta installata. Nella fase 8 diventano `it.faraoni.stylevault` e "StyleVault". Il container resta lo stesso.
- **Lingua:** il Profilo apre la scelta di sistema dell'app, invece di un selettore interno. È il modo previsto da Apple e copre tutte le API di testo. Sul sito c'era un interruttore IT/EN.
- **Stagione e occasione:** una per capo, come oggi nel sito e nell'algoritmo. Il design le elencava al plurale.
- **Calendario:** il giorno è una stringa, per non farlo spostare con i fusi orari.
- **Ricerca città:** come il sito, con Open-Meteo. Se nella fase 3 resta solo WeatherKit, passa a MapKit.

## Per le fasi successive

- **Fase 2:** categorie personalizzate, oggi solo in `localStorage`. Doppioni di `BodyPhoto`, da unire come il Profilo.
- **Fase 3:** l'outfit salvato nel sito conserva una copia dei capi e sopravvive alla loro cancellazione. Qui per ora ci sono solo i riferimenti: i campi nuovi si possono aggiungere, perché lo schema non è ancora in Production.
- **Fase 8:** Privacy Manifest nel target nuovo, `aps-environment` di produzione, promozione dello schema CloudKit.
