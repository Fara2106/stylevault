# Avatar realistico — Prova tecnica Core ML Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sapere, con misure vere, se Mobile-VTON convertito in Core ML sta nelle soglie del design sull'iPhone 18 Pro Max di Lorenzo e sull'iPhone 15 Pro di Mary, prima di costruire l'integrazione nell'app.

**Architecture:** Script Python nel repo (`tools/avatar-realistico/`) catturano dal modello PyTorch gli ingressi/uscite di riferimento, convertono ogni pezzo in `.mlpackage` (fp16, poi palettizzato 6 bit) e verificano la conversione sul Mac rifacendo l'intera generazione con Core ML. Una piccola app iOS di misura (`RealisticBench`, target XcodeGen separato) carica i modelli convertiti sull'iPhone e misura tempi per pezzo e memoria. Il piano dell'integrazione nell'app si scrive solo dopo il cancello del Task 6, con le interfacce misurate qui.

**Tech Stack:** Python 3.11 + PyTorch 2.15 (MPS) + coremltools 9; Swift/SwiftUI + Core ML; XcodeGen.

**Spec:** `docs/superpowers/specs/2026-11-03-avatar-realistico-design.md` (§6.1 è questa prova)

## Global Constraints

- **Codice esterno**: ogni comando che importa `Mobile_VTON` (codice scaricato) lo lancia **Lorenzo dal Terminale**; Claude Code scrive gli script e legge i risultati. Il classificatore blocca l'esecuzione da parte dell'agente: non aggirarlo.
- Pesi, venv e `.mlpackage` (GB) **mai in git**: stanno in `$SPIKE` = `…/scratchpad/spike-mvton` (pesi in `$SPIKE/weights/checkpoint`, codice in `$SPIKE/repo`) e `ios/RealisticBench/Models/` (ignorata).
- Coppia di prova fissa: persona `ios/build/foto-corpo-test/1-davanti.jpg` (figura intera, portata a 3:4 768×1024 con bordo bianco), capo `ios/StyleVaultTests/Fixtures/maglione.jpg`, descrizione "The item is a cream white cable-knit crew neck sweater with long sleeves, ribbed cuffs and hem, made of a soft chunky wool knit.", seed 42, **10 passi**, guidance 2.5, scheduler FlowMatchEuler shift 3.0.
- Soglie (design §6.1): vista davanti completa **≤ 60 s sul 18 Pro Max** (`00008160-000661061A200036`), **≤ 90 s sul 15 Pro** di Mary, nessuna chiusura per memoria sul 15 Pro.
- Licenza Mobile-VTON CC BY-NC-SA 4.0: niente uso commerciale; i file convertiti la ereditano.
- Simulatore condiviso: test iOS solo con `-destination 'id=18361580-2FC8-4A18-AED3-7461008C6569'` e `CODE_SIGNING_ALLOWED=NO`.
- Commit in italiano con `Co-Authored-By: Claude …`; commit e push solo con l'ok di Lorenzo.

## Review Focus

