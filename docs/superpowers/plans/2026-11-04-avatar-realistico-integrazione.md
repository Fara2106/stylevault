# Avatar realistico nell'app — Piano d'integrazione

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In "Vedilo addosso" la parte di sopra dell'outfit diventa realistica, calcolata sull'iPhone con Mobile-VTON (Core ML, 6 bit), per tutti gli utenti dell'app pubblicata gratis.

**Architecture:** I 7 modelli 6 bit e i file dei tokenizzatori stanno in una Release GitHub pubblica (`Fara2106/stylevault`, archivi Apple Archive + manifest con SHA-256). L'app li scarica al primo uso, li compila e li tiene in Application Support. Un motore `MobileVTONTryOn` (dietro il protocollo `RealisticTryOn`) rifà in Swift la catena già verificata in `ios/RealisticBench/BenchGenerator.swift`, con tokenizzatore CLIP, preprocessing DINOv2, scheduler e rumore scritti in Swift. Il risultato sostituisce la foto del corpo della vista. Pantaloni e scarpe si disegnano sopra col collage di oggi, poi la parte di sopra realistica si ridisegna sopra i pantaloni con una maschera ricavata dalla differenza tra la foto originale e il risultato.

**Tech Stack:** Swift 6 / SwiftUI, Core ML, Vision, AppleArchive, CryptoKit, XcodeGen; Python 3.11 + transformers (solo tokenizzatori, senza Mobile-VTON); JS (sito, Vitest).

**Spec:** `docs/superpowers/specs/2026-11-03-avatar-realistico-design.md`. I risultati della prova sono in `docs/verifiche/2026-11-03-avatar-realistico/prova-tecnica.md`.

## Global Constraints

