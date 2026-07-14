# Smistatore capi — Piano 1: classificatore + gate + degrado

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fermare il bug live di Mary — mai più uno screenshot grezzo incollato sul manichino — con un classificatore che riconosce gli screenshot, un blocco all'aggiunta e un degrado a tinta unita al render. Senza ancora la dipendenza ML.

**Architecture:** Un modulo puro `garmentClassifier.js` classifica l'immagine (`clean`/`messy`/`screenshot`) riusando il riempimento dai 4 angoli già in `garmentTexture.js`. Il verdetto viene consumato in due punti: (1) all'aggiunta foto in `AddItemPage`, dove uno `screenshot` viene **bloccato**; (2) in `loadGarmentTexture` (guscio DOM), dove uno `screenshot` forza il **ripiego in tinta unita** invece del ritaglio geometrico — rete di sicurezza per i capi già in guardaroba.

**Tech Stack:** JavaScript, React 19, Vitest 4, react-i18next. Nessuna nuova dipendenza.

## Global Constraints

- Il classificatore è un **modulo puro** (nessun DOM): testabile in Vitest node, come `garmentTexture.js`.
- **Conservativo:** nel dubbio NON dice `screenshot`. `screenshot` solo se più segnali forti concordano. Un falso blocco di una foto buona è peggio di uno scontorno mediocre.
- I test devono usare anche **immagini vere** come fixture, non solo sintetiche (i test sintetici non hanno bordi sfumati e non falliscono mai). Rompere sempre il codice per vedere il test diventare rosso prima di dichiararlo verde.
- Riuso di `backgroundMask` da `src/utils/garmentTexture.js` (già esistente): non riscrivere il flood-fill.
- Test runner: `npx vitest run <file>`.

---

### Task 1: Conteggio delle isole di contenuto

**Files:**
- Create: `src/utils/garmentClassifier.js`
- Test: `src/utils/garmentClassifier.test.js`

**Interfaces:**
- Consumes: `backgroundMask` da `./garmentTexture` (firma: `backgroundMask({data,width,height}, {tolerance}?) → Uint8Array` con 1 = capo, 0 = sfondo).
- Produces: `countIslands(mask, width, height, { minSize = 12 } = {}) → number` — numero di componenti connesse (4-vicini) di pixel capo (mask=1) con almeno `minSize` pixel.

- [ ] **Step 1: Write the failing test**

```js
import { describe, it, expect } from 'vitest';
import { countIslands } from './garmentClassifier';

/** mask width*height con 1 dentro i rettangoli passati. */
const maskWith = (width, height, rects) => {
  const m = new Uint8Array(width * height);
  for (const r of rects)
    for (let y = r.y; y < r.y + r.h; y++)
      for (let x = r.x; x < r.x + r.w; x++) m[y * width + x] = 1;
  return m;
};

describe('countIslands', () => {
  it('un solo blocco = una isola', () => {
    const m = maskWith(20, 20, [{ x: 4, y: 4, w: 8, h: 8 }]);
    expect(countIslands(m, 20, 20)).toBe(1);
  });

  it('tre blocchi staccati = tre isole', () => {
    const m = maskWith(30, 30, [
      { x: 1, y: 1, w: 5, h: 5 },
      { x: 12, y: 1, w: 5, h: 5 },
      { x: 1, y: 12, w: 5, h: 5 },
    ]);
    expect(countIslands(m, 30, 30)).toBe(3);
  });

  it('ignora granelli sotto minSize', () => {
    const m = maskWith(20, 20, [
      { x: 4, y: 4, w: 8, h: 8 }, // 64 px
      { x: 18, y: 18, w: 1, h: 1 }, // 1 px: rumore
    ]);
    expect(countIslands(m, 20, 20, { minSize: 12 })).toBe(1);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run src/utils/garmentClassifier.test.js`
Expected: FAIL — `countIslands is not a function` (il modulo non esiste ancora).

- [ ] **Step 3: Write minimal implementation**

