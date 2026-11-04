# Avatar realistico — strumenti della prova tecnica

Script per convertire **Mobile-VTON** (CVPR 2026) in Core ML e verificarne la
conversione, come da piano
`docs/superpowers/plans/2026-11-03-avatar-realistico-prova-tecnica.md`.

- Codice e pesi di Mobile-VTON **non** sono nel repo: stanno nella cartella
  della prova (`$SPIKE/repo`, `$SPIKE/weights/checkpoint`, venv in
  `$SPIKE/venv`). Licenza **CC BY-NC-SA 4.0**: solo uso non commerciale, e i
  modelli convertiti la ereditano.
- Gli script che importano il codice di Mobile-VTON (`capture_reference.py`,
  `convert_coreml.py`) li **lancia Lorenzo dal Terminale** (Claude Code non
  esegue codice scaricato); gli altri usano solo i modelli Core ML.
- Tutto ciò che producono finisce in `out/` (ignorata da git).

| Script | Cosa fa |
|---|---|
| `common.py` | caricamento del modello e coppia di prova fissa (persona davanti + maglione, 10 passi, seed 42) |
| `capture_reference.py` | immagine di riferimento PyTorch fp16 (in fp32 il Mac da 16 GB va in swap) e ingressi/uscite di ogni pezzo al passo 0 |
| `components.py` | i 7 modelli Core ML: nomi di ingressi/uscite e dati di verifica |
| `convert_coreml.py` | conversione in `.mlpackage` fp16 (venv di conversione con torch 2.7) |
| `verify_components.py` | confronto di ogni `.mlpackage` col riferimento (coseno, NaN, ordine delle feature) — non importa Mobile-VTON |
| `coreml_pipeline.py` | generazione intera con i modelli Core ML, tempo per pezzo e PSNR contro `reference.png` — non importa Mobile-VTON; sul Mac usare `--units CPU_AND_GPU` |
| `palettize.py` | compressione a 6 bit (palette k-means per gruppi di 16 canali) in `out/coreml-6bit/`; serve scikit-learn |
| `export_bench_inputs.py` | ingressi veri della coppia di prova per `RealisticBench --generate` in `out/bench-inputs/` |
| `export_tokenizer_cases.py` | casi di prova del tokenizzatore, `cloth-pixels.bin` e `cloth.jpg` per i test Swift in `ios/StyleVaultTests/Fixtures/realistic/` |
| `package_models.py` | un `.aar` per modello a 6 bit + `Tokenizer.aar`, `models-manifest.json` e `MODELS-LICENSE.md` in `out/release/` (per la Release `avatar-models-v1`) |

## RealisticBench sull'iPhone / iPad

App di misura in `ios/RealisticBench` (target XcodeGen, iOS 18, iPhone e iPad). I
modelli **non** sono nel bundle: si copiano una volta nella cartella dati
dell'app. Modelli compilati in `out/compiled-6bit/` e `out/compiled-fp16/`
(`xcrun coremlcompiler compile X.mlpackage cartella`).

```bash
DEV=<id del dispositivo>   # xcrun devicectl list devices
cd ios && xcodebuild build -project StyleVault.xcodeproj -scheme RealisticBench -configuration Release \
  -destination "id=$DEV" -derivedDataPath build/dd -allowProvisioningUpdates -allowProvisioningDeviceRegistration
xcrun devicectl device install app --device $DEV build/dd/Build/Products/Release-iphoneos/RealisticBench.app
cd ../tools/avatar-realistico
xcrun devicectl device copy to --device $DEV --domain-type appDataContainer \
  --domain-identifier it.faraoni.stylevault.bench --source out/compiled-6bit --destination Documents/Models-6bit
xcrun devicectl device copy to --device $DEV --domain-type appDataContainer \
  --domain-identifier it.faraoni.stylevault.bench --source out/bench-inputs --destination Documents/Inputs
# misura (tempi per pezzo + 10 passi veri) o generazione vera
xcrun devicectl device process launch --device $DEV --console it.faraoni.stylevault.bench --units mix --models 6bit
xcrun devicectl device process launch --device $DEV --console it.faraoni.stylevault.bench --units mix --models 6bit --generate
# immagine generata
xcrun devicectl device copy from --device $DEV --domain-type appDataContainer \
  --domain-identifier it.faraoni.stylevault.bench --source Documents/Output/generata-Models-6bit.png --destination out/
```

`--units`: `ane`, `gpu` o `mix` (tutto sul Neural Engine, UNet di prova sulla GPU).
Apple ID gratuito: massimo 3 app firmate per dispositivo.

Generazione Swift sul Mac (stesso codice dell'app, senza simulatore):

```bash
cd ios && TEST_RUNNER_BENCH_ROOT=<cartella con Models-6bit/ e Inputs/> TEST_RUNNER_BENCH_MODELS=Models-6bit \
  xcodebuild test -project StyleVault.xcodeproj -scheme RealisticBenchMac -destination 'platform=macOS' -derivedDataPath build/dd
```