1. **Conversione "silenziosamente sbagliata"**: un pezzo convertito che gira ma dà numeri diversi (attenzione, normalizzazioni in fp16) → immagine finale rovinata. Va pinnata confrontando ogni pezzo col riferimento PyTorch fp32 (Task 2) e l'immagine finale (Task 3).
2. **Uscite multiple della UNet del capo** (`garment_features`, una lista di tensori) che passano nella UNet di prova: ordine e forme devono restare identici dopo la conversione (Task 2, test sull'ordine).
3. **Memoria di picco**: i pezzi caricati insieme possono superare il limite di iOS sul 15 Pro anche se ognuno da solo ci sta → misurare il picco con tutti i modelli caricati come nella generazione vera (Task 5).
4. **Prima esecuzione molto più lenta** (compilazione Core ML sul dispositivo): va misurata a parte e non confusa col tempo a regime (Task 5).
5. **Unità di calcolo**: Neural Engine e GPU danno tempi molto diversi e a volte risultati diversi; misurare `.cpuAndNeuralEngine` e `.cpuAndGPU` (Task 5).

---

### Task 1: Riferimento PyTorch e forme dei tensori

**Files:**
- Create: `tools/avatar-realistico/README.md` (cosa sono gli script, licenza, che li lancia Lorenzo)
- Create: `tools/avatar-realistico/common.py` (caricamento modelli e preparazione della coppia di prova, riusato da tutti gli script)
- Create: `tools/avatar-realistico/capture_reference.py`
- Modify: `.gitignore` (aggiungi `tools/avatar-realistico/out/`, `ios/RealisticBench/Models/`)

**Interfaces:**
- Produces: `common.load_pipeline(weights: str, dtype: torch.dtype, device: str) -> Pipe`; `common.test_inputs() -> dict` (persona e capo 768×1024, testi); cartella `tools/avatar-realistico/out/reference/` con `shapes.json` (nome pezzo → forme e dtype di ogni ingresso/uscita, per un passo), `step0_<pezzo>_in.npz` / `_out.npz` (ingressi/uscite del passo 0 di: `denoiser_garment`, `denoiser`, `vae_encode`, `vae_decoder`, `image_encoder`, `text_encoder`, `text_encoder_2`), `reference.png` (immagine finale, fp32, 10 passi).

- [ ] **Step 1:** Scrivi `capture_reference.py`: carica la pipeline in **fp32 su MPS**, registra con hook `forward` ingressi/uscite di ogni pezzo al primo passo (per `denoiser_garment` tutte le `garment_features` in ordine), salva `shapes.json`, gli `.npz` e `reference.png`. I parametri della generazione sono quelli dei Global Constraints.
- [ ] **Step 2:** Lorenzo lancia `"$SPIKE/venv/bin/python" -I tools/avatar-realistico/capture_reference.py "$SPIKE/repo" "$SPIKE/weights/checkpoint"`. Atteso: stampa le forme (es. `denoiser.sample [2, 32, 256, 96]`, `prompt_embeds [2, N, 4096]`) e crea `out/reference/reference.png` con il maglione addosso.
- [ ] **Step 3:** Guarda `reference.png`: dev'essere come la prova "figura intera" del 2026-11-03. Copialo in `docs/verifiche/2026-11-03-avatar-realistico/riferimento-pytorch.png` insieme ai confronti della prova usa-e-getta (`confronto-davanti.jpg`, `confronto-3.jpg`).
- [ ] **Step 4:** Commit (con l'ok di Lorenzo): `tools/avatar-realistico/`, `.gitignore`, `docs/verifiche/2026-11-03-avatar-realistico/`.

### Task 2: Conversione in Core ML (fp16) e verifica pezzo per pezzo

**Files:**
- Create: `tools/avatar-realistico/convert_coreml.py`
- Create: `tools/avatar-realistico/verify_components.py`

**Interfaces:**
- Consumes: `common.load_pipeline`, `out/reference/shapes.json` e `.npz` (Task 1).
- Produces: `out/coreml-fp16/{DenoiserGarment,Denoiser,VAEEncoder,VAEDecoder,ImageEncoder,TextEncoder,TextEncoder2}.mlpackage` con forme fisse da `shapes.json`; nomi di ingressi/uscite = nomi in `shapes.json` (le `garment_features` diventano uscite `garment_feature_0…K` in ingresso al `Denoiser` con gli stessi nomi). `verify_components.py` stampa per pezzo: similarità coseno e errore massimo rispetto al riferimento.

- [ ] **Step 1:** Scrivi `verify_components.py` prima della conversione: per ogni `.mlpackage` presente esegue `predict` sugli ingressi di `step0_<pezzo>_in.npz` e confronta con `_out.npz`. **Passa** se coseno ≥ 0.999 e nessun NaN; per `Denoiser` controlla anche che l'ordine delle `garment_feature_k` sia quello del riferimento (scambiandone due il coseno deve crollare: verificalo una volta e annota il risultato).
- [ ] **Step 2:** Lorenzo lancia `verify_components.py` senza modelli: atteso "0 pezzi trovati", nessun errore.
- [ ] **Step 3:** Scrivi `convert_coreml.py`: per ogni pezzo un wrapper `nn.Module` con ingressi/uscite piatti (niente dict/liste), `torch.jit.trace` con le forme di `shapes.json`, `coremltools.convert(..., convert_to="mlprogram", compute_precision=ct.precision.FLOAT16, minimum_deployment_target=ct.target.iOS17)`. L'attenzione resta quella del repo (`AttnProcessor2_0`, niente xformers).
- [ ] **Step 4:** Lorenzo installa coremltools nel venv (`VIRTUAL_ENV="$SPIKE/venv" uv pip install coremltools`) e lancia `convert_coreml.py`, poi `verify_components.py`. Atteso: 7 pezzi, tutti PASS. Se un pezzo fallisce: annota quale e perché (operazione non supportata / numeri diversi) e torna da Lorenzo prima di proseguire — è già un'informazione da cancello.
- [ ] **Step 5:** Commit degli script.

### Task 3: Generazione intera con Core ML sul Mac

**Files:**
- Create: `tools/avatar-realistico/coreml_pipeline.py`

**Interfaces:**
- Consumes: `.mlpackage` del Task 2 (o del Task 4 con `--models out/coreml-6bit`), `common.test_inputs()`.
- Produces: `out/coreml-<variante>.png` e stampa del tempo per pezzo sul Mac.

- [ ] **Step 1:** Scrivi `coreml_pipeline.py`: rifà il ciclo di `tryon_pipeline_full_cat.py` (righe ~1330–1440: concatenazione lungo l'altezza `concat_dim=-2`, guida con `torch.zeros_like` per le feature del capo nel ramo incondizionato, scheduler `FlowMatchEulerDiscreteScheduler(shift=3.0)` di diffusers, decodifica con `(latents / 1.5305) + 0.0609`) chiamando i `.mlpackage` al posto dei moduli PyTorch. Nessun import di `Mobile_VTON.models` (solo scheduler e pre/post-processing).
- [ ] **Step 2:** Lorenzo lancia `coreml_pipeline.py --models out/coreml-fp16`. Atteso: `out/coreml-fp16.png` visivamente uguale a `reference.png` (stesso seed) e PSNR ≥ 30 dB rispetto a `reference.png` (lo script lo stampa).
- [ ] **Step 3:** Copia l'immagine in `docs/verifiche/2026-11-03-avatar-realistico/coreml-fp16.png`; commit.

### Task 4: Compressione a 6 bit

**Files:**
- Create: `tools/avatar-realistico/palettize.py`

**Interfaces:**
- Consumes: `out/coreml-fp16/*.mlpackage`.
- Produces: `out/coreml-6bit/*.mlpackage` (stessi nomi e interfacce) e stampa della dimensione totale.

- [ ] **Step 1:** Scrivi `palettize.py` con `coremltools.optimize.coreml.palettize_weights` (`OpPalettizerConfig(mode="kmeans", nbits=6)`), escludendo i pezzi sotto 50 MB.
- [ ] **Step 2:** Lorenzo lancia `palettize.py`, poi `verify_components.py --models out/coreml-6bit` e `coreml_pipeline.py --models out/coreml-6bit`. Atteso: dimensione totale stampata (obiettivo design ~1 GB; annota il valore vero), coseno ≥ 0.99 per pezzo, immagine 6 bit ancora "da maglione vero" a occhio (PSNR stampato e annotato).
- [ ] **Step 3:** Copia `coreml-6bit.png` nelle verifiche; commit. Se a 6 bit la qualità crolla, prova 8 bit (`nbits=8`) e annota entrambe.

### Task 5: App di misura sull'iPhone (`RealisticBench`)

**Files:**
- Modify: `ios/project.yml` (nuovo target `RealisticBench`, app iOS 17, bundle `it.faraoni.stylevault.bench`, team `599MS2BZ63`, risorse `RealisticBench/Models/*.mlpackage`; target test `RealisticBenchTests`)
- Create: `ios/RealisticBench/BenchApp.swift` (schermata: pulsante "Misura", unità di calcolo scelta, risultati in testo, stampa in console con prefisso `SVBENCH`)
- Create: `ios/RealisticBench/BenchRunner.swift`
- Create: `ios/RealisticBench/BenchEstimate.swift`
- Test: `ios/RealisticBenchTests/BenchEstimateTests.swift`

**Interfaces:**
- Consumes: i 7 `.mlpackage` (fp16 o 6 bit) copiati da `tools/avatar-realistico/out/coreml-<variante>/` in `ios/RealisticBench/Models/`.
- Produces: per ogni unità di calcolo (`.cpuAndNeuralEngine`, `.cpuAndGPU`): tempo della **prima** esecuzione e mediana di 3 esecuzioni a regime per pezzo, memoria di picco (`phys_footprint` da `task_info`) con tutti i modelli caricati, stima della vista davanti completa.

- [ ] **Step 1: Test che fallisce** — `BenchEstimateTests.testStimaVistaDavanti`:

```swift
let t = BenchTimes(textEncoder: 0.2, textEncoder2: 0.5, imageEncoder: 0.3, vaeEncoder: 0.4,
                   denoiserGarment: 1.0, denoiser: 2.0, vaeDecoder: 0.6)
// 2 codifiche VAE (persona e capo), 10 passi ognuno con UNet capo + UNet prova
XCTAssertEqual(BenchEstimate.frontView(t, steps: 10), 0.2 + 0.5 + 0.3 + 2 * 0.4 + 10 * (1.0 + 2.0) + 0.6, accuracy: 1e-9)
XCTAssertTrue(BenchEstimate.passes(seconds: 59, device: .iPhone18ProMax))
XCTAssertFalse(BenchEstimate.passes(seconds: 61, device: .iPhone18ProMax))
XCTAssertTrue(BenchEstimate.passes(seconds: 90, device: .iPhone15Pro))
```

- [ ] **Step 2:** `xcodegen generate` e `xcodebuild test -scheme RealisticBench -destination 'id=18361580-2FC8-4A18-AED3-7461008C6569' CODE_SIGNING_ALLOWED=NO` → FAIL (`BenchEstimate` non esiste).
- [ ] **Step 3:** Implementa `struct BenchTimes` (i 7 campi `Double`, secondi), `enum BenchDevice { case iPhone18ProMax, iPhone15Pro }`, `enum BenchEstimate { static func frontView(_: BenchTimes, steps: Int) -> Double; static func passes(seconds: Double, device: BenchDevice) -> Bool }` con soglie 60 / 90 s.
- [ ] **Step 4:** Rilancia il test → PASS.
- [ ] **Step 5:** Implementa `BenchRunner.measure(units: MLComputeUnits) async -> (BenchTimes, firstRun: BenchTimes, peakMemoryMB: Double)`: carica i 7 modelli **insieme** dal bundle, crea ingressi casuali con le forme dichiarate dal modello (`MLMultiArray` fp16), misura come da Interfaces. La UNet di prova riceve le `garment_feature_k` uscite dalla UNet del capo (non casuali), così l'interfaccia tra le due è esercitata.
- [ ] **Step 6:** Copia i modelli 6 bit in `ios/RealisticBench/Models/`, compila e installa sull'iPhone di Lorenzo (`xcodebuild build -scheme RealisticBench -destination 'id=00008160-000661061A200036' -allowProvisioningUpdates`, `devicectl device install app`, `devicectl device process launch --console`), tocca "Misura" per entrambe le unità. Atteso in console: righe `SVBENCH` con tempi, picco di memoria e "PASSA/NON PASSA". Ripeti con fp16 se il 6 bit è stato scartato nel Task 4.
- [ ] **Step 7:** Stesso sull'**iPhone 15 Pro di Mary** (va collegato al Mac, Modalità sviluppatore attiva, registrato nel team: `-allowProvisioningDeviceRegistration`). Atteso: nessuna chiusura per memoria; tempi e PASSA/NON PASSA in console.
- [ ] **Step 8:** Commit di `ios/RealisticBench*` e `ios/project.yml`.

### Task 6: Cancello — risultati e decisione con Lorenzo

**Files:**
- Create: `docs/verifiche/2026-11-03-avatar-realistico/prova-tecnica.md` (tabella: pezzo × unità × telefono, prima esecuzione e regime, memoria di picco, stima vista davanti, PASSA/NON PASSA; dimensioni fp16 e 6 bit; immagini Task 1/3/4)
- Modify: `MEMORIA.md` (sezione app iOS: esito della prova tecnica)
- Modify: `docs/superpowers/specs/2026-11-03-avatar-realistico-design.md` (§6.1: risultati misurati; eventuale decisione su codificatori di testo sul Mac)

- [ ] **Step 1:** Scrivi `prova-tecnica.md` con i numeri dei Task 2–5.
- [ ] **Step 2:** Presenta a Lorenzo: passa / non passa sui due telefoni, qualità 6 bit vs PyTorch, e la proposta (procedere col piano d'integrazione, oppure fermarsi / alternative del design §1).
- [ ] **Step 3:** Se Lorenzo dice di procedere: scrivi con superpowers:writing-plans il piano `docs/superpowers/plans/2026-11-xx-avatar-realistico-app.md` (download con barra, `RealisticTryOn`, schermata, cache, composizione con pantaloni e scarpe), usando i nomi e le forme reali dei `.mlpackage`.
- [ ] **Step 4:** Commit dei documenti (con l'ok di Lorenzo).
