# FASHN VTON v1.5: strumenti della prova tecnica

Prova del 04-05/11/2026: capire se FASHN VTON v1.5 può sostituire Mobile-VTON
nell'app nativa, visto che i dati di addestramento di Mobile-VTON hanno una
licenza solo ricerca (report di pubblicazione, sezione 00).

**Esito: sul Mac funziona, su iPhone e iPad non è stato provato.** Nessun
numero qui sotto dice quanto ci mette un telefono, né se ci sta in memoria.

## Licenze

| Pezzo | Licenza | Nota |
|---|---|---|
| Codice e pesi FASHN VTON | Apache 2.0 | 18 milioni di coppie di addestramento, origine non dichiarata |
| FASHN Human Parser | NVIDIA SegFormer, solo ricerca o valutazione | **Escluso**: lo sostituisce un finto modulo in `common.py` |
| DWPose + YOLOX | Apache 2.0 | Dati di addestramento non verificati; Apple Vision da provare al loro posto |

Il parser serve solo con le maschere. Con `segmentation_free=True` e
`garment_photo_type="flat-lay"` la pipeline ne ignora l'uscita.

## Cosa non è nel repo

Codice e pesi stanno nella cartella della prova, indicata da `FASHN_SPIKE`:
`repo/`, `weights/`, `venv/`. Quella del 04/11 è in una cartella temporanea e un
riavvio la cancella. Per rifarla:

- codice: `github.com/fashn-ai/fashn-vton-1.5`, commit `7c0f10a`;
- pesi: `fashn-ai/fashn-vton-1.5` (`model.safetensors`, 1,94 GB) e
  `fashn-ai/DWPose` su Hugging Face (`yolox_l.onnx`, `dw-ll_ucoco_384.onnx`);
- ambiente: Python 3.12, torch 2.7.0, coremltools 9.0, **numpy 2.3.5**,
  scikit-learn 1.9.1. coremltools 9.0 non funziona con numpy 2.5.

Tutto ciò che producono gli script finisce in `out/`, ignorata da git.

## Script

| Script | Cosa fa |
|---|---|
| `common.py` | percorsi, coppia di prova (la stessa di Mobile-VTON), finto parser |
| `guard.sh <minuti> <comando>` | lancia un comando pesante a priorità bassa e lo ferma per tempo, swap o memoria |
| `reference.py` | cattura gli ingressi del trasformatore in `out/inputs.npz`; misura un passaggio PyTorch |
| `convert_coreml.py` | conversione in Core ML fp16, un passaggio a batch 1 |
| `palettize.py` | compressione a 6 bit, stessa palette di Mobile-VTON |
| `coreml_pipeline.py` | generazione intera sugli ingressi catturati; tempi e PSNR |

**Sempre con `guard.sh`.** Il 04/11 una generazione senza limiti ha fatto
riavviare il Mac. Limiti usati: `MAX_SWAP_MB=5000`, e su MPS
`PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.75 PYTORCH_MPS_LOW_WATERMARK_RATIO=0.6`.

## Riscritture per Core ML

Core ML accetta tensori fino a 5 dimensioni. In `convert_coreml.py`:

- `apply_rope` lavora su `[cos, sin]` invece che sulle matrici di rotazione;
- l'ultimo passaggio di forma usa `pixel_shuffle` invece di `rearrange`.

`check_rewrites` le confronta con gli originali a ogni lancio: differenza 0,0.

## Risultati sul Mac (M1 Pro, 16 GB)

Maglione su foto a figura intera, 30 passi, CFG 1,5, 59 passaggi del modello.

| Modello | Dove gira | Dimensione | Tempo a passo | Totale | Primo passo | Qualità |
|---|---|---|---|---|---|---|
| fp16 | GPU | 1,8 GB | 7,3 s | 219,8 s | 8,2 s | riferimento |
| 6 bit | GPU | 704 MB | 8,5 s | 265,5 s | 20,2 s | 38,3 dB dal fp16 |

- Il tempo a passo è una media senza il primo passo. L'ultimo passo, senza CFG,
  usa un passaggio solo e dura circa la metà.
- Le due generazioni non sono confrontabili al secondo: il Mac era occupato da
  altre sessioni. Non dimostrano che il 6 bit sia più lento.
- Neural Engine, fp16, 3 passi: 11,3 s a passo, contro 7,2 s della GPU. Non è
  verificato quanta parte giri davvero sul Neural Engine.
- PyTorch MPS fp16, un passaggio: 4,76 s. A 59 passaggi con CFG a batch 2 è
  stato fermato da `guard.sh` per lo swap. Quindi **manca il confronto PSNR
  con PyTorch**: la conversione è verificata passo per passo, non sull'immagine.
- Compressione: 200 s, swap fino a 2,2 GB.

A occhio il capo è giusto: maniche lunghe, polsini, trecce riconoscibili. Viso,
pantaloncini, orologio e scarpe restano intatti. Limiti: le trecce sono
irregolari al centro, il logo ricamato sparisce, e il 6 bit aggiunge una trama
leggera nel fondo grigio. In entrambe le versioni si vede un bordo orizzontale
netto sul petto, dove iniziano le trecce.

Le pose sono state calcolate sul Mac e catturate in `inputs.npz`: **DWPose non è
stato convertito**, quindi la catena intera sul dispositivo non esiste ancora.

## Confronto con Mobile-VTON

| | Mobile-VTON | FASHN VTON |
|---|---|---|
| Licenza dei pesi | CC BY-NC-SA 4.0 | Apache 2.0 |
| Dati di addestramento | DressCode (solo ricerca), VITON-HD | non dichiarati |
| Parametri | 415 milioni | 972 milioni |
| Passaggi per immagine | 10 passi | 59 |
| Peso a 6 bit | 1,3 GB, tutti i pezzi | 704 MB, senza le pose |
| iPhone 18 Pro Max | 21,4 s, misurato | non provato |
| iPad Pro 13" M4 | 36,3 s, misurato | non provato |
| Memoria a 6 bit | 2,4 GB | non misurata |

## Cosa manca

1. Misura su iPhone e iPad: tempo e memoria di picco, con un passaggio solo.
   Serve un dispositivo di Lorenzo e un adattamento di `ios/RealisticBench`.
2. Pose sul dispositivo: Apple Vision al posto di DWPose, poi confronto.
3. Origine dei dati di addestramento: chiederla a FASHN prima di pubblicare.
