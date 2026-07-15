# Smistatore Piano 2: scontorno automatico gratis (@imgly) + cache

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Far vestire davvero il manichino: per le foto NON-screenshot (clean/messy) il capo viene scontornato con un modello ML on-device (`@imgly/background-removal`, gratis), il PNG trasparente è cachato in IndexedDB, e la modalità piatta lo usa come `textureUrl` al posto del ritaglio geometrico grezzo.

**Architecture:** Un modulo `backgroundRemoval.js` incapsula `@imgly` (WASM, on-device, restituisce un dataURL PNG). Un modulo `garmentCutoutCache.js` (IndexedDB) memorizza il PNG per `id capo + hash foto`. In `loadGarmentTexture` (guscio DOM già async), per i capi non-screenshot il `textureUrl` viene preso dalla cache (miss → `@imgly` → cache), con il ritaglio geometrico come ripiego se `@imgly` fallisce. Il 3D e il classificatore restano invariati.

**Tech Stack:** JavaScript, React 19, Vitest 4, `@imgly/background-removal` (nuova dipendenza, WASM on-device), IndexedDB (nativo, nessuna dipendenza).

## Global Constraints

- **Non spendere:** tutto on-device, nessuna API a pagamento, nessun server. `@imgly/background-removal` gira in-browser.
- **Solo modalità piatta / caso non-screenshot:** gli screenshot restano gestiti dal Piano 1 (verdetto `screenshot` → tinta unita). Il 3D (`garmentTexture.js` geometrico) **non si tocca**.
- **Molti pezzi NON sono unit-testabili in node** (WASM/IndexedDB richiedono il browser): come per three.js, la matematica pura si testa in Vitest, l'integrazione ML si **verifica nel browser**. Non fingere che un test node copra `@imgly`.
- **Sito statico su GitHub Pages + CSP:** la libreria scarica gli asset del modello a runtime. Va verificato che build e CSP li permettano (Task 1 è il gate).
- Il PNG in cache è un **dataURL** (`image/png`, con alpha), usabile direttamente come `href` di `<image>` SVG.
- Test runner: `npx vitest run <file>`.

---

### Task 1: Installare @imgly e provarlo nel browser (spike-gate)

Questo task **de-rischia tutto il piano**: se `@imgly` non gira in questo build/CSP/mobile, si scopre qui prima di costruirci sopra.

**Files:**
- Modify: `package.json` (dipendenza)
- Create (temporaneo): `src/utils/_imgly_spike.js` — verrà rimosso a fine task

**Interfaces:**
- Produces: conferma che `import { removeBackground } from '@imgly/background-removal'` funziona in-browser in questa app e restituisce un `Blob` PNG.

- [ ] **Step 1: Installare la libreria**

Run: `npm i @imgly/background-removal`
Expected: installata senza errori. Annotare in `package.json` la versione risolta.

- [ ] **Step 2: Verificare l'impatto sul build**

Run: `npx vite build --base=/stylevault/`
Expected: build OK. Annotare la dimensione del/dei chunk aggiunti. Se il bundle principale cresce molto, verificare che `@imgly` sia in un chunk separato / caricato dinamicamente (import dinamico, vedi Task 4). Se il build fallisce per gli asset WASM, annotare l'errore: è un segnale che serve configurare `vite` (assetsInclude / publicPath della libreria).

- [ ] **Step 3: Provare removeBackground davvero (browser)**

Creare `src/utils/_imgly_spike.js`:

```js
// Spike temporaneo: prova che @imgly gira in-browser. Da rimuovere a fine Task 1.
import { removeBackground } from '@imgly/background-removal';

window.__imglySpike = async (imgUrl) => {
  console.time('imgly');
  const blob = await removeBackground(imgUrl);
  console.timeEnd('imgly');
  const url = URL.createObjectURL(blob);
  const img = new Image();
  img.src = url;
  img.style.cssText = 'position:fixed;top:0;right:0;width:200px;z-index:99999;background:repeating-conic-gradient(#ccc 0% 25%,#fff 0% 50%) 0 0/20px 20px';
  document.body.appendChild(img);
  return url;
};
```

