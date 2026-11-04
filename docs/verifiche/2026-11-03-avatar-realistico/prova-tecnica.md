# Prova tecnica — Mobile-VTON in Core ML sull'iPhone

Data: 2026-11-03/04 (notte). Piano: `docs/superpowers/plans/2026-11-03-avatar-realistico-prova-tecnica.md`.
Registro dettagliato: `.superpowers/sdd/2026-11-03-avatar-realistico-prova-tecnica/progress.md`.

Coppia di prova fissa per tutte le misure: foto davanti a figura intera + maglione
color crema, 10 passi, seed 42, guida 2,5.

## In breve

| Domanda | Risposta |
|---|---|
| Si converte in Core ML? | **Sì**, tutti e 7 i pezzi, con le stesse uscite del modello originale |
| La qualità regge? | **Sì**: fp16 a 33,0 dB, 6 bit a 31,8 dB contro PyTorch, uguali a occhio |
| Quanto pesa? | 3,1 GB in fp16, **1,2 GB a 6 bit** (obiettivo del design: ~1 GB) |
| Sta nei 60 s sul 18 Pro Max? | **Sì: 25 s** misurati a 6 bit in modalità mista (~21 s attesi con la copia veloce della notte) |
| Sta nei 90 s sul 15 Pro di Mary? | **Da misurare** (serve il telefono) |
| Memoria | picco 2,4 GB a 6 bit (con `increased-memory-limit`: 6,1 GB disponibili sul 18 Pro Max) |
| Primo avvio | ~3,7 min di preparazione per il Neural Engine, una volta dopo l'installazione |

## Conversione e qualità (Mac)

| Modello | fp16 | 6 bit | Coseno fp16 | Coseno 6 bit |
|---|---|---|---|---|
| TextEncoder (CLIP-L) | 236 MB | 90 MB | 0,99998 | 0,99797 |
| TextEncoder2 (CLIP-G) | 1325 MB | 501 MB | 1,00000 | 0,99764 |
| ImageEncoder (DINOv2 + proiezione) | 222 MB | 85 MB | 1,00000 | 0,99991 |
| VAEEncoder | 66 MB | 25 MB | 1,00000 | 1,00000 |
| DenoiserGarment (UNet del capo) | 608 MB | 234 MB | 0,99999 | 0,99851 |
| Denoiser (UNet di prova) | 730 MB | 284 MB | 1,00000 | 0,99953 |
| VAEDecoder | 4 MB | 4 MB (non compresso) | 1,00000 | 1,00000 |
| **Totale** | **3,1 GB** | **1,2 GB** | | |

Immagine intera rifatta coi soli modelli Core ML (`coreml_pipeline.py`):
PSNR **32,99 dB** (fp16) e **31,83 dB** (6 bit) contro PyTorch — soglia 30 dB.
Confronto: `pytorch-fp16-6bit.jpg` (PyTorch, fp16, 6 bit).

Correzioni necessarie alla conversione:
- DINOv2: l'interpolazione bicubica delle posizioni non esiste in Core ML → posizioni
  per 224×224 calcolate una volta e incollate.
- UNet del capo: le feature 8–11 sono gli stessi tensori delle 12–15 → il modello ne
  dà 24, l'app ricopia le 12–15 nelle 8–11.

## Tempi sull'iPhone 18 Pro Max (app `RealisticBench`)

Tempi di 10 passi **veri** (timestep che cambia, uscita letta): con ingressi
identici ripetuti Core ML ricicla il lavoro e i tempi escono falsamente bassi.

| Modelli | Unità | 10 passi | Vista davanti | Picco memoria | Esito |
|---|---|---|---|---|---|
| fp16 | solo Neural Engine | — | — | — | il Denoiser non si prepara (>50 min) |
| fp16 | solo GPU | 27,6 s | 30,0 s | 2,8 GB | passa |
| fp16 | **mista** (ANE + Denoiser su GPU) | 22,7 s | 23,2 s | 4,0 GB | passa |
| 6 bit | **mista** | 24,4 s | **25,0 s** | **2,4 GB** | **passa** |
| 6 bit | solo Neural Engine | — | — | — | Denoiser non pronto dopo 5 min (prova interrotta) |

Per passo, 6 bit mista: UNet del capo 0,21 s (Neural Engine), UNet di prova 1,79 s
(GPU), preparazione delle feature 0,44 s.

Primo avvio dopo l'installazione (una volta, poi in cache): 224 s di preparazione
a 6 bit in modalità mista (VAEEncoder 110 s, UNet del capo 81 s sul Neural Engine).

Cose imparate sul telefono:
- Senza l'entitlement `com.apple.developer.kernel.increased-memory-limit` la UNet del
  capo va in crash sulla GPU (MPSGraph: heap nil). Con l'entitlement (concesso anche
  all'Apple ID gratuito) l'app ha 6,1 GB.
- I 7 modelli caricati insieme non servono: la generazione va a fasi (testi + capo +
  VAE → le due UNet → decoder) liberando la memoria tra una fase e l'altra.
- Ricreare a ogni passo gli ingressi della UNet di prova (300 MB) costava 80 s su
  10 passi: vanno preparati una volta e aggiornati sul posto.
- Apple ID gratuito: massimo 3 app firmate sul telefono.

## Generazione vera sul dispositivo

`RealisticBench` → "Genera la vista davanti" (o `--generate`) rifà tutta la catena
coi modelli Core ML e gli ingressi esportati dal Mac (`export_bench_inputs.py`):
token CLIP, pixel per DINOv2, foto, rumore col seed 42, sigma dello scheduler.
Restano da scrivere in Swift per l'app vera: tokenizzatore CLIP e preprocessing di
DINOv2 (piccoli, deterministici).

