# Smistatore dello scontorno capi — design

**Data:** 2026-07-14
**Stato:** approvato, pronto per il piano di implementazione

## Problema

In modalità PIATTA i capi non vestono il manichino: compaiono le **foto grezze**
degli screenshot con la UI del sito (badge "PROMO", prezzo, barra di stato,
modella). Segnalato da Mary sul sito live.

### Causa radice (investigata e riprodotta)

Mary aggiunge i capi **caricando screenshot** di app di shopping. Lo scontorno in
[`garmentTexture.js`](../../../src/utils/garmentTexture.js) usa un **riempimento
dai 4 angoli**: "sfondo = ciò che è raggiungibile da un angolo con colore simile;
capo = tutto il resto". Funziona su una foto pulita di un capo su fondo uniforme;
**fallisce su uno screenshot**, che è un collage: tutto ciò che non è raggiungibile
dagli angoli — foto del capo **+ badge + prezzo + UI** — viene marcato come "capo".
Il ritaglio risultante (`textureUrl`) è lo screenshot intero, che
[`AvatarSvg.jsx`](../../../src/components/Avatar/AvatarSvg.jsx) incolla sul
manichino senza clip.

La rete di sicurezza esistente (`coverage` fra 0.02 e 0.92 → altrimenti tinta
unita) **non scatta**: un'isola di contenuto sta comodamente nel range "valido".

Riproduzione (test scritto ed eseguito, poi rimosso): screenshot sintetico con
capo + badge rosso + riga prezzo → `ok: true`, `coverage: 0.46`, badge e prezzo
finiscono con `mask = 1` (trattati da capo). Combacia con lo screenshot di Mary e
con la lezione già nota: i test sintetici non hanno bordi sfumati e non hanno mai
visto questo caso.

**Punto chiave:** nessuna regolazione delle soglie del riempimento potrà mai
separare un capo da una UI arbitraria dentro uno screenshot. È un problema di
segmentazione semantica, non di soglia.

## Obiettivo

Uno **smistatore** che, all'aggiunta del capo, riconosce il tipo di immagine e la
manda nel percorso migliore, con una rete di sicurezza sotto: l'app non mostra
**mai** più uno screenshot grezzo, e veste il manichino sul serio quando l'input lo
permette. L'utente non deve sapere niente di "link vs foto vs screenshot".

## Decisioni prese (brainstorming)

- **Scope v1:** classificazione + background-removal ML in-browser (non solo rete
  di sicurezza).
- **Quando/cache:** lo scontorno gira **all'aggiunta** (spinner); il PNG ritagliato
  si salva in **cache locale** (IndexedDB). Niente modifiche a Supabase. Il backlog
  (capi già in guardaroba) si lavora in modo **pigro al primo render**.
- **Screenshot (REVISIONE 2026-07-14, vedi sotto):** non più solo "blocca". Si
  **guida l'utente a ritagliare e inquadrare solo il capo**, e per i casi che
  restano ostici c'è il **tap-to-cutout on-device** (l'utente tocca il capo, un
  modello di segmentazione tipo SAM/MobileSAM lo ritaglia, gratis, sul dispositivo).
  Il **degrado a tinta unita** resta come backstop al render per il backlog.
- **Approccio C:** la ML si innesta **solo sulla modalità piatta**; il **3D resta
  invariato** (pipeline geometrica `garmentTexture.js` toccata zero). Blast radius
  minimo sulla parte live e funzionante. Condivisi il classificatore e il gate;
  diverso solo il meccanismo di ritaglio.