Importarlo temporaneamente in `src/main.jsx` (una riga: `import './utils/_imgly_spike.js';`).
Run: `npm run dev`, aprire l'app, in console: `await window.__imglySpike('https://picsum.photos/seed/x/500/700')`.
Expected: dopo qualche secondo appare in alto a destra l'immagine **con lo sfondo rimosso** (trasparenza visibile sul pattern a scacchi). Annotare il tempo di `console.time('imgly')`. Provare anche su una foto di capo reale (una delle fixture, servita da `src/utils/__fixtures__/`).

- [ ] **Step 4: Verificare su mobile (o emulazione)**

Aprire la stessa pagina da un telefono sulla rete locale (o DevTools device emulation) e rieseguire lo spike. Annotare se gira e quanto ci mette. Se crasha/è troppo lento su mobile, **fermarsi e segnalare**: potrebbe servire un modello più piccolo (opzione di config della libreria) o self-host degli asset.

- [ ] **Step 5: Rimuovere lo spike**

Cancellare `src/utils/_imgly_spike.js` e la riga di import in `src/main.jsx`.
Run: `npx vitest run && npx vite build --base=/stylevault/`
Expected: test verdi, build OK.

- [ ] **Step 6: Commit**

```bash
git add package.json package-lock.json
git commit -m "chore: aggiungi @imgly/background-removal (spike in-browser ok)"
```
(Nel messaggio annotare tempo osservato e dimensione chunk.)

---

### Task 2: Chiave di cache (funzione pura)

**Files:**
- Create: `src/utils/garmentCutoutCache.js`
- Test: `src/utils/garmentCutoutCache.test.js`

**Interfaces:**
- Produces: `cutoutCacheKey(item) → string` — `${item.id}:${hash}` dove `hash` è un hash stringa deterministico di `item.photo` (così se la foto cambia, la chiave cambia e la cache si invalida). `CUTOUT_VERSION` esportata: costante nel prefisso della chiave, così un bump rigenera tutto.

- [ ] **Step 1: Write the failing test**

```js
import { describe, it, expect } from 'vitest';
import { cutoutCacheKey, CUTOUT_VERSION } from './garmentCutoutCache';

describe('cutoutCacheKey', () => {
  it('include id e versione', () => {
    const k = cutoutCacheKey({ id: 'abc', photo: 'data:image/jpeg;base64,AAAA' });
    expect(k).toContain('abc');
    expect(k).toContain(String(CUTOUT_VERSION));
  });

  it('cambia se cambia la foto (invalidazione)', () => {
    const a = cutoutCacheKey({ id: 'x', photo: 'data:1' });
    const b = cutoutCacheKey({ id: 'x', photo: 'data:2' });
    expect(a).not.toBe(b);
  });

  it('è stabile a parità di input', () => {
    const item = { id: 'x', photo: 'data:same' };
    expect(cutoutCacheKey(item)).toBe(cutoutCacheKey(item));
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run src/utils/garmentCutoutCache.test.js`
Expected: FAIL — `cutoutCacheKey is not a function`.

- [ ] **Step 3: Write minimal implementation**

```js
/**
 * Cache locale (IndexedDB) dei PNG scontornati dei capi. La chiave lega id capo e
 * foto: se la foto cambia, la cache si invalida. `CUTOUT_VERSION` nel prefisso
 * permette di rigenerare tutto cambiando l'algoritmo di scontorno.
 */

export const CUTOUT_VERSION = 1;

/** Hash stringa deterministico (djb2), in esadecimale. Non crittografico: serve
 * solo a distinguere foto diverse per la chiave di cache. */
const hashString = (s) => {
  let h = 5381;
  for (let i = 0; i < s.length; i++) h = ((h << 5) + h + s.charCodeAt(i)) | 0;
  return (h >>> 0).toString(16);
};

/** @returns {string} chiave di cache per il capo. */
export function cutoutCacheKey(item) {
  return `v${CUTOUT_VERSION}:${item.id}:${hashString(item.photo || '')}`;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npx vitest run src/utils/garmentCutoutCache.test.js`