```js
/**
 * Classificatore del tipo di immagine capo. Puro, nessun DOM: il guscio che
 * decodifica la foto sta in garmentImage.js / AddItemPage.
 */
import { backgroundMask } from './garmentTexture';

/**
 * Numero di componenti connesse (4-vicini) di pixel capo (mask=1) con almeno
 * `minSize` pixel. Le isole piccole sono rumore e non contano. Uno screenshot
 * spezza il "non-sfondo" in tante isole (foto + badge + blocchi di testo);
 * una foto pulita del capo ne ha una sola.
 */
export function countIslands(mask, width, height, { minSize = 12 } = {}) {
  const seen = new Uint8Array(width * height);
  let islands = 0;
  for (let start = 0; start < mask.length; start++) {
    if (!mask[start] || seen[start]) continue;
    let count = 0;
    const stack = [start];
    seen[start] = 1;
    while (stack.length) {
      const p = stack.pop();
      count++;
      const x = p % width;
      const y = (p - x) / width;
      const neigh = [
        x > 0 ? p - 1 : -1,
        x < width - 1 ? p + 1 : -1,
        y > 0 ? p - width : -1,
        y < height - 1 ? p + width : -1,
      ];
      for (const n of neigh) {
        if (n < 0 || seen[n] || !mask[n]) continue;
        seen[n] = 1;
        stack.push(n);
      }
    }
    if (count >= minSize) islands++;
  }
  return islands;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npx vitest run src/utils/garmentClassifier.test.js`
Expected: PASS (3 test).

- [ ] **Step 5: Commit**

```bash
git add src/utils/garmentClassifier.js src/utils/garmentClassifier.test.js
git commit -m "feat(classifier): conteggio isole di contenuto"
```

---

### Task 2: Densità di testo

**Files:**
- Modify: `src/utils/garmentClassifier.js`
- Test: `src/utils/garmentClassifier.test.js`

**Interfaces:**
- Produces: `textDensity(imageData, { contrast = 60 } = {}) → number` — frazione (0..1) di transizioni di luminanza ad alto contrasto sulle scanline orizzontali. Il testo (tanti flip chiaro/scuro ravvicinati) alza questo valore; una foto liscia lo tiene basso.

- [ ] **Step 1: Write the failing test**

```js
import { textDensity } from './garmentClassifier';

/** imageData RGBA da una funzione (x,y)->[r,g,b]. */
const imageFrom = (width, height, fn) => {
  const data = new Uint8ClampedArray(width * height * 4);
  for (let y = 0; y < height; y++)
    for (let x = 0; x < width; x++) {
      const [r, g, b] = fn(x, y);
      const i = (y * width + x) * 4;
      data[i] = r; data[i + 1] = g; data[i + 2] = b; data[i + 3] = 255;
    }
  return { data, width, height };
};

describe('textDensity', () => {
  it('una foto liscia ha densità quasi nulla', () => {
    const img = imageFrom(40, 40, () => [150, 160, 170]);
    expect(textDensity(img)).toBeLessThan(0.02);
  });

  it('un pattern fitto bianco/nero (tipo testo) ha densità alta', () => {
    const img = imageFrom(40, 40, (x) => (x % 2 === 0 ? [0, 0, 0] : [255, 255, 255]));
    expect(textDensity(img)).toBeGreaterThan(0.4);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run src/utils/garmentClassifier.test.js`
Expected: FAIL — `textDensity is not a function`.

- [ ] **Step 3: Write minimal implementation** (aggiungi in fondo a `garmentClassifier.js`)

```js
const luminance = (data, i) =>
  0.299 * data[i] + 0.587 * data[i + 1] + 0.114 * data[i + 2];

/**
 * Frazione di transizioni ad alto contrasto sulle scanline orizzontali: per ogni
 * coppia di pixel adiacenti sulla riga, conta quando il salto di luminanza supera
 * `contrast`. Il testo produce moltissimi salti chiaro/scuro; una foto no.
 */
export function textDensity({ data, width, height }, { contrast = 60 } = {}) {
  let flips = 0;
  let pairs = 0;
  for (let y = 0; y < height; y++) {
    let prev = luminance(data, (y * width) * 4);
    for (let x = 1; x < width; x++) {
      const i = (y * width + x) * 4;
      const lum = luminance(data, i);
      if (Math.abs(lum - prev) > contrast) flips++;
      pairs++;
      prev = lum;
    }
  }
  return pairs === 0 ? 0 : flips / pairs;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npx vitest run src/utils/garmentClassifier.test.js`
Expected: PASS (5 test totali).

- [ ] **Step 5: Commit**

```bash
git add src/utils/garmentClassifier.js src/utils/garmentClassifier.test.js
git commit -m "feat(classifier): densità di testo sulle scanline"
```

---

### Task 3: Verdetto `classifyGarmentImage`