- **Gemini (BYOK): NON più necessario per essere gratis.** Con guida al ritaglio +
  tap-to-cutout on-device, tutta la pipeline di scontorno è gratuita e locale.
  Gemini resta al massimo un lusso opzionale (chiave dell'utente in localStorage,
  niente proxy), **non un gradino obbligato**. Requisito esplicito di Lorenzo:
  **non spendere; trovare un modo gratis.** Trovato: il tap sostituisce l'AI
  semantica a pagamento (è l'utente a dire *quale* è il capo).

## Architettura

### La scala dei ripieghi (rivista 2026-07-14: tutta gratis, on-device)

```
0. GUIDA AL RITAGLIO → l'utente inquadra/ritaglia solo il capo (riduce gli errori
                       a monte: uno screenshot ritagliato ≈ foto quasi-pulita)
1. clean       → scontorno geometrico attuale (gratis, istantaneo)
2. messy       → bg-removal ML in-browser (@imgly, gratis, on-device)
3. screenshot / cutout non pulito → TAP-TO-CUTOUT: l'utente tocca il capo,
                 segmentazione on-device (SAM/MobileSAM, WebGPU) lo ritaglia (gratis)
4. render, capo senza ritaglio (backlog) → tinta unita (backstop)
(opz.) Gemini BYOK → lusso facoltativo, NON necessario. Solo se l'utente ha una
                     chiave e vuole l'estrazione automatica senza toccare.
```

### Flusso dati

```
AGGIUNTA (foto) → GUIDA/RITAGLIO al capo → classify
   → clean/messy → scontorno automatico on-device → cache IndexedDB
   → screenshot / risultato sporco → "tocca il capo" → SAM on-device → cache
RENDER piatto → cutout in cache? → usa PNG
                                 → miss (backlog)? → classify + scontorno pigro
                                                    | screenshot non risolto → tinta unita
RENDER 3D → pipeline geometrica attuale (INVARIATA)
```

### Scontorno gratis: guida al ritaglio + tap-to-cutout (REVISIONE 2026-07-14)

Il vincolo di Lorenzo è **non spendere**. La svolta: il motivo per cui uno
screenshot non si scontorna in automatico è che la macchina non sa **quale** cosa
sia il capo dentro il collage — quella comprensione è ciò che si pagherebbe con
Gemini. Ma se è **l'utente** a indicarlo, il costo sparisce.

**Due leve gratuite, in ordine:**

1. **Guida al ritaglio (a monte).** All'aggiunta, si invita/aiuta l'utente a
   **inquadrare o ritagliare solo il capo** (via barra di stato, prezzo, badge,
   altri prodotti). Idea di Lorenzo. Effetto: uno screenshot ritagliato stretto sul
   capo diventa ≈ una foto quasi-pulita, e lo **scontorno automatico gratis**
   (`@imgly`, on-device) ci arriva da solo. Riduce gli errori senza modelli extra.
2. **Tap-to-cutout (rete per i casi ostici).** Se dopo il ritaglio l'immagine è
   ancora sporca (es. capo **indossato da una modella** nello screenshot), l'utente
   **tocca il capo** e un modello di **segmentazione interattiva on-device**
   (SAM / MobileSAM / SlimSAM via WebGPU o WASM) ritaglia esattamente la regione
   toccata. Gratis, sul dispositivo, nessun server, nessuna chiave. Il tap
   fornisce il "quale oggetto" che altrimenti richiederebbe l'AI semantica.

**Costi/limiti onesti (nessuno è denaro):**
- Il modello SAM si scarica la prima volta (decine di MB), come la bg-removal.
- Il tap è un'interazione in più (ma è UX migliore del blocco secco).
- Se il capo è indossato, il tap può prendere anche la persona: ritaglio meno
  pulito, ma comunque meglio dello screenshot intero.
- Resta escluso il solo **vestire realistico** (il capo che *cade* addosso): quello
  è un'altra cosa (compositing "posato" gratis, o Gemini a pagamento), fuori dallo
  scontorno.

**Conseguenza sul piano:** il gradino "screenshot → blocca/Gemini" del Piano 1
diventa "screenshot → guida al ritaglio → (se serve) tap-to-cutout". Il Piano 1
già fatto (classificatore + blocco + degrado) resta valido come **primo strato**
(rileva lo screenshot e non incolla mai la foto grezza); la guida al ritaglio e il
tap-to-cutout sono materia del **Piano 2** (era "ML in-browser + cache"), che ora
include anche SAM on-device. Gemini scende a **Piano 3 opzionale, non necessario**.

### Componenti

**Condivisi**

- `classifyGarmentImage(imageData) → 'clean' | 'messy' | 'screenshot'`
  Modulo **puro** (testabile in Vitest), solo euristiche cheap. Conservativo: nel
  dubbio **non** dice `screenshot`.
- **Gate all'aggiunta** in `AddItemPage.jsx`: dopo l'upload foto, classifica; se
  `screenshot` e nessuna chiave Gemini → blocca con messaggio.

**Pipeline piatta (nuova, ML)**

- `removeBackground(...)` in `garmentImage.js` (guscio DOM): chiama
  `@imgly/background-removal`, produce un **Blob PNG trasparente**.
- `garmentCutoutCache.js` — wrapper IndexedDB (get/set + versione algoritmo).
- `AvatarSvg` piatto usa il PNG dalla cache come `textureUrl` (già trasparente),
  tinta unita se degradato.

**Pipeline 3D (invariata)**

- `garmentTexture.js` geometrico + `loadGarmentTexture`: **nessuna modifica**.

**Gemini (rung 4, opzionale)**

- Campo chiave in Profilo (localStorage), mai su Supabase.
- `geminiCutout.js` — modulo separato, fetch diretto all'API Generative Language.

### Il classificatore — segnali

Tutti cheap, nessuna AI:

1. **Uniformità dello sfondo** — riuso il riempimento dai 4 angoli: quanto raggiunge
   e quanto sono uniformi gli angoli.
2. **Numero di isole di contenuto** — componenti connesse del "non-sfondo". Una
   sola isola → capo singolo; tante isole sparse → segnale forte di `screenshot`.
3. **Densità di testo** — micro-salti di luminanza ad alto contrasto sulle scanline.
4. **Rettangoli UI a tinta piatta** — run di pixel identici con bordi dritti
   allineati agli assi (supporto).
5. **Proporzioni / barra di stato** — aspect ratio da schermo telefono + striscia
   in alto con iconcine (supporto, non decisivo).

**Decisione (conservativa):** `screenshot` solo se **più segnali forti concordano**
(es. molte isole disconnesse **E** alta densità di testo). Mai su un segnale solo.
Altrimenti: sfondo uniforme + una sola isola → `clean`; tutto il resto → `messy`.

### Cache locale

- `garmentCutoutCache.js` su **IndexedDB** (i PNG sono troppo grossi per
  localStorage).
- Chiave: `${id capo}:${hash della foto}` → se la foto cambia, la cache si invalida.
- Valore: PNG (blob) + verdetto classificatore + numero di versione dell'algoritmo
  (bump della versione = rigenerazione automatica).

## La ML in-browser

**Libreria:** `@imgly/background-removal` (MIT, pensata per foto-prodotto, ONNX su
WASM). Preferita a MediaPipe (tarata su selfie) e a transformers.js+RMBG (più
artigianale).

**Paletti onesti:**

- **Peso modello** decine di MB, scaricato la prima volta e poi in cache del
  browser. Su GitHub Pages è solo un fetch. Strada (a) CDN della libreria; strada
  (b) self-host asset se CSP/affidabilità danno noia. Si parte da (a).
- **CSP** del sito (nostra): permettere WASM (`wasm-unsafe-eval`) e l'origine del
  modello. Da verificare su `index.html`/header in fase di integrazione.
- **Performance mobile**: qualche secondo per immagine + download la prima volta.
  Accettabile all'aggiunta con spinner; girare **fuori dal main thread**.
- **Limite reale**: toglie lo *sfondo* attorno al soggetto. Capo steso → ottimo;
  capo *indossato da una persona* → tiene la persona. Input ideale = capo da solo.

## Gemini (BYOK) — guida chiave API

Da mettere in-app (verificare i label attuali di Google quando si scrive il testo):

1. Vai su **aistudio.google.com** e accedi col tuo account Google.
2. Clicca **"Get API key"**.
3. **"Create API key"** → scegli o crea un progetto Google Cloud.
4. **Copia** la chiave.
5. *(Consigliato)* Restringila: Google Cloud Console → Credenziali → la chiave →
   limita a referrer del sito + solo *Generative Language API*.
6. Incollala in StyleVault → Profilo. Resta sul dispositivo.

**Caveat:** chiave nel browser = va ristretta; ha la sua quota/free tier.

**⚠️ Zona da spike (non blocca la v1):** se Gemini rende meglio un'immagine
trasparente o una maschera, e la CORS dal browser, si verificano quando si arriva
al rung 4. La scala gratis (rung 1–3) è il cuore e non dipende da questo nodo.

## Strategia di test

La lezione nota: i test sintetici non falliscono mai perché non hanno bordi sfumati.
Quindi:

- **Classificatore** validato su **immagini vere** come fixture: lo screenshot di
  Mary, un paio di foto-prodotto pulite, una foto di un capo steso con sfondo
  incasinato. Se non becca lo screenshot di Mary, il test è rosso e non abbiamo
  finito. Il synthetic solo per i casi limite noti.
- **Cache**: get/set, invalidazione su cambio foto, bump di versione.
- **Gate**: `screenshot` senza chiave → blocca; con chiave → passa.
- Rompere sempre il codice per vedere il test diventare rosso prima di dichiararlo
  verde.

## Cosa risolve e cosa no (onesto)

Risolve: foto vera del capo (veste davvero), link con foto pulita, backlog rotto
(tinta unita invece di screenshot), screenshot nuovi (bloccati). **Non** risolve:
vestire il manichino *da uno screenshot* senza Gemini; il classificatore e la ML
non sono perfetti al 100% (per questo la rete di sicurezza sotto). Il "risolto" si
appoggia anche sul **cambiare l'input di Mary** — screenshot → foto/link.

## Fuori scope (v1)

- Proxy Gemini server-side con chiave condivisa (sostituito da BYOK).
- Reprocessing di massa del guardaroba (il backlog si fa pigro al primo render).
- Toccare la pipeline 3D geometrica.