Expected: PASS (3 test).

- [ ] **Step 5: Commit**

```bash
git add src/utils/garmentCutoutCache.js src/utils/garmentCutoutCache.test.js
git commit -m "feat(cutout-cache): chiave di cache per id+foto con versione"
```

---

### Task 3: I/O IndexedDB della cache

**Files:**
- Modify: `src/utils/garmentCutoutCache.js`
- Test: browser (IndexedDB non gira in node senza polyfill; si verifica al Task 6)

**Interfaces:**
- Consumes: `cutoutCacheKey`.
- Produces:
  - `getCachedCutout(item) → Promise<string|null>` — il dataURL PNG se in cache, altrimenti `null`.
  - `putCachedCutout(item, dataUrl) → Promise<void>` — salva il dataURL.
  - Non lanciano mai: se IndexedDB non è disponibile o dà errore, `get` risolve `null` e `put` risolve senza effetto (la pipeline ripiega sul geometrico).

- [ ] **Step 1: Implementare l'I/O** (aggiungi in fondo a `garmentCutoutCache.js`)

```js
const DB_NAME = 'sv_garment_cutouts';
const STORE = 'cutouts';

/** Apre (o crea) il DB. Risolve null se IndexedDB non c'è (es. modalità privata). */
const openDb = () =>
  new Promise((resolve) => {
    if (typeof indexedDB === 'undefined') return resolve(null);
    let req;
    try {
      req = indexedDB.open(DB_NAME, 1);
    } catch {
      return resolve(null);
    }
    req.onupgradeneeded = () => {
      if (!req.result.objectStoreNames.contains(STORE)) req.result.createObjectStore(STORE);
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => resolve(null);
  });

/** @returns {Promise<string|null>} dataURL PNG cachato, o null. */
export async function getCachedCutout(item) {
  const db = await openDb();
  if (!db) return null;
  return new Promise((resolve) => {
    try {
      const req = db.transaction(STORE, 'readonly').objectStore(STORE).get(cutoutCacheKey(item));
      req.onsuccess = () => resolve(typeof req.result === 'string' ? req.result : null);
      req.onerror = () => resolve(null);
    } catch {
      resolve(null);
    }
  });
}

/** Salva il dataURL. Non lancia mai. @returns {Promise<void>} */
export async function putCachedCutout(item, dataUrl) {
  const db = await openDb();
  if (!db) return;
  return new Promise((resolve) => {
    try {
      const tx = db.transaction(STORE, 'readwrite');
      tx.objectStore(STORE).put(dataUrl, cutoutCacheKey(item));
      tx.oncomplete = () => resolve();
      tx.onerror = () => resolve();
    } catch {
      resolve();
    }
  });
}
```

- [ ] **Step 2: Verificare che non rompa la suite**

Run: `npx vitest run`
Expected: PASS (i test esistenti non toccano IndexedDB; la funzione pura del Task 2 resta verde). L'I/O si verifica nel browser al Task 6.

- [ ] **Step 3: Commit**

```bash
git add src/utils/garmentCutoutCache.js
git commit -m "feat(cutout-cache): get/put su IndexedDB, non lancia mai"
```

---

### Task 4: Wrapper di @imgly (scontorno on-device)

**Files:**
- Create: `src/utils/backgroundRemoval.js`
- Test: browser (Task 6)

**Interfaces:**
- Produces: `removeGarmentBackground(photoUrl) → Promise<string>` — dataURL PNG trasparente del capo scontornato. Lancia se `@imgly` fallisce (il chiamante fa il ripiego). Import **dinamico** di `@imgly` così il modello/WASM non pesa sul bundle iniziale.

- [ ] **Step 1: Implementare il wrapper**