**Files:**
- Modify: `src/utils/garmentClassifier.js`
- Test: `src/utils/garmentClassifier.test.js`

**Interfaces:**
- Consumes: `backgroundMask`, `countIslands`, `textDensity`.
- Produces: `classifyGarmentImage(imageData, opts?) → { verdict: 'clean'|'messy'|'screenshot', islands: number, text: number, reach: number }`.
  - `reach` = frazione di pixel di **sfondo** (mask=0).
  - `verdict === 'screenshot'` **solo se** `islands >= ISLAND_MIN` **E** `text >= TEXT_MIN` (due segnali forti concordi).
  - altrimenti `clean` se `reach >= REACH_CLEAN` **E** `islands <= 1`; altrimenti `messy`.
  - Costanti esportate: `ISLAND_MIN`, `TEXT_MIN`, `REACH_CLEAN` (tarate al Task 4).

- [ ] **Step 1: Write the failing test**

```js
import { classifyGarmentImage } from './garmentClassifier';

describe('classifyGarmentImage (sintetico)', () => {
  it('capo pieno su fondo bianco uniforme = clean', () => {
    // fondo bianco, un rettangolo azzurro liscio al centro
    const img = imageFrom(60, 60, (x, y) =>
      x >= 15 && x < 45 && y >= 15 && y < 45 ? [150, 170, 200] : [255, 255, 255]
    );
    const out = classifyGarmentImage(img);
    expect(out.verdict).toBe('clean');
  });

  it('collage con tante isole e testo = screenshot', () => {
    // fondo bianco; foto liscia + due badge + una fascia "testo" a righe fitte
    const img = imageFrom(80, 80, (x, y) => {
      if (x >= 10 && x < 70 && y >= 8 && y < 40) return [150, 170, 200]; // foto
      if (x >= 12 && x < 24 && y >= 44 && y < 52) return [200, 40, 40]; // badge 1
      if (x >= 40 && x < 52 && y >= 44 && y < 52) return [40, 160, 60]; // badge 2
      if (y >= 60 && y < 72) return x % 2 === 0 ? [0, 0, 0] : [255, 255, 255]; // testo
      return [255, 255, 255];
    });
    const out = classifyGarmentImage(img);
    expect(out.verdict).toBe('screenshot');
  });

  it('oggetto su sfondo NON uniforme e senza testo = messy, mai screenshot', () => {
    // sfondo rumoroso (niente flood-fill pulito), un blocco: nessun testo
    const img = imageFrom(60, 60, (x, y) => {
      if (x >= 20 && x < 40 && y >= 20 && y < 40) return [150, 170, 200];
      return [200 + ((x * 7 + y * 13) % 40), 190, 180]; // sfondo variato
    });
    const out = classifyGarmentImage(img);
    expect(out.verdict).not.toBe('screenshot');
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run src/utils/garmentClassifier.test.js`
Expected: FAIL — `classifyGarmentImage is not a function`.

- [ ] **Step 3: Write minimal implementation** (aggiungi in fondo)

```js
// Tarate al Task 4 su immagini vere. Valori iniziali prudenti.
export const ISLAND_MIN = 3;   // almeno 3 isole di contenuto
export const TEXT_MIN = 0.06;  // e testo apprezzabile
export const REACH_CLEAN = 0.45; // sfondo che copre buona parte del frame

/**
 * Verdetto sul tipo di immagine capo. Conservativo: 'screenshot' solo quando
 * DUE segnali forti concordano (tante isole E testo), così una foto vera non
 * viene mai scambiata per uno screenshot e bloccata a torto.
 */
export function classifyGarmentImage(image, opts = {}) {
  const { width, height } = image;
  const mask = backgroundMask(image, opts);
  let bg = 0;
  for (let p = 0; p < mask.length; p++) if (!mask[p]) bg++;
  const reach = bg / (width * height);
  const islands = countIslands(mask, width, height);
  const text = textDensity(image, opts);

  let verdict;
  if (islands >= ISLAND_MIN && text >= TEXT_MIN) verdict = 'screenshot';
  else if (reach >= REACH_CLEAN && islands <= 1) verdict = 'clean';
  else verdict = 'messy';

  return { verdict, islands, text, reach };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npx vitest run src/utils/garmentClassifier.test.js`
Expected: PASS (8 test totali). Se il caso "screenshot" o "clean" non passa, i valori iniziali delle costanti vanno aggiustati QUI finché i tre casi sintetici sono verdi (la taratura fine su immagini vere è il Task 4).