- Decisione di Lorenzo (2026-11-04): si va avanti con Mobile-VTON e l'app si **pubblica gratis**. Licenza CC BY-NC-SA 4.0, quindi l'app non può avere pubblicità, acquisti in-app, abbonamenti né fini commerciali finché c'è questo modello. Vanno riportati autori e licenza nell'app e nella Release, e i modelli convertiti si distribuiscono con la stessa licenza.
- Configurazione misurata: **6 bit**, modalità **mista** (tutto `.cpuAndNeuralEngine`, `Denoiser` su `.cpuAndGPU`), **una rete grande alla volta**, feature del capo su file fp16 mappati, entitlement `com.apple.developer.kernel.increased-memory-limit`.
- Parametri del modello: 768×1024 (3:4), 10 passi, guida 2,5, FlowMatch shift 3, latenti `(x − 0,0609) · 1,5305`, testo = CLIP-L ‖ CLIP-G allargato a 4096 + 256 token a zero, negativo fisso = `common.NEGATIVE` di `tools/avatar-realistico/common.py`.
- Didascalie, copiate da `common.py`: `caption_cloth = "The item is a \(descriptor)."`, `caption = "Replace the upper body with " + caption_cloth senza la prima parola`.
- Tokenizzatori: max 77 token. `tokenizer` ha pad `<|endoftext|>` (49407), `tokenizer_2` ha pad `!`; il vocabolario è lo stesso.
- DINOv2 (`image_encoder/preprocessor_config.json`): lato corto a 256 bicubico, ritaglio centrale 224×224, ×1/255, media [0,485, 0,456, 0,406], dev. std [0,229, 0,224, 0,225].
- Soglie: vista davanti ≤ 60 s sul 18 Pro Max, ≤ 90 s sul 15 Pro, nessuna chiusura per memoria. Versione realistica solo con **RAM fisica ≥ 7,5 GB** e su dispositivo vero; altrove resta il collage.
- Lo script che importa Mobile_VTON lo lancia Lorenzo. Gli altri script si lanciano con `python -I`.
- Simulatore: sempre `-destination 'id=18361580-2FC8-4A18-AED3-7461008C6569'` e `CODE_SIGNING_ALLOWED=NO`. Vision non gira nel simulatore iOS 27: i test con Vision o Core ML vero girano sul Mac (`RealisticBenchMac`) o sul dispositivo.
- Commit in italiano con `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Commit, push, Release e deploy del sito solo con l'ok di Lorenzo.

## Review Focus

1. **App in background durante il calcolo**: iOS non permette la GPU in background. La generazione si ferma pulita, resta il collage e al ritorno si può rigenerare (test in Task 7).
2. **Download interrotto, spazio insufficiente o hash sbagliato**: il download riprende da dove era rimasto, compare un messaggio chiaro e un modello corrotto non viene mai caricato (test in Task 5).
3. **Dispositivo con meno di 8 GB o simulatore**: niente download, solo collage e una nota (test in Task 5).
4. **Foto del corpo non 3:4** (molto alta, orizzontale, con EXIF ruotato): il bordo bianco va aggiunto e tolto in modo che il risultato combaci con la foto originale (test in Task 3 e Task 6).
5. **Sito non aggiornato (manca `descriptor`) o nomi italiani con accenti ed emoji**: la didascalia ricade sul nome, il tokenizzatore non va in crash e tronca a 77 token (test in Task 2).

---

### Task 1: Pacchetto dei modelli e casi di prova del tokenizzatore (Mac)

**Files:**
- Create: `tools/avatar-realistico/package_models.py`
- Create: `tools/avatar-realistico/export_tokenizer_cases.py`
- Create: `tools/avatar-realistico/MODELS-LICENSE.md` (autori, citazione, CC BY-NC-SA 4.0, cosa è stato modificato: conversione Core ML e palettizzazione 6 bit)
- Create: `ios/StyleVaultTests/Fixtures/realistic/tokenizer-cases.json`, `cloth-pixels.bin` e `cloth.jpg` (= `maglione.jpg` portato a 3:4)
- Modify: `tools/avatar-realistico/README.md` (due righe nella tabella)

**Interfaces:**
- Produces: `out/release/` con un `.aar` per modello (`TextEncoder.aar`, …, `VAEDecoder.aar` da `out/coreml-6bit/*.mlpackage`), `Tokenizer.aar` (vocab.json + merges.txt di `tokenizer`), `MODELS-LICENSE.md` e `models-manifest.json`:
  `{"version": 1, "files": [{"name": "Denoiser.aar", "bytes": Int, "sha256": "hex"}]}`
- Produces: `tokenizer-cases.json` = `[{"text": String, "ids": [Int], "ids2": [Int]}]`

- [ ] **Step 1:** scrivi `export_tokenizer_cases.py WEIGHTS`. Usa `CLIPTokenizer` di transformers con `padding="max_length", max_length=77, truncation=True` per i due tokenizzatori. Casi:
  - il negativo;
  - le due didascalie della coppia di prova;
  - `"The item is a light-blue button-up shirt."`;
  - `"The item is a Maglione a trecce più caldo 🧶."`;
  - una frase di 120 parole (troncatura).

  Esporta anche `cloth_pixels` (copia da `out/bench-inputs/cloth_pixels.bin`) e `cloth.jpg` (`common.fit_3x4(maglione)`).
- [ ] **Step 2:** lancialo: `"$SPIKE/venv-convert/bin/python" -I tools/avatar-realistico/export_tokenizer_cases.py "$SPIKE/weights/checkpoint"`. Atteso: 6 casi; nel caso della coppia di prova `ids`/`ids2` uguali a `out/bench-inputs/ids_caption.bin`/`ids2_caption.bin`.
- [ ] **Step 3:** scrivi `package_models.py`.
  - Per ogni modello lancia `aa archive -d out/coreml-6bit/<Nome>.mlpackage -o out/release/<Nome>.aar`; per il tokenizzatore archivia `vocab.json` + `merges.txt`.
  - Calcola sha256 e byte di ogni archivio e scrive `models-manifest.json`.
  - Copia `MODELS-LICENSE.md` in `out/release/`.
- [ ] **Step 4:** lancialo con `python -I`. Atteso: 8 archivi, totale ≈ 1,2 GB; `aa extract` di uno dei due ridà un `.mlpackage` che `coremltools` apre.
- [ ] **Step 5:** commit (script, licenza, fixture). La **Release** `avatar-models-v1`, con gli archivi, il manifest e la licenza nelle note, la crea `gh release create` solo con l'ok di Lorenzo.

### Task 2: Didascalia e tokenizzatore CLIP in Swift

**Files:**
- Create: `ios/StyleVault/Realistic/CLIPTokenizer.swift`
- Create: `ios/StyleVault/Realistic/GarmentCaption.swift`
- Test: `ios/StyleVaultTests/CLIPTokenizerTests.swift`
- Modify: `ios/project.yml` (cartella `Fixtures/realistic` nelle risorse dei test)

**Interfaces:**
- Produces:
  ```swift
  struct CLIPTokenizer {
      init(vocab: URL, merges: URL, padToken: String) throws   // "<|endoftext|>" oppure "!"
      func ids(_ text: String) -> [Int32]                        // sempre 77
  }
  enum GarmentCaption {
      static let negative: String                                  // = common.NEGATIVE
      static func cloth(_ item: AvatarItem) -> String              // "The item is a <descriptor>."
      static func person(_ item: AvatarItem) -> String             // "Replace the upper body with item is a <descriptor>."
  }
  ```
  `descriptor` vale `item.descriptor` (Task 8) se c'è e non è vuoto, altrimenti `item.name`, altrimenti `"garment"`.

- [ ] **Step 1:** test `testMatchesPythonCases`. Per ogni caso di `tokenizer-cases.json`: `CLIPTokenizer(…, padToken: "<|endoftext|>").ids(text) == ids` e con `"!"` `== ids2`.
- [ ] **Step 2:** test `testCaptionFallbacks`:
  - `descriptor = "cream sweater"` dà `"The item is a cream sweater."`;
  - `descriptor = nil, name = "Maglione"` dà `"The item is a Maglione."`;
  - `person(...)` inizia con `"Replace the upper body with item is a "`.
- [ ] **Step 3:** esegui `xcodebuild test -scheme StyleVault -destination 'id=18361580-2FC8-4A18-AED3-7461008C6569' CODE_SIGNING_ALLOWED=NO -only-testing:StyleVaultTests/CLIPTokenizerTests`. Atteso: FAIL (tipi mancanti).
- [ ] **Step 4:** implementa il BPE di CLIP. Testo pulito (spazi compressi, minuscolo) e diviso con la regex di CLIP: `<\|startoftext\|>|<\|endoftext\|>|'s|'t|'re|'ve|'m|'ll|'d|[\p{L}]+|[\p{N}]|[^\s\p{L}\p{N}]+`. Poi byte → unicode come GPT-2, `</w>` sull'ultimo simbolo, merge per rango, BOS 49406 + token (troncati a 75) + EOS 49407, e pad fino a 77.
- [ ] **Step 5:** test PASS, commit.

### Task 3: Ingressi in Swift — bordo 3:4, tensori, DINOv2, scheduler, rumore

**Files:**
- Create: `ios/StyleVault/Realistic/TryOnInputs.swift`
- Test: `ios/StyleVaultTests/TryOnInputsTests.swift`

**Interfaces:**
- Produces:
  ```swift
  enum TryOnInputs {
      static let width = 768, height = 1024
      /// Come PIL ImageOps.pad: adatta mantenendo le proporzioni, centra, bordo bianco.
      static func pad3x4(_ image: CGImage) -> (image: CGImage, content: CGRect)  // content = dove sta la foto nei 768×1024
      static func unpad(_ result: CGImage, content: CGRect, to size: CGSize) -> CGImage
      static func modelTensor(_ image: CGImage) -> [Float]          // [3, 1024, 768] in [-1, 1], RGB
      static func dinoPixels(_ image: CGImage) -> [Float]           // [3, 224, 224]
      static func schedule(steps: Int, shift: Double) -> (timesteps: [Double], sigmas: [Double])
      static func noise(count: Int, seed: UInt64) -> [Float]        // gaussiana N(0,1) riproducibile
  }
  ```

- [ ] **Step 1:** test.
  - `testScheduleMatchesDiffusers`: `schedule(steps: 10, shift: 3)` uguale a `timesteps` e `sigmas` di `out/bench-inputs/manifest.json`, copiati nel test (tolleranza 1e-4).
  - `testDinoPixelsCloseToPython`: `dinoPixels(cloth.jpg)` contro `cloth-pixels.bin`, errore medio assoluto < 0,03.
  - `testPadRoundTrip`: 600×1200 (alta), 1200×600 (larga) e 768×1024: `content` centrato, rapporto conservato, `unpad(pad3x4(x).image, …)` riporta la dimensione di partenza.
  - `testNoiseIsGaussianAndStable`: due chiamate col seed 42 sono uguali; su 1e6 campioni media ≈ 0 ± 0,01 e varianza ≈ 1 ± 0,01.
- [ ] **Step 2:** esegui i test sul simulatore. Atteso: FAIL.
- [ ] **Step 3:** implementa. Lo scheduler va scritto così (diffusers `FlowMatchEulerDiscreteScheduler`, verificato con il manifest):
  ```
  shifted(s) = shift·s / (1 + (shift−1)·s)
  t_i = linspace(1, shifted(1/1000), steps)
  sigma_i = shifted(t_i), poi si aggiunge 0
  timesteps = sigma_i · 1000
  ```
  - DINOv2: ridimensiona con CoreGraphics `interpolationQuality = .high`. Il ritaglio centrale arrotonda come transformers: `top = (h − 224) / 2`, con divisione intera.
  - Rumore: SplitMix64 + Box–Muller.
  - Applica l'orientamento EXIF prima del bordo.
- [ ] **Step 4:** test PASS, commit.

### Task 4: Conti condivisi tra app e banco

**Files:**
- Move: `ios/RealisticBench/BenchMath.swift` → `ios/StyleVault/Realistic/TryOnMath.swift` (`enum TryOnMath`, stesso contenuto)
- Modify: `ios/project.yml` (RealisticBench e RealisticBenchMacTests includono `StyleVault/Realistic/TryOnMath.swift`)
- Modify: `ios/RealisticBench/*.swift`, `ios/RealisticBenchTests/BenchMathTests.swift` (`BenchMath` → `TryOnMath`)

- [ ] **Step 1:** sposta il file e rinomina il tipo; `xcodegen generate`.
- [ ] **Step 2:** esegui i test di `RealisticBenchTests` (9) e i test macOS di `CopyFloatsTests` (4). Atteso: PASS. Commit.

### Task 5: Modelli sul telefono — supporto, download, verifica, compilazione

**Files:**
- Create: `ios/StyleVault/Realistic/RealisticSupport.swift`
- Create: `ios/StyleVault/Realistic/RealisticModelStore.swift`
- Test: `ios/StyleVaultTests/RealisticModelStoreTests.swift`

**Interfaces:**
- Produces:
  ```swift
  enum RealisticSupport {
      static func isSupported(physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory,
                              isSimulator: Bool) -> Bool   // ≥ 7,5e9 e non simulatore; l'app passa #if targetEnvironment(simulator)
  }
  enum ModelStoreProgress: Equatable { case downloading(done: Int64, total: Int64), preparing(done: Int, total: Int) }
  enum ModelStoreError: Error, Equatable { case notEnoughSpace(neededMB: Int), corrupted(String), network }
  actor RealisticModelStore {
      static let shared: RealisticModelStore
      init(baseURL: URL, folder: URL, session: URLSession = .shared)
      var isReady: Bool { get }
      func prepare(progress: @Sendable (ModelStoreProgress) -> Void) async throws   // scarica, verifica, estrae, compila
      func modelURL(_ name: String) -> URL?          // .mlmodelc compilato
      func tokenizerFiles() -> (vocab: URL, merges: URL)?
  }
  ```
  - `baseURL` = `https://github.com/Fara2106/stylevault/releases/download/avatar-models-v1/`.
  - `folder` = Application Support/RealisticModels, esclusa dal backup.
  - Il manifest scaricato è salvato accanto ai modelli: `isReady` è vero solo se tutti i file del manifest sono compilati.

- [ ] **Step 1:** test, con un `URLProtocol` finto che serve archivi piccoli: un `.aar` di un `.mlpackage` minuscolo creato nel test con `aa`, oppure una cartella qualsiasi + manifest.
  - `testUnsupportedDevices`: 6 GB → false; 8 GB nel simulatore → false; 8 GB su dispositivo → true.
  - `testHashMismatchDeletesFile`: sha sbagliato → `ModelStoreError.corrupted("X.aar")`, il file non resta e `isReady == false`.
  - `testResumesAfterInterruption`: il protocollo finto interrompe a metà → al secondo `prepare` la richiesta porta `Range: bytes=<scaricati>-` e il file finale ha l'hash giusto.
  - `testNotEnoughSpace`: con lo spazio libero iniettato a 1 GB → `notEnoughSpace` prima di scaricare. Servono `bytes` totali × 2,5.
  - `testProgressIsMonotonic`: i `done` crescono e finiscono a `total`.
- [ ] **Step 2:** test FAIL.
- [ ] **Step 3:** implementa.
  - Download per file, su `*.part`, con `Range` da dove si era rimasti.
  - SHA-256 con CryptoKit a blocchi.
  - Estrazione con `AppleArchive`, poi `MLModel.compileModel(at:)` e spostamento in `compiled/`.
  - `preparing` conta i modelli compilati.
  - `URLResourceValues.isExcludedFromBackup = true` sulla cartella.
  - La preparazione per il Neural Engine (≈ 4 min al primo caricamento) avviene nel motore: qui non serve.
- [ ] **Step 4:** test PASS, commit.

### Task 6: Motore `MobileVTONTryOn`

**Files:**
- Create: `ios/StyleVault/Realistic/RealisticTryOn.swift` (protocollo + `MobileVTONTryOn`)
- Test: `ios/RealisticBenchMacTests/MobileVTONTryOnMacTests.swift` (Mac, Core ML vero; i file del motore si aggiungono alle sorgenti di `RealisticBenchMacTests` in `project.yml`)

**Interfaces:**
- Consumes: `CLIPTokenizer`, `GarmentCaption`, `TryOnInputs`, `TryOnMath`, `RealisticModelStore.modelURL`.
- Produces:
  ```swift
  struct TryOnProgress: Equatable { let fraction: Double }   // 0…1, vera: fase 1 = 5%, capo = 10%, ogni passo di prova = 8%, decoder = 5%
  protocol RealisticTryOn: Sendable {
      /// person e garment come arrivano (qualsiasi proporzione); il risultato ha la dimensione di person.
      func generate(person: CGImage, garment: CGImage, item: AvatarItem,
                    progress: @Sendable (TryOnProgress) -> Void) async throws -> CGImage
  }
  struct MobileVTONTryOn: RealisticTryOn {
      init(models: @Sendable (String) -> URL?, tokenizer: (vocab: URL, merges: URL),
           noise: [Float]? = nil, seed: UInt64 = 42)
  }
  ```

- [ ] **Step 1:** test sul Mac (`TEST_RUNNER_BENCH_ROOT` come in `GenerationMacTests`, `BENCH_MODELS=6bit`).
  - `testMatchesPythonCoreML`: la coppia di prova (foto del corpo e `cloth.jpg`) con `item.descriptor` = la descrizione della prova e `noise` = `noise.bin` deve stare a **≥ 35 dB** da `out/reference/coreml-6bit.png`, ricavata con `coreml_pipeline.py`. A `MobileVTONTryOn` le immagini arrivano senza bordo: il bordo e i tensori li calcola il motore.
  - `testCancellationStopsBetweenSteps`: annullando il `Task` dopo il 3° aggiornamento arriva `CancellationError` entro un passo e la cartella delle feature temporanee non resta.
  - `testProgressReachesOne`: l'ultimo `fraction` vale 1 e la sequenza cresce.
- [ ] **Step 2:** test FAIL.
- [ ] **Step 3:** implementa riprendendo le fasi di `BenchGenerator.run` (stessa struttura, stessi nomi di ingressi e uscite). Ingressi da `TryOnInputs`/`CLIPTokenizer` al posto dei `.bin`.
  - Unità: tutto `.cpuAndNeuralEngine`, `Denoiser` su `.cpuAndGPU`.
  - `try Task.checkCancellation()` prima di ogni chiamata a un modello.
  - Feature in una cartella temporanea unica per chiamata, cancellata con `defer`.
  - Risultato: `TryOnInputs.unpad` alla dimensione di `person`.
- [ ] **Step 4:** test PASS (sul Mac con `-destination 'platform=macOS'`, schema `RealisticBenchMac`), commit.

### Task 7: Composizione, cache e schermata

**Files:**
- Create: `ios/StyleVault/Realistic/GarmentMask.swift`
- Create: `ios/StyleVault/Realistic/RealisticCache.swift`
- Create: `ios/StyleVault/Realistic/RealisticAvatarModel.swift` (`@MainActor @Observable`, stato per vista)
- Modify: `ios/StyleVault/Avatar/AvatarComposer.swift` (parametro `overlay`)
- Modify: `ios/StyleVault/Avatar/CutoutCache.swift` (`cutout(image:key:allInstances:)`)
- Modify: `ios/StyleVault/Avatar/AvatarView.swift`
- Modify: `ios/project.yml` (entitlement `increased-memory-limit` sul target StyleVault, file `StyleVault/StyleVault.entitlements`)
- Test: `ios/StyleVaultTests/GarmentMaskTests.swift`, `ios/StyleVaultTests/RealisticAvatarModelTests.swift`

**Interfaces:**
- Produces:
  ```swift
  enum GarmentMask {
      /// Pixel dove il risultato cambia rispetto alla foto (stessa geometria): la parte di sopra nuova.
      static func make(original: CGImage, result: CGImage, threshold: UInt8 = 40) -> CGImage   // maschera in scala di grigi
  }
  // AvatarComposer.render(..., overlay: (image: CGImage, mask: CGImage)? = nil) — disegnato DOPO scarpe e pantaloni
  actor RealisticCache {
      static let shared: RealisticCache
      func image(item: AvatarItem, view: BodyView, bodyKey: String) -> CGImage?
      func store(_ image: CGImage, item: AvatarItem, view: BodyView, bodyKey: String)
  }   // Caches/realistic/<item.id>-<view>-<bodyKey>-v1.png
  enum RealisticState: Equatable { case collage, downloading(Double), preparing(Double), generating(Double), ready, failed(String), unsupported }
  @MainActor @Observable final class RealisticAvatarModel {
      init(engine: RealisticTryOn?, store: RealisticModelStore?, supported: Bool)
      private(set) var state: [BodyView: RealisticState]
      func start(_ view: BodyView, person: CGImage, garment: CGImage, item: AvatarItem, bodyKey: String) async
      func cancelAll()                       // chiusura della schermata o app in background
  }
  ```
  - **Capo realistico:** capospalla se c'è, altrimenti top. La foto è quella di `AvatarModel.garmentImageURL(item, view:)`, quindi di spalle il retro. Il capo scelto e il top sotto il capospalla non si disegnano più col collage.
  - **Una generazione alla volta:** `start` su un'altra vista mentre una gira viene ignorato, perché i pulsanti sono disabilitati.
  - **Composizione:**
    1. il risultato realistico prende il posto della foto del corpo (scontorno e posa ricalcolati con `CutoutCache.cutout(image:…)` e chiave `realistic-<…>`);
    2. si disegnano pantaloni e scarpe;
    3. si ridisegna `overlay` = risultato attraverso `GarmentMask`, solo dalla riga del collo alla riga delle ginocchia (dalla posa, così la maschera non tocca viso e piedi).

- [ ] **Step 1:** test.
  - `testMaskFindsChangedArea`: due immagini sintetiche uguali tranne un rettangolo → maschera bianca sul rettangolo (≥ 95%) e nera fuori (≥ 99%), con rumore di ±10 su tutta l'immagine.
  - `testMaskAlignsWithNon3x4Photo`: foto 600×1200 → `pad3x4`, poi il rettangolo cambiato nel 768×1024, poi `unpad`. La maschera cade nello stesso punto della foto originale (±2 px).
  - `testFrontStartsAloneOthersOnDemand`, con un motore finto: dopo `start(.front)` lo stato passa per `generating` e arriva a `ready`; `.side` e `.back` restano `.collage`.
  - `testUnsupportedNeverDownloads`: `supported: false` → `.unsupported`, nessuna chiamata allo store.
  - `testCancelAllReturnsToCollage`: motore finto lento + `cancelAll()` → `.collage` e nessuna immagine in cache.
  - `testOneGenerationAtATime`: `start(.side)` mentre `.front` è in `generating` → `.side` resta `.collage` e il motore viene chiamato una volta sola.
  - `testCacheHitSkipsEngine`: con l'immagine in `RealisticCache` → `.ready` senza chiamare il motore.
- [ ] **Step 2:** test FAIL.
- [ ] **Step 3:** implementa il modello di stato, la maschera (differenza massima per canale ≥ soglia, poi chiusura 5×5 e sfocatura di 2 px sul bordo), `overlay` in `AvatarComposer`, cache e `CutoutCache.cutout(image:)`.
- [ ] **Step 4:** in `AvatarView`:
  - davanti parte da sola;
  - barra con percentuale sotto l'immagine: "Scarico i modelli… 35% (420 MB di 1,2 GB)", "Preparo i modelli, solo la prima volta… 3/7", "Versione realistica… 40%";
  - "Genera di profilo" e "Genera di spalle" compaiono quando davanti è `.ready`;
  - errore → messaggio breve e si resta sul collage;
  - `.unsupported` → nota "La versione realistica richiede iPhone 15 Pro o successivo";
  - pulsante ⓘ → foglio "Crediti" con autori di Mobile-VTON, licenza CC BY-NC-SA 4.0 e link a `https://github.com/tmllab/2026_CVPR_Mobile-VTON`;
  - `onDisappear` e `scenePhase != .active` → `cancelAll()`.
- [ ] **Step 5:** test PASS (`StyleVaultTests` interi, 50 + nuovi) e commit.

### Task 8: Descrizione del capo dal sito

**Files:**
- Modify: `src/utils/nativeBridge.js` (`avatarPayload` aggiunge `descriptor: garmentDescriptor(item)` da `tryOnPrompt.js`)
- Modify: `src/utils/nativeBridge.test.js`
- Modify: `ios/StyleVault/Web/WebBridge.swift` (`AvatarItem.descriptor: String?`)
- Modify: `ios/StyleVaultTests/WebBridgeTests.swift`

- [ ] **Step 1:** test JS: un capo `{subcategory: 'sweater', colors: ['cream'], …}` → `descriptor === 'cream sweater'`. Test Swift: un payload senza `descriptor` si decodifica con `descriptor == nil`, mentre `"cream sweater"` si legge.
- [ ] **Step 2:** `npx vitest run src/utils/nativeBridge.test.js` e i test Swift. Atteso: FAIL.
- [ ] **Step 3:** implementa.
- [ ] **Step 4:** test PASS, commit. Il deploy del sito si fa solo con l'ok di Lorenzo. L'app funziona anche prima: in quel caso la descrizione è il nome del capo.

### Task 9: Prova sui dispositivi e chiusura

**Files:**
- Modify: `docs/verifiche/2026-11-03-avatar-realistico/prova-tecnica.md` (sezione "Nell'app")
- Modify: `MEMORIA.md`, `docs/superpowers/specs/2026-11-03-avatar-realistico-design.md` (§3: decisione di pubblicazione gratuita)

- [ ] **Step 1:** con la Release pubblicata (ok di Lorenzo), installa StyleVault sul 18 Pro Max (`xcrun devicectl device install app --device 00008160-000661061A200036 …`) e verifica i punti del design §7:
  1. al primo "Vedilo addosso" barra del download, poi preparazione, poi davanti realistico; a regime ≤ 60 s;
  2. "Genera di profilo" e "Genera di spalle";
  3. riaprendo lo stesso outfit le viste compaiono subito;
  4. pantaloni e scarpe al loro posto, con l'orlo della parte di sopra sopra i pantaloni;
  5. chiudendo a metà, o mandando l'app in background, nessun blocco.

  Salva una schermata di ogni vista in `docs/verifiche/2026-11-03-avatar-realistico/app-*.png`.
- [ ] **Step 2:** stessa prova sul **15 Pro di Mary**: ≤ 90 s, nessuna chiusura per memoria. Se non passa, torna da Lorenzo prima di pubblicare.
- [ ] **Step 3:** aggiorna resoconto, design e MEMORIA.md, poi chiedi a Lorenzo commit e push.

## Fuori da questo piano

- **Pubblicazione sull'App Store**: serve l'Apple Developer Program (99 €/anno; con l'Apple ID gratuito l'app dura 7 giorni). Servono anche scheda, privacy (le foto non escono dal telefono per il realistico) ed età. Va fatta con Lorenzo, dopo questo piano.
- Pantaloni, gonne e scarpe realistici; tipo di avatar sul sito.