```js
/**
 * Scontorno del capo con modello ML on-device (@imgly/background-removal, gratis,
 * gira nel browser via WASM). Import dinamico: il modello non entra nel bundle
 * iniziale, si scarica solo al primo uso. Restituisce un dataURL PNG trasparente.
 */

const blobToDataUrl = (blob) =>
  new Promise((resolve, reject) => {
    const r = new FileReader();
    r.onload = () => resolve(r.result);
    r.onerror = () => reject(new Error('read'));
    r.readAsDataURL(blob);
  });

/** @param {string} photoUrl dataURL o URL della foto del capo.
 *  @returns {Promise<string>} dataURL PNG scontornato. Lancia in caso di errore. */
export async function removeGarmentBackground(photoUrl) {
  const { removeBackground } = await import('@imgly/background-removal');
  const blob = await removeBackground(photoUrl);
  return blobToDataUrl(blob);
}
```

- [ ] **Step 2: Verificare build + import dinamico**

Run: `npx vite build --base=/stylevault/`
Expected: build OK; `@imgly` finisce in un **chunk separato** (import dinamico), non nel bundle principale. Annotare i chunk.

- [ ] **Step 3: Commit**

```bash
git add src/utils/backgroundRemoval.js
git commit -m "feat(cutout): wrapper @imgly on-device, import dinamico"
```

---

### Task 5: Integrare in loadGarmentTexture (cache-first + @imgly)

**Files:**
- Modify: `src/utils/garmentImage.js`
- Test: browser (Task 6) + `npx vitest run` per non-regressione

**Interfaces:**
- Consumes: `getCachedCutout`, `putCachedCutout` da `./garmentCutoutCache`; `removeGarmentBackground` da `./backgroundRemoval`.
- Produces: `loadGarmentTexture` restituisce lo stesso shape, ma per i capi non-screenshot il `textureUrl` viene dalla cache/`@imgly` (ripiego: ritaglio geometrico `cutout(...)`). `swatchUrl`/`printUrl`/`colorHex` restano dal geometrico (servono al 3D).

- [ ] **Step 1: Aggiungere gli import** in cima a `garmentImage.js`

```js
import { getCachedCutout, putCachedCutout } from './garmentCutoutCache';
import { removeGarmentBackground } from './backgroundRemoval';
```

- [ ] **Step 2: Sostituire il calcolo di `textureUrl`**

In [`garmentImage.js`](../../../src/utils/garmentImage.js), il blocco finale di `loadGarmentTexture` oggi è:

```js
  const swatchUrl = result.swatch ? cropToDataUrl(imageData, result.swatch) : null;
  const printUrl = result.print
    ? printToDataUrl(imageData, result.print, result.dominantHex)
    : null;
  const textureUrl = cutout(imageData, result.mask, result.bounds);

  return {
    textureUrl,
    swatchUrl,
    printUrl,
    printAt: result.printAt,
    colorHex: result.dominantHex,
    kind: 'texture',
    reason: null,
  };
```

Sostituirlo con (swatch/print invariati; `textureUrl` da cache→@imgly→geometrico):

```js
  const swatchUrl = result.swatch ? cropToDataUrl(imageData, result.swatch) : null;
  const printUrl = result.print
    ? printToDataUrl(imageData, result.print, result.dominantHex)
    : null;

  // textureUrl (modalità piatta): scontorno ML on-device, cachato. Miss → @imgly →
  // salva in cache. Se @imgly fallisce, ripiego sul ritaglio geometrico grezzo.
  let textureUrl = await getCachedCutout(item);
  if (!textureUrl) {
    try {
      textureUrl = await removeGarmentBackground(item.photo);
      await putCachedCutout(item, textureUrl);
    } catch {
      textureUrl = cutout(imageData, result.mask, result.bounds);
    }
  }

  return {
    textureUrl,
    swatchUrl,
    printUrl,
    printAt: result.printAt,
    colorHex: result.dominantHex,
    kind: 'texture',
    reason: null,
  };
```

- [ ] **Step 3: Verificare non-regressione**

Run: `npx vitest run`
Expected: PASS (134 test). I test non chiamano `loadGarmentTexture` col ramo @imgly (è guscio DOM), quindi restano verdi; la logica ML si verifica al Task 6.

- [ ] **Step 4: Build**

Run: `npx vite build --base=/stylevault/`
Expected: build OK.