Verifica fatta sul Mac (test macOS `RealisticBenchMacTests`, stesso codice Swift e
stesso Core ML dell'app): l'immagine generata dal codice Swift è **identica pixel per
pixel** a quella dello script Python, sia in fp16 sia a 6 bit (`swift-mac-fp16.png`,
`swift-mac-6bit.png`).

Ottimizzazione della notte: le uscite della UNet del capo arrivano in fp16 e
finivano nella copia elemento per elemento. Con la copia veloce (vImage) la
preparazione delle feature scende da 21 s a 0,75 s su 10 passi sul Mac; sull'iPhone
valeva 4,4 s → attesi ~0,1 s.

### Una rete grande alla volta

La UNet del capo dipende solo dal passo, non dall'immagine che si sta formando:
le sue feature per i 10 passi si calcolano prima (fp16, su file riletti mappati,
che non pesano sullo swap), poi si libera e si carica la UNet di prova. Sul Mac:

| | Prima | Dopo |
|---|---|---|
| Memoria dopo i passi | 2,5 GB | **1,17 GB** |
| UNet del capo, per passo (GPU del Mac) | 3,8 s | **0,25 s** (di fila la GPU non deve ripreparare due reti) |
| Immagine | — | identica byte per byte |

Da verificare sul telefono se anche lì la UNet del capo accelera.

### Simulatori

**iPhone 18 Pro Max (simulatore): generazione completa riuscita** — 553 s sulla
CPU del simulatore, immagine a 44,7 dB da quella del Mac (CPU contro GPU) e a
33,0 dB dal modello originale (`simulatore-iphone-fp16.png`,
`simulatore-iphone-schermata.png`).

Cosa è servito per arrivarci, sul Mac da 16 GB:
- modelli **fp16**: col 6 bit il simulatore scompatta i pesi sulla CPU un elemento
  alla volta (oltre 30 minuti per il primo modello; sul telefono: secondi);
- **una rete alla volta** e feature su file mappati (sopra);
- **`--units cpu`**: in modalità GPU il simulatore passa dal Metal del Mac e alla
  prima UNet di prova iOS chiude l'app per swap del Mac esaurito.

Il simulatore iPhone 18 Pro era occupato dai test UI di Fitness Hub (un'altra
sessione), l'iPad dai test UI di Vocali. Due volte ho disturbato per pochi secondi
i test di Vocali: avviando la misura sull'iPad (fermata subito) e, nel controllo
finale, i test StyleVault sul 18 Pro Max dove Vocali si era appena spostata.

**iPad Pro 13" M5 (simulatore creato apposta e poi cancellato): generazione completa
riuscita** — 603 s, immagine **identica pixel per pixel** a quella del simulatore
iPhone, 33,0 dB dal modello originale (`simulatore-ipad-fp16.png`,
`simulatore-ipad-schermata.png`). L'app riconosce da sola l'iPad (soglia: 60 s come
il 18 Pro Max, il design non la prevedeva).

Cosa dicono i simulatori: la catena Swift (testi, capo, VAE, 10 passi con guida,
decoder, una rete alla volta) funziona su iOS e iPadOS 27.2 e dà la stessa immagine
del Mac. I **tempi** non contano: il simulatore usa solo la CPU del Mac, niente Neural
Engine né GPU del telefono.

## Da fare prima della decisione

1. **iPhone 18 Pro Max**: generazione vera (`--generate`) e misura con la copia veloce.
2. **iPad di Lorenzo**: stessa prova (va registrato nel team al primo collegamento).
3. **iPhone 15 Pro di Mary** (8 GB): misura e generazione, 6 bit, modalità mista —
   è il caso più stretto per memoria.
4. **UNet di prova a batch 1** (`Denoiser1`, guida in due chiamate: metà attivazioni,
   forse preparabile dal Neural Engine). Script e app pronti; la conversione importa
   Mobile-VTON, quindi la lancia Lorenzo:
   `"$SPIKE/venv-convert/bin/python" -I tools/avatar-realistico/convert_coreml.py "$SPIKE/repo" "$SPIKE/weights/checkpoint" --only Denoiser1`,
   poi `verify_components.py --only Denoiser1 --units CPU_AND_GPU`, `palettize.py --only Denoiser1`
   e l'app con `--split`.
5. Facoltativo: "solo Neural Engine" a 6 bit lasciando al Denoiser più tempo; e la
   VAEEncoder sulla GPU per tagliare i 110 s di preparazione al primo avvio.

## Proposta

Sul 18 Pro Max la prova **passa con ampio margine** (25 s contro 60). Se domani
passa anche il 15 Pro di Mary (soglia 90 s, senza chiusure per memoria), propongo di
scrivere il piano d'integrazione con questa configurazione:

- modelli a **6 bit** (1,2 GB da scaricare al primo uso, con barra);
- **modalità mista**: tutto sul Neural Engine, la UNet di prova sulla GPU;
- generazione **a fasi**, ingressi preparati una volta e copia veloce delle uscite;
- entitlement `increased-memory-limit`;
- al primo avvio una "preparazione" di ~4 minuti con barra (una volta sola);
- da scrivere in Swift: tokenizzatore CLIP, preprocessing DINOv2, scheduler (già
  fatto e testato in `BenchMath`).

Resta il vincolo di licenza (CC BY-NC-SA: niente uso commerciale) già scritto nel design.