- [ ] **Step 5: Commit**

```bash
git add src/utils/garmentClassifier.js src/utils/garmentClassifier.test.js
git commit -m "feat(classifier): verdetto clean/messy/screenshot conservativo"
```

---

### Task 4: Taratura su immagini vere (fixture reali)

**Files:**
- Create: `src/utils/__fixtures__/README.md`
- Create: `src/utils/__fixtures__/screenshot-mary.jpg` (fornita da Lorenzo)
- Create: `src/utils/__fixtures__/foto-pulita.jpg` (foto-prodotto su bianco)
- Create: `src/utils/__fixtures__/capo-steso.jpg` (capo vero su sfondo incasinato)
- Test: `src/utils/garmentClassifier.real.test.js`

**Interfaces:**
- Consumes: `classifyGarmentImage`. Nessuna nuova API prodotta.

> Questo task richiede **file immagine reali**. Senza lo screenshot vero di Mary il classificatore non è validato sul caso che ci ha fatto partire. Se i file non ci sono ancora, l'esecuzione si ferma qui e si chiede a Lorenzo di fornirli (lo screenshot del capo caricato da Mary + una foto-prodotto pulita + una foto di un capo steso).

- [ ] **Step 1: Aggiungere le immagini reali**

Salvare i tre file in `src/utils/__fixtures__/`. In `README.md` annotare cosa rappresenta ciascuno e da dove viene.

- [ ] **Step 2: Write the failing test** (decodifica PNG/JPEG in Node)

```js
import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp'; // se non presente: vedi Step 3
import { classifyGarmentImage } from './garmentClassifier';

const load = async (name) => {
  const path = fileURLToPath(new URL(`./__fixtures__/${name}`, import.meta.url));
  const { data, info } = await sharp(readFileSync(path))
    .ensureAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });
  return { data: new Uint8ClampedArray(data), width: info.width, height: info.height };
};

describe('classifyGarmentImage (immagini vere)', () => {
  it('lo screenshot di Mary è riconosciuto come screenshot', async () => {
    expect((await classifyGarmentImage(await load('screenshot-mary.jpg'))).verdict).toBe('screenshot');
  });
  it('una foto-prodotto pulita NON è uno screenshot', async () => {
    expect((await classifyGarmentImage(await load('foto-pulita.jpg'))).verdict).not.toBe('screenshot');
  });
  it('un capo steso NON è uno screenshot', async () => {
    expect((await classifyGarmentImage(await load('capo-steso.jpg'))).verdict).not.toBe('screenshot');
  });
});
```

- [ ] **Step 3: Assicurarsi del decoder immagini**

`sharp` serve solo ai test per decodificare i JPEG in Node. Se non è tra le devDependencies:
Run: `npm i -D sharp`
(In alternativa, se `sharp` dà problemi di build, decodificare con `@vitest/…` non è previsto: usare `sharp`, è lo standard per raw pixel in Node.)

- [ ] **Step 4: Run test — verificare che fallisca se le soglie sono sbagliate**

Run: `npx vitest run src/utils/garmentClassifier.real.test.js`
Expected all'inizio: potenzialmente FAIL sullo screenshot di Mary se le soglie iniziali non lo colgono. Questo è il punto: **regolare `ISLAND_MIN` / `TEXT_MIN` / `REACH_CLEAN`** in `garmentClassifier.js` finché lo screenshot di Mary è `screenshot` E le due foto vere NON lo sono. Rieseguire anche i test sintetici del Task 1-3 per non regredirli.

- [ ] **Step 5: Run entrambi i file — verde**

