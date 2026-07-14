# Smistatore dello scontorno capi — design

**Data:** 2026-07-14 (rev. 2 — percorso tutto gratis, on-device)
**Stato:** Piano 1 implementato e verde. Piano 2 (scontorno gratis) da scrivere.

## Problema

In modalità PIATTA i capi non vestono il manichino: compaiono le **foto grezze**
degli screenshot con la UI del sito (badge "PROMO", prezzo, barra di stato,
modella). Segnalato dall'utente sul sito live.

### Causa radice (investigata e riprodotta)

L'utente aggiunge i capi **caricando screenshot** di app di shopping. Lo scontorno
in [`garmentTexture.js`](../../../src/utils/garmentTexture.js) usa un **riempimento
dai 4 angoli**: "sfondo = ciò che è raggiungibile da un angolo con colore simile;
capo = tutto il resto". Funziona su una foto pulita di un capo su fondo uniforme;
**fallisce su uno screenshot**, che è un collage: tutto ciò che non è raggiungibile
dagli angoli — foto del capo **+ badge + prezzo + UI** — viene marcato come "capo".
Il ritaglio (`textureUrl`) è lo screenshot intero, che
[`AvatarSvg.jsx`](../../../src/components/Avatar/AvatarSvg.jsx) incolla sul
manichino senza clip. La rete di sicurezza esistente (`coverage` fra 0.02 e 0.92)
**non scatta**: un'isola di contenuto sta comodamente nel range "valido".

**Punto chiave:** nessuna regolazione delle soglie del riempimento potrà mai
separare un capo da una UI arbitraria dentro uno screenshot. Serve o un input
migliore, o che sia **l'utente** a indicare quale è il capo.

## Vincolo e obiettivo

**Vincolo esplicito di Lorenzo: non spendere. Tutto gratis e on-device.**
Uno smistatore che, all'aggiunta del capo, riconosce il tipo di immagine e la manda
nel percorso migliore, con una rete di sicurezza sotto: l'app non mostra **mai** più
uno screenshot grezzo, e scontorna il capo gratis quando l'input lo permette.

## La scala (tutta gratis, on-device)

```
0. GUIDA AL RITAGLIO → l'utente inquadra/ritaglia solo il capo (idea di Lorenzo):
                       uno screenshot ritagliato stretto ≈ foto quasi-pulita
1. clean       → scontorno geometrico attuale (gratis, istantaneo)
2. messy       → bg-removal ML in-browser (@imgly, gratis, on-device)
3. screenshot / cutout sporco → TAP-TO-CUTOUT: l'utente tocca il capo, un modello di
                 segmentazione interattiva (SAM/MobileSAM/SlimSAM, WebGPU/WASM) lo
                 ritaglia (gratis, sul dispositivo)
4. render, capo senza ritaglio (backlog) → sagoma in tinta unita (backstop)
```

**Perché funziona senza spendere:** uno screenshot non si auto-scontorna gratis
perché la macchina non sa *quale* sia il capo nel collage. Se è **l'utente** a
dirlo — ritagliando a monte o con un **tap** — quel "quale" è risolto senza AI a
pagamento. La segmentazione interattiva (SAM) gira in-browser, gratis.

### Approccio C

La ML si innesta **solo sulla modalità piatta**; il **3D resta invariato** (pipeline
geometrica `garmentTexture.js` toccata zero). Blast radius minimo sulla parte live.
Condivisi il classificatore e il flusso; diverso solo il meccanismo di ritaglio.

## Il classificatore (Piano 1, FATTO)

`classifyGarmentImage(imageData) → { verdict: 'clean'|'messy'|'screenshot', islands,
text, reach }`. Modulo puro, testabile in Vitest.

**Segnali che separano davvero** (misurati su immagini vere il 2026-07-14):
- **Isole di contenuto** (componenti connesse del non-sfondo): capi reali 1–9,
  screenshot 52–145. Discrimina nettissimo.
- **Sfondo uniforme** (`reach`): screenshot 0.84–0.95 (pieni di chrome), capi bassi.
- Il **testo** NON separa: una maglietta liscia ha densità di testo *maggiore* di
  uno screenshot poco testuale. Resta solo diagnostico, fuori dal verdetto.

**Verdetto:** `screenshot` se `isole ≥ 24` **E** `reach ≥ 0.40`; altrimenti `clean`
se `reach ≥ 0.45` e `isole ≤ 1`; altrimenti `messy`. Conservativo: un capo vero (un
solo oggetto che riempie il frame) non viene mai scambiato per screenshot.

## Componenti

**Piano 1 — FATTO (branch `feat/smistatore-scontorno-capi`)**
- `garmentClassifier.js` (puro) + test sintetici + test su immagini vere (fixture).
- Gate all'aggiunta in `AddItemPage`: se `screenshot` → messaggio (evolverà in
  "ritaglia/tocca il capo" nel Piano 2).
- `garmentImage.js` `loadGarmentTexture`: se `screenshot` → ripiego tinta unita
  (backstop per il backlog). 3D invariato.

**Piano 2 — da scrivere (scontorno gratis)**
- **Guida/ritaglio** all'aggiunta: aiutare l'utente a inquadrare solo il capo.
- **`@imgly/background-removal`** in-browser (MIT, on-device) per lo scontorno
  automatico di foto pulite/messy.
- **Tap-to-cutout**: segmentazione interattiva SAM/MobileSAM (WebGPU/WASM) per gli
  screenshot / cutout sporchi; l'utente tocca il capo.
- **Cache locale IndexedDB**: `${id capo}:${hash foto}` → PNG ritagliato + versione
  algoritmo. Scontorno all'aggiunta; backlog pigro al primo render.

**Pipeline 3D** — `garmentTexture.js` geometrico: **nessuna modifica**.

## Paletti onesti (nessuno è denaro)

- I modelli (@imgly, SAM) si scaricano la prima volta (decine di MB), poi in cache.
- Il tap è un'interazione in più (ma è UX migliore del blocco secco).
- La bg-removal toglie lo *sfondo*, non isola il capo da un collage: per questo per
  gli screenshot serve il tap.
- Se il capo è indossato da una modella, il tap può prendere anche la persona:
  ritaglio meno pulito, ma meglio dello screenshot intero.
- **Fuori scope:** vestire *realistico* (il capo che cade addosso). È compositing
  "posato" (vedi spec "Su modello") o AI generativa — non parte di questo lavoro.

## Strategia di test

I test sintetici non bastano (bordi netti irreali). Il classificatore è validato su
**immagini vere** come fixture (`src/utils/__fixtures__/`): screenshot reali +
foto di capi reali per i falsi positivi. Rompere sempre il codice per vedere il
test diventare rosso. **Da aggiungere:** uno screenshot vero dell'utente (shopping)
per confermare la taratura prima di considerarla definitiva.

## Cosa risolve

Foto vera del capo (scontornata gratis), screenshot ritagliato/toccato (scontornato
gratis on-device), backlog rotto (tinta unita invece di screenshot grezzo). Il tutto
**senza spendere**. Resta fuori solo la vestizione realistica (out of scope).