- [ ] **Step 5: Commit**

```bash
git add src/utils/garmentImage.js
git commit -m "feat(avatar): modalità piatta usa lo scontorno @imgly cachato"
```

---

### Task 6: Verifica end-to-end nel browser

**Files:** nessuno (verifica).

- [ ] **Step 1: Avviare**

Run: `npm run dev`

- [ ] **Step 2: Capo con foto messy → cutout vero**

Aggiungere un capo con una **foto reale** (sfondo non uniforme, es. capo su un letto — usare una fixture o una foto vera). Aprire l'avatar in **modalità PIATTA**.
Expected: al primo render c'è un'attesa (secondi, @imgly gira), poi il capo appare **scontornato pulito** sul manichino, non più il ritaglio geometrico grezzo. Console senza errori.

- [ ] **Step 3: Cache — il secondo render è istantaneo**

Ricaricare la pagina (o togliere e rimettere il capo). Riaprire l'avatar piatto.
Expected: il capo appare **subito** (nessuna attesa @imgly): il PNG viene dalla cache IndexedDB. Verificare in DevTools → Application → IndexedDB → `sv_garment_cutouts` che ci sia la voce.

- [ ] **Step 4: Screenshot → resta tinta unita (Piano 1 intatto)**

Aggiungere un capo da uno screenshot. Avatar piatto.
Expected: sagoma in **tinta unita** (non passa da @imgly, il verdetto è `screenshot`). Nessuna regressione del Piano 1.

- [ ] **Step 5: Ripiego se @imgly non parte**

In DevTools, simulare offline (così il modello @imgly non si scarica la prima volta) e aggiungere un capo nuovo con foto pulita su bianco.
Expected: niente crash; il capo appare col **ritaglio geometrico** (ripiego), non sparisce. (Se il modello era già in cache del browser, questo passo può non essere osservabile: annotarlo.)

- [ ] **Step 6: Salvare l'esito**

Annotare l'esito reale dei passi 2-5 (cosa si è visto, tempi @imgly, presenza in IndexedDB). Se qualcosa non va come atteso, non forzare: tornare al task pertinente.

---

## Self-Review

**Copertura spec (Piano 2 = scontorno automatico gratis, rung 1-2 della scala):**
- `@imgly` on-device per lo scontorno gratis → Task 1, 4. ✓
- Cache locale IndexedDB (chiave id+foto+versione) → Task 2, 3. ✓
- Integrazione in modalità piatta (textureUrl da cutout ML) → Task 5. ✓
- Screenshot restano tinta unita (Piano 1) → verificato Task 6.4; nessun task lo cambia. ✓
- 3D invariato → nessun task tocca `garmentTexture.js`. ✓
- **Fuori da questo piano:** guida al ritaglio + tap-to-cutout SAM → Piano 3 (user-assisted). Annotato.

**Placeholder scan:** nessun TBD. Le parti non deterministiche (@imgly, IndexedDB) sono esplicitamente **verificate nel browser** (Task 1, 6), non finte-testate in node — coerente con "three.js non gira nei test".

**Consistenza dei tipi:** `cutoutCacheKey(item)→string`, `getCachedCutout(item)→Promise<string|null>`, `putCachedCutout(item,dataUrl)→Promise<void>`, `removeGarmentBackground(photoUrl)→Promise<string>` — usati identici nel Task 5. `loadGarmentTexture` mantiene lo shape `GarmentTexture` esistente.

**Rischio dichiarato:** il Task 1 è un **gate**. Se @imgly non gira in questo build/CSP o è troppo lento su mobile, ci si ferma e si valuta (self-host asset, modello più piccolo, o rimandare). Il resto del piano presuppone che il Task 1 sia passato.

**Nota working tree:** ci sono modifiche non committate non correlate in `AvatarSvg.jsx`/`avatarMesh.js`/`avatarOptions.js` (lavoro sui corpi per genere). Questo piano **non le tocca**: opera in `garmentImage.js` e nuovi moduli. `AvatarSvg` piatto già rende `textureUrl`, quindi non serve modificarlo.