Run: `npx vitest run src/utils/garmentClassifier.test.js src/utils/garmentClassifier.real.test.js`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add src/utils/__fixtures__ src/utils/garmentClassifier.real.test.js src/utils/garmentClassifier.js package.json package-lock.json
git commit -m "test(classifier): taratura su immagini vere (screenshot di Mary + foto)"
```

---

### Task 5: Rete di sicurezza al render (backlog)

**Files:**
- Modify: `src/utils/garmentImage.js` (dentro `loadGarmentTexture`, dopo aver ottenuto `imageData`, prima di `extractGarment`)
- Test: manuale (guscio DOM, non unit-testato) — vedi Task 7

**Interfaces:**
- Consumes: `classifyGarmentImage` da `./garmentClassifier`; `garmentFallbackHex` (già in `garmentImage.js`).
- Produces: nessuna nuova API. Cambia il comportamento: se l'immagine è `screenshot`, `loadGarmentTexture` restituisce il ripiego tinta unita (`kind: 'flat'`, `reason: 'screenshot'`) senza tentare il ritaglio geometrico.

- [ ] **Step 1: Modificare `loadGarmentTexture`**

In [`src/utils/garmentImage.js`](../../../src/utils/garmentImage.js), aggiungere l'import in cima:

```js
import { classifyGarmentImage } from './garmentClassifier';
```

Subito dopo il blocco che ottiene `imageData` (dopo il `try/catch` del `getImageData`, prima di `const result = extractGarment(imageData);`), inserire:

```js
  // Rete di sicurezza per i capi già in guardaroba: se la foto è uno screenshot
  // (collage con UI), lo scontorno geometrico incollerebbe l'intera schermata
  // sul manichino. Meglio la sagoma in tinta unita. I capi NUOVI vengono già
  // bloccati all'aggiunta (AddItemPage); questo copre il backlog.
  if (classifyGarmentImage(imageData).verdict === 'screenshot') {
    return {
      textureUrl: null,
      swatchUrl: null,
      printUrl: null,
      printAt: null,
      colorHex: garmentFallbackHex(item),
      kind: 'flat',
      reason: 'screenshot',
    };
  }
```

- [ ] **Step 2: Verificare che non rompe i test esistenti**

Run: `npx vitest run`
Expected: PASS (i test di `garmentTexture`/`garmentImage` non toccano questo ramo; nessuna regressione).

- [ ] **Step 3: Commit**

```bash
git add src/utils/garmentImage.js
git commit -m "feat(avatar): screenshot nel backlog -> tinta unita, non foto grezza"
```

---

### Task 6: Blocco all'aggiunta + testi i18n

**Files:**
- Modify: `src/pages/AddItemPage/AddItemPage.jsx` (`handlePhotoUpload`)
- Modify: `src/i18n/it.json` (blocco `addItem`)
- Modify: `src/i18n/en.json` (blocco `addItem`)
- Test: manuale — vedi Task 7

**Interfaces:**
- Consumes: `classifyGarmentImage`; `resizeImageFile` (già usato). Serve decodificare il dataURL in `imageData`: helper locale `dataUrlToImageData`.
- Produces: nessuna nuova API pubblica.

- [ ] **Step 1: Aggiungere i testi i18n**

In `src/i18n/it.json`, dentro il blocco `"addItem"`, aggiungere:

```json
    "screenshotBlocked": "Sembra uno screenshot. Per far vestire davvero il capo all'avatar, carica una foto del capo (meglio se steso o su sfondo semplice) oppure aggiungilo da link.",
    "screenshotBlockedTitle": "Questa è una schermata, non un capo"
```

In `src/i18n/en.json`, dentro `"addItem"`, aggiungere:

```json
    "screenshotBlocked": "This looks like a screenshot. To actually dress the avatar, upload a photo of the garment (ideally flat or on a plain background) or add it from a link.",
    "screenshotBlockedTitle": "This is a screen capture, not a garment"
```

- [ ] **Step 2: Modificare `handlePhotoUpload`**

In [`AddItemPage.jsx`](../../../src/pages/AddItemPage/AddItemPage.jsx), aggiungere l'import:

```js
import { classifyGarmentImage } from '../../utils/garmentClassifier';
```

Aggiungere un helper (in cima al file, fuori dal componente):

```js
/** Decodifica un dataURL in ImageData, per il classificatore. */
const dataUrlToImageData = (dataUrl) =>
  new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => {
      const canvas = document.createElement('canvas');
      canvas.width = img.naturalWidth;
      canvas.height = img.naturalHeight;
      const ctx = canvas.getContext('2d', { willReadFrequently: true });
      ctx.drawImage(img, 0, 0);
      resolve(ctx.getImageData(0, 0, canvas.width, canvas.height));
    };
    img.onerror = () => reject(new Error('decode'));
    img.src = dataUrl;
  });
```

Sostituire il corpo di `handlePhotoUpload` con:

```js
  const handlePhotoUpload = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    try {
      const dataUrl = await resizeImageFile(file, 600);
      const imageData = await dataUrlToImageData(dataUrl);
      if (classifyGarmentImage(imageData).verdict === 'screenshot') {
        setErrors((prev) => ({ ...prev, photo: t('addItem.screenshotBlocked') }));
      } else {
        set('photo', dataUrl);
      }
    } catch {
      /* file non leggibile: nessun cambiamento */
    }
    e.target.value = '';
  };
```

- [ ] **Step 3: Mostrare l'errore nella dropzone**

Nella zona `mode === 'photo'` di `AddItemPage.jsx`, sotto la dropzone/preview, mostrare l'errore se presente. Individuare il blocco `add-item__source` per la foto (righe ~171-200) e aggiungere subito dopo l'`<input type="file" ... />` di chiusura, dentro lo stesso contenitore:

```jsx
          {errors.photo && (
            <p className="add-item__link-note add-item__link-note--error" role="alert">
              <Icon name="alert" size={13} /> {errors.photo}
            </p>
          )}
```

(Se non esiste un'icona `alert`, usare `Icon name="info"` o rimuovere l'icona: verificare i nomi disponibili in `src/components/common`.)

- [ ] **Step 4: Verificare build e test**

Run: `npx vitest run`
Expected: PASS. Poi `npm run build` per confermare che JSX e import compilano.
Expected: build senza errori.

- [ ] **Step 5: Commit**

```bash
git add src/pages/AddItemPage/AddItemPage.jsx src/i18n/it.json src/i18n/en.json
git commit -m "feat(add-item): blocca gli screenshot e spiega come dare un input buono"
```

---

### Task 7: Verifica manuale nel browser

**Files:** nessuno (verifica end-to-end).

**Interfaces:** nessuna.

- [ ] **Step 1: Avviare l'app**

Run: `npm run dev`

- [ ] **Step 2: Provare il gate all'aggiunta**

Aggiungere un capo da foto caricando **lo screenshot di un'app di shopping** (come fa Mary).
Expected: l'upload viene rifiutato e compare il messaggio `screenshotBlocked`; nessuna foto impostata.

- [ ] **Step 3: Provare un input buono**

Aggiungere un capo caricando una **foto-prodotto pulita** o una foto del capo steso.
Expected: la foto viene accettata, nessun messaggio di blocco.

- [ ] **Step 4: Provare il backlog nel render**

Con un capo già in guardaroba la cui foto è uno screenshot (uno di quelli di Mary), aprire l'avatar in modalità **PIATTA**.
Expected: il capo esce come **sagoma in tinta unita** (colore del capo), NON come screenshot incollato. La modalità **3D** resta invariata.

- [ ] **Step 5: Segnare l'esito**

Annotare qui l'esito reale dei passi 2-4 (cosa si è visto davvero). Se un caso non si comporta come atteso, tornare al Task 4 (taratura soglie) — non forzare l'esito.

---

## Self-Review

**Copertura spec (Piano 1 = rung 1 + rung 3 dello spec):**
- Classificatore `clean/messy/screenshot` con segnali cheep e regola conservativa → Task 1-3. ✓
- Validazione su immagini vere (screenshot di Mary) → Task 4. ✓
- Gate all'aggiunta che blocca gli screenshot → Task 6. ✓
- Rete di sicurezza a tinta unita per il backlog al render → Task 5. ✓
- 3D invariato → nessun task lo tocca. ✓
- **Fuori da questo piano:** scontorno gratis on-device (guida al ritaglio +
  `@imgly` + tap-to-cutout SAM) + cache IndexedDB. Va nel Piano 2. Annotato.

**Placeholder scan:** nessun TBD/TODO nel codice. Le uniche dipendenze esterne (immagini reali al Task 4) sono esplicite e con condizione di stop.

**Consistenza dei tipi:** `classifyGarmentImage(imageData) → { verdict, islands, text, reach }` usato identico nei Task 3, 5, 6. `countIslands(mask,width,height,{minSize})` e `textDensity(imageData,{contrast})` coerenti fra definizione (Task 1-2) e uso (Task 3). `backgroundMask` importato con la firma reale di `garmentTexture.js`.

**Nota di rischio onesta:** le soglie del classificatore (`ISLAND_MIN`, `TEXT_MIN`, `REACH_CLEAN`) sono stime; il Task 4 le fissa sulle immagini vere. Se lo screenshot di Mary non fosse separabile dalle foto buone con questi tre segnali, aggiungere un quarto segnale (rettangoli UI a tinta piatta / barra di stato, già previsti nello spec) prima di allargare le soglie e rischiare falsi blocchi.
