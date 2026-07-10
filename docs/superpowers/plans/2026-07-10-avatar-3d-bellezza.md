# Avatar 3D, secondo giro: smettere di incollare la foto

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** L'avatar 3D senza AI deve essere bello. Oggi la foto del capo è incollata come un adesivo curvo: si vede il *disegno* della maglietta (collo, maniche, orli) schiacciato su un torso che ha già la sua forma, e i pantaloni, incollati su un'unica superficie che abbraccia entrambe le gambe, si leggono come una gonna.

**Architecture:** La forma la fa la mesh, il tessuto lo fa la foto. I capi diventano insiemi di parti 3D vere (busto + maniche, due gambe separate). Il materiale usa una **piastrella di tessuto** ritagliata dall'interno del capo (mai i bordi, mai il contorno disegnato), ripetuta. Se la foto contiene una **stampa** riconoscibile (una zona interna di colore molto diverso dal dominante), viene ritagliata e riappoggiata sulla mesh **nel punto in cui stava sul capo fotografato**: un logo sul taschino resta sul taschino, uno sul petto resta sul petto. Sparisce il cilindro-decal che sporgeva.

**Tech Stack:** three.js 0.180, React 19, Vitest (ambiente `node`).

## Global Constraints

- I test girano in ambiente `node` (`vite.config.js`): **nessun DOM, nessun canvas, nessun WebGL.** La matematica sta in utils puri e testati; `Avatar3D.jsx` è cablaggio e si giudica a schermo.
- **Un test che calcola il valore atteso richiamando la funzione sotto test non fallisce mai.** È già successo su questo modulo con `radiusAt`. Ogni test nuovo va provato rompendo il codice: deve diventare rosso.
- `Avatar3D.jsx` resta l'**unico** file che importa three.js, è `export default`, caricato con `React.lazy`. Chunk separato.
- Nessun ciclo di rendering continuo. `devicePixelRatio` ≤ 2.
- Non toccare `src/utils/tryonComposer.js`. I `kind` restano `top | dress | bottom | outerwear | shoes`.
- La rete di sicurezza esistente non si tocca: `onUnavailable`, `Avatar3DBoundary`, `webglcontextlost`, `clearFigure`.
- I 96 test esistenti restano verdi. `npm run build` passa.
- Commit in italiano, footer `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- Nessun asset esterno, nessuna dipendenza nuova: la trama del tessuto si genera da codice.

---

## Task 1: la piastrella di tessuto e la stampa

**Files:** Modify `src/utils/garmentTexture.js`; Test `src/utils/garmentTexture.test.js`

**Interfaces prodotte:**

```js
/**
 * Quadrato tutto interno al capo, da usare come piastrella di tessuto ripetuta.
 * Si parte dal baricentro della maschera e si rimpicciolisce finché ogni pixel
 * del quadrato appartiene al capo: così non entrano mai bordi, cuciture del
 * disegno o sfondo.
 * @returns {{x,y,width,height}|null} null se non c'è spazio (capo troppo sottile)
 */
export function fabricSwatch(mask, width, height, bounds)

/**
 * Zona di stampa: pixel interni al capo il cui colore dista dal dominante più
 * di `minDistance` (Chebyshev). Si restituisce il loro rettangolo solo se è una
 * stampa plausibile: fra lo 0.5% e il 25% dell'area del capo, e non attaccata al
 * bordo del capo (quello sarebbe un'ombra o un orlo, non una stampa).
 * @returns {{x,y,width,height}|null}
 */
export function printRegion(image, mask, dominantHex, { minDistance = 60 } = {})

/**
 * Dove sta la stampa dentro il capo, in frazioni da 0 a 1 del rettangolo del capo.
 * Serve a rimetterla sulla mesh **nello stesso punto in cui stava sul capo vero**:
 * un logo sul taschino resta sul taschino, non finisce in mezzo al petto.
 *
 * `cx`: 0 = bordo sinistro del capo, 0.5 = centro, 1 = bordo destro.
 * `cy`: 0 = orlo alto (spalle), 1 = orlo basso.
 * `w`, `h`: quanto è larga e alta la stampa, sempre in frazioni del capo.
 *
 * @returns {{cx:number, cy:number, w:number, h:number}|null}
 */
export function printPlacement(bounds, print)
```

`extractGarment` restituisce in più `swatch`, `print` e `printAt` (tutti possono essere `null`).

- [ ] **Step 1: Test che falliscono**

In coda a `src/utils/garmentTexture.test.js` (riusa `makeImage`, `WHITE`, `BLUE`):

```js
import { fabricSwatch, printRegion } from './garmentTexture';

const RED = [200, 40, 40];

describe('fabricSwatch', () => {
  it('sta tutto dentro il capo, mai sui bordi', () => {
    const img = makeImage(20, 20, WHITE, BLUE, { x: 5, y: 5, width: 10, height: 10 });
    const mask = backgroundMask(img);
    const bounds = garmentBounds(mask, 20, 20);
    const s = fabricSwatch(mask, 20, 20, bounds);

    expect(s).not.toBeNull();
    for (let y = s.y; y < s.y + s.height; y++) {
      for (let x = s.x; x < s.x + s.width; x++) {
        expect(mask[y * 20 + x]).toBe(1); // ogni pixel della piastrella è capo
      }
    }
  });

  it('restituisce null se il capo è troppo sottile per contenere un quadrato', () => {
    // striscia alta 1 pixel: nessun quadrato di lato >= 2 ci sta dentro
    const img = makeImage(20, 20, WHITE, BLUE, { x: 2, y: 10, width: 16, height: 1 });
    const mask = backgroundMask(img);
    const bounds = garmentBounds(mask, 20, 20);
    expect(fabricSwatch(mask, 20, 20, bounds)).toBeNull();
  });
});

describe('printRegion', () => {
  it('trova la stampa: una macchia rossa dentro un capo blu', () => {
    const img = makeImage(20, 20, WHITE, BLUE, { x: 2, y: 2, width: 16, height: 16 });
    // stampa 4x4 al centro
    for (let y = 8; y < 12; y++) {
      for (let x = 8; x < 12; x++) {
        const i = (y * 20 + x) * 4;
        img.data[i] = RED[0]; img.data[i + 1] = RED[1]; img.data[i + 2] = RED[2];
      }
    }
    const mask = backgroundMask(img);
    const r = printRegion(img, mask, '#284f7f');
    expect(r).toEqual({ x: 8, y: 8, width: 4, height: 4 });
  });

  it('non scambia per stampa un capo in tinta unita', () => {
    const img = makeImage(20, 20, WHITE, BLUE, { x: 2, y: 2, width: 16, height: 16 });
    const mask = backgroundMask(img);
    expect(printRegion(img, mask, '#284f7f')).toBeNull();
  });

  it('non scambia per stampa una macchia che occupa quasi tutto il capo', () => {
    const img = makeImage(20, 20, WHITE, BLUE, { x: 2, y: 2, width: 16, height: 16 });
    for (let y = 3; y < 17; y++) {
      for (let x = 3; x < 17; x++) {
        const i = (y * 20 + x) * 4;
        img.data[i] = RED[0]; img.data[i + 1] = RED[1]; img.data[i + 2] = RED[2];
      }
    }
    const mask = backgroundMask(img);
    expect(printRegion(img, mask, '#284f7f')).toBeNull(); // >25% dell'area
  });

  it('non scambia per stampa una zona attaccata al bordo del capo', () => {
    const img = makeImage(20, 20, WHITE, BLUE, { x: 2, y: 2, width: 16, height: 16 });
    // striscia rossa lungo il bordo sinistro del capo: e' un orlo, non una stampa
    for (let y = 2; y < 18; y++) {
      const i = (y * 20 + 2) * 4;
      img.data[i] = RED[0]; img.data[i + 1] = RED[1]; img.data[i + 2] = RED[2];
    }
    const mask = backgroundMask(img);
    expect(printRegion(img, mask, '#284f7f')).toBeNull();
  });
});

describe('printPlacement', () => {
  // Capo: rettangolo x 10..109, y 20..219 (100 x 200).
  const bounds = { x: 10, y: 20, width: 100, height: 200 };

  it('una stampa al centro esatto risulta al centro', () => {
    // stampa 20x20 centrata: centro (60, 120)
    const p = printPlacement(bounds, { x: 50, y: 110, width: 20, height: 20 });
    expect(p.cx).toBeCloseTo(0.5, 6);
    expect(p.cy).toBeCloseTo(0.5, 6);
    expect(p.w).toBeCloseTo(0.2, 6); // 20/100
    expect(p.h).toBeCloseTo(0.1, 6); // 20/200
  });

  it('un logo sul taschino resta in alto a sinistra, non al centro', () => {
    // stampa 10x10 con angolo (20, 40): centro (25, 45)
    const p = printPlacement(bounds, { x: 20, y: 40, width: 10, height: 10 });
    expect(p.cx).toBeCloseTo(0.15, 6); // (25-10)/100
    expect(p.cy).toBeCloseTo(0.125, 6); // (45-20)/200
    expect(p.cx).toBeLessThan(0.5);
    expect(p.cy).toBeLessThan(0.5);
  });

  it('una scritta sull’orlo basso resta in basso', () => {
    const p = printPlacement(bounds, { x: 40, y: 200, width: 30, height: 10 });
    expect(p.cy).toBeCloseTo(0.925, 6); // (205-20)/200
    expect(p.cy).toBeGreaterThan(0.8);
  });

  it('senza stampa o senza capo non c’è collocazione', () => {
    expect(printPlacement(bounds, null)).toBeNull();
    expect(printPlacement(null, { x: 1, y: 1, width: 1, height: 1 })).toBeNull();
  });
});
```

- [ ] **Step 2:** `npx vitest run src/utils/garmentTexture.test.js` → FAIL (`fabricSwatch is not a function`).

- [ ] **Step 3: Implementazione.** In `src/utils/garmentTexture.js`:

```js
/** Vero se il quadrato di lato `side` con angolo (x,y) è tutto dentro il capo. */
const squareInside = (mask, width, x, y, side) => {
  for (let yy = y; yy < y + side; yy++) {
    for (let xx = x; xx < x + side; xx++) {
      if (!mask[yy * width + xx]) return false;
    }
  }
  return true;
};

export function fabricSwatch(mask, width, height, bounds) {
  if (!bounds) return null;
  // baricentro dei pixel del capo: sta nel pieno del tessuto, non sui bordi
  let sx = 0;
  let sy = 0;
  let n = 0;
  for (let y = bounds.y; y < bounds.y + bounds.height; y++) {
    for (let x = bounds.x; x < bounds.x + bounds.width; x++) {
      if (!mask[y * width + x]) continue;
      sx += x;
      sy += y;
      n++;
    }
  }
  if (!n) return null;
  const cx = Math.round(sx / n);
  const cy = Math.round(sy / n);

  const maxSide = Math.min(bounds.width, bounds.height);
  for (let side = maxSide; side >= 2; side--) {
    const x = Math.max(0, Math.min(width - side, cx - (side >> 1)));
    const y = Math.max(0, Math.min(height - side, cy - (side >> 1)));
    if (squareInside(mask, width, x, y, side)) {
      return { x, y, width: side, height: side };
    }
  }
  return null;
}

const hexToRgb = (hex) => [
  parseInt(hex.slice(1, 3), 16),
  parseInt(hex.slice(3, 5), 16),
  parseInt(hex.slice(5, 7), 16),
];

/** Vero se il pixel `p` tocca lo sfondo: sta sul bordo del capo. */
const onGarmentEdge = (mask, width, height, p) => {
  const x = p % width;
  const y = (p - x) / width;
  if (x === 0 || y === 0 || x === width - 1 || y === height - 1) return true;
  return (
    !mask[p - 1] || !mask[p + 1] || !mask[p - width] || !mask[p + width]
  );
};

const PRINT_MIN_AREA = 0.005;
const PRINT_MAX_AREA = 0.25;

export function printRegion(image, mask, dominantHex, { minDistance = 60 } = {}) {
  const { data, width, height } = image;
  const [dr, dg, db] = hexToRgb(dominantHex);

  let minX = width;
  let minY = height;
  let maxX = -1;
  let maxY = -1;
  let printPixels = 0;
  let garmentPixels = 0;

  for (let p = 0; p < mask.length; p++) {
    if (!mask[p]) continue;
    garmentPixels++;
    const i = p * 4;
    if (colorDistance(data, i, dr, dg, db) <= minDistance) continue;
    // Una zona attaccata al bordo del capo è un orlo, un'ombra, una cucitura:
    // non è una stampa. Se ne trovo anche solo un pixel, rinuncio.
    if (onGarmentEdge(mask, width, height, p)) return null;
    printPixels++;
    const x = p % width;
    const y = (p - x) / width;
    if (x < minX) minX = x;
    if (x > maxX) maxX = x;
    if (y < minY) minY = y;
    if (y > maxY) maxY = y;
  }

  if (!garmentPixels || maxX < 0) return null;
  const share = printPixels / garmentPixels;
  if (share < PRINT_MIN_AREA || share > PRINT_MAX_AREA) return null;

  return { x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1 };
}
```

```js
/**
 * Dove sta la stampa dentro il capo, in frazioni del rettangolo del capo.
 * È ciò che permette di rimetterla sulla mesh nello stesso punto in cui stava
 * sul capo fotografato, invece di piazzarla sempre in mezzo al petto.
 */
export function printPlacement(bounds, print) {
  if (!bounds || !print) return null;
  return {
    cx: (print.x + print.width / 2 - bounds.x) / bounds.width,
    cy: (print.y + print.height / 2 - bounds.y) / bounds.height,
    w: print.width / bounds.width,
    h: print.height / bounds.height,
  };
}
```

E in `extractGarment`, nel ramo `ok`, aggiungi al valore restituito:

```js
    swatch: fabricSwatch(mask, width, height, bounds),
    print,                              // calcolata una volta sola, vedi sotto
    printAt: printPlacement(bounds, print),
```

dove `print` va calcolata **una volta**, prima del `return`, riusando il colore
dominante già calcolato (non ricalcolarlo: costa una scansione dell'immagine):

```js
  const dominantHex = dominantColor(image, mask);
  const bounds = garmentBounds(mask, width, height);
  const print = printRegion(image, mask, dominantHex);
```

Nel ramo degradato: `swatch: null, print: null, printAt: null`.

- [ ] **Step 4:** `npx vitest run src/utils/garmentTexture.test.js` → PASS. Poi `npm test` → tutti verdi.

- [ ] **Step 5: Prova di mutazione.** Togli il controllo `onGarmentEdge` e verifica che il test "non scambia per stampa una zona attaccata al bordo" diventi **rosso**. Rimetti. Riporta l'output di entrambe.

- [ ] **Step 6: Commit**

```bash
git add src/utils/garmentTexture.js src/utils/garmentTexture.test.js
git commit -m "Dalla foto: la piastrella di tessuto e la zona di stampa

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: i capi diventano parti 3D vere

**Files:** Modify `src/utils/garmentMesh.js`; Test `src/utils/garmentMesh.test.js`

**Il difetto da rimuovere:** oggi un capo è un solo guscio di rotazione. Una maglietta senza maniche sembra una canotta con un bavaglio; i pantaloni sono due gusci ma la fantasia li univa in una colonna.

**Interfaccia prodotta:**

```js
/**
 * Le parti 3D di un capo. Ogni parte è un profilo da ruotare attorno all'asse,
 * con lo scostamento laterale a cui va messa. `mirror: true` significa "istanzia
 * anche a -offsetX" (le due maniche, le due gambe).
 * @returns {{ profile: [number,number][], offsetX: number, mirror: boolean }[]}
 */
export function garmentParts(kind, config)
```

Composizione per tipo (le campate del busto restano quelle di `SPANS`):

| kind | parti |
|---|---|
| `top` | guscio del busto + due maniche corte sul braccio (da 1.42 a 1.24) |
| `dress` | guscio busto+gonna + due maniche corte (da 1.42 a 1.24) |
| `outerwear` | guscio del busto + due maniche lunghe (da 1.44 a 0.98) |
| `bottom` | due gambe (`mirror: true`), nessuna manica |
| `shoes` | due scarpe (`mirror: true`) |

Le maniche sono gusci del profilo `arm` di `bodyProfiles`, con lo stesso `GARMENT_GAP` del capo e `offsetX = body.armOffsetX`.

`garmentProfile` resta esportata e invariata (la usano i test esistenti e `decalBounds`).

- [ ] **Step 1: Test che falliscono**

```js
import { garmentParts } from './garmentMesh';

describe('garmentParts', () => {
  it('il top ha il busto e due maniche', () => {
    const parts = garmentParts('top', cfg);
    expect(parts).toHaveLength(2); // busto + manica (mirror la raddoppia)
    expect(parts[0].mirror).toBe(false);
    expect(parts[1].mirror).toBe(true);
    expect(parts[1].offsetX).toBeGreaterThan(0);
  });

  it('le maniche del capospalla arrivano più in basso di quelle del top', () => {
    const lowestY = (part) => Math.min(...part.profile.map(([, y]) => y));
    expect(lowestY(garmentParts('outerwear', cfg)[1])).toBeLessThan(
      lowestY(garmentParts('top', cfg)[1])
    );
  });

  it('i pantaloni sono due gambe rispecchiate, senza maniche', () => {
    const parts = garmentParts('bottom', cfg);
    expect(parts).toHaveLength(1);
    expect(parts[0].mirror).toBe(true);
    expect(parts[0].offsetX).toBeCloseTo(bodyProfiles(cfg).legOffsetX, 9);
  });

  it('le maniche stanno fuori dal braccio a ogni quota', () => {
    const body = bodyProfiles(cfg);
    const sleeve = garmentParts('top', cfg)[1];
    for (const [r, y] of sleeve.profile.slice(1, -1)) {
      expect(r).toBeGreaterThan(radiusAt(body.arm, y));
    }
  });

  it('restituisce lista vuota per un tipo sconosciuto', () => {
    expect(garmentParts('cappello', cfg)).toEqual([]);
  });
});
```

- [ ] **Step 2:** eseguili, devono fallire.

- [ ] **Step 3: Implementazione.** In `src/utils/garmentMesh.js`, aggiungi:

```js
/** Campate delle maniche, per tipo. Assenti dove il capo non ne ha. */
const SLEEVES = {
  top: { from: 1.24, to: 1.42 },
  dress: { from: 1.24, to: 1.42 },
  outerwear: { from: 0.98, to: 1.44 },
};

/** Costruisce il profilo di un guscio attorno a `source`, fra due quote. */
const shell = (source, from, to, gap) => {
  const profile = [[0.001, from]];
  for (let i = 0; i <= STEPS; i++) {
    const y = from + ((to - from) * i) / STEPS;
    profile.push([radiusAt(source, y) + gap, y]);
  }
  profile.push([0.001, to]);
  return profile;
};

export function garmentParts(kind, config) {
  const span = SPANS[kind];
  if (!span) return [];

  const body = bodyProfiles(config);
  const parts = [];

  const main = garmentProfile(kind, config);
  parts.push({ profile: main.profile, offsetX: main.offsetX, mirror: main.doubled });

  const sleeve = SLEEVES[kind];
  if (sleeve) {
    parts.push({
      profile: shell(body.arm, sleeve.from, sleeve.to, span.gap),
      offsetX: body.armOffsetX,
      mirror: true,
    });
  }
  return parts;
}
```

Rifattorizza `garmentProfile` perché usi `shell(...)` invece di ripetere il ciclo: **una sola costruzione di guscio in tutto il file.**

- [ ] **Step 4:** test verdi, `npm test` verde.

- [ ] **Step 5: Prova di mutazione.** Togli il `+ gap` da `shell` e verifica che "le maniche stanno fuori dal braccio" diventi **rosso**. Rimetti.

- [ ] **Step 6: Commit**

```bash
git add src/utils/garmentMesh.js src/utils/garmentMesh.test.js
git commit -m "I capi 3D hanno le maniche: parti vere, non un guscio solo

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: `garmentImage.js` produce tessuto e stampa

**Files:** Modify `src/utils/garmentImage.js`

`GarmentTexture` diventa:

```js
/**
 * @typedef {Object} GarmentTexture
 * @property {string|null} textureUrl  PNG del capo intero scontornato (serve alla modalità piatta)
 * @property {string|null} swatchUrl   PNG della piastrella di tessuto, da ripetere sulla mesh
 * @property {string|null} printUrl    PNG della sola stampa, sfondo trasparente
 * @property {string} colorHex
 * @property {'texture'|'flat'} kind
 * @property {string|null} reason
 */
```

`cutout(imageData, mask, bounds)` esiste già: riusala per ritagliare, ma **fai attenzione** — oggi azzera l'alpha dei pixel di sfondo **modificando `imageData` sul posto**. Chiamarla tre volte sullo stesso `imageData` va bene solo perché l'operazione è idempotente; per la piastrella e la stampa servono ritagli **diversi**. Estrai una funzione `cropToDataUrl(imageData, rect)` che ritaglia senza toccare l'alpha, e usa `cutout` solo per il capo intero.

Per la stampa, i pixel fuori dalla zona di stampa vanno resi trasparenti: solo i pixel che distano dal dominante più di 60 restano opachi.

Nei rami degradati: `swatchUrl: null, printUrl: null`.

- [ ] Implementa, `npm test` (96+ verdi), `npm run build`, commit:
  `"Tessuto e stampa arrivano fino al 3D"`

---

## Task 4: la scena, rifatta

**Files:** Modify `src/components/Avatar/Avatar3D.jsx`

- [ ] **Via il decal cilindrico.** `frontDecal` sparisce, e con lei l'artefatto della piastra che sporge di lato. `decalBounds` resta in `garmentMesh.js` **solo se serve ancora**: se non la usa più nessuno, cancellala insieme ai suoi test (codice morto).

- [ ] **Ogni capo si costruisce da `garmentParts(kind, config)`**: una mesh per parte, e per le parti con `mirror: true` due mesh a `±offsetX`.

- [ ] **Materiale del capo:** `MeshStandardMaterial({ map: swatchTexture, color: 0xffffff, roughness: 0.95 })` dove `swatchTexture` è la piastrella caricata da `swatchUrl`, con `wrapS = wrapT = RepeatWrapping` e `repeat.set(3, 3)`. Se `swatchUrl` è `null`, niente mappa: `color: safeColor(colorHex)`. La piastrella è tessuto vero preso dalla foto, quindi righe e quadri si vedono; il contorno disegnato del capo no.

- [ ] **La stampa, dove stava davvero.** Solo se `printUrl` e `printAt` non sono nulli. `printAt` dice, in frazioni del capo fotografato, dove stava la stampa e quanto era grande. La si rimette **nello stesso punto** sulla parte principale del capo:

```js
  // La parte principale del capo va da `from` a `to` (SPANS[kind]).
  // `printAt.cy` è misurata dall'alto del capo, mentre y cresce verso l'alto.
  const y = to - printAt.cy * (to - from);
  const patchHeight = printAt.h * (to - from);

  // `printAt.cx` = 0.5 è il centro del davanti. Lo scarto orizzontale diventa un
  // angolo attorno all'asse: la stampa gira col corpo, resta incollata al tessuto.
  const theta = (printAt.cx - 0.5) * DECAL_ARC;

  // Larghezza in radianti, proporzionale a quanto era larga sul capo.
  const arc = printAt.w * DECAL_ARC;
```

Il piano è un settore di cilindro di apertura `arc`, alto `patchHeight`, al raggio del capo a quella quota (`radiusAt(mainProfile, y) + 0.004`), con `thetaStart = theta - arc / 2`. Texturizzato con `printUrl`, `transparent: true`, stesso `polygonOffset` di prima.

Così un logo sul taschino resta sul taschino e uno sull'orlo resta sull'orlo.

**Attenzione ai capi con `mirror: true` (i pantaloni).** Lì `printAt.cx` è misurata sull'intera foto, che contiene **due gambe**: una scritta sulla tasca sinistra ha `cx ≈ 0.25`. Trasformarla direttamente in un angolo attorno all'asse di *una* gamba la manderebbe nel posto sbagliato. Va prima scelta la gamba, poi ricalcolata la frazione dentro quella gamba:

```js
  if (part.mirror) {
    const onLeft = printAt.cx < 0.5;
    instanceX = onLeft ? -part.offsetX : part.offsetX;
    // rimappa 0..0.5 -> 0..1 (gamba sinistra), 0.5..1 -> 0..1 (gamba destra)
    localCx = onLeft ? printAt.cx * 2 : (printAt.cx - 0.5) * 2;
    // e la larghezza raddoppia in frazione, perché il riferimento è mezzo capo
    localW = printAt.w * 2;
  }
```

La stampa va poi su **una sola** istanza, quella scelta: altrimenti la stessa scritta compare su entrambe le gambe.

Se `localW > 1` (la stampa attraversa entrambe le gambe: non è una stampa da tasca, è una fantasia diffusa) **si rinuncia**: se ne occupa già la piastrella di tessuto.

- [ ] **Ombra a terra:** un `CircleGeometry` orizzontale a `y = 0.002`, materiale nero con `opacity: 0.18`, `transparent: true`, senza luci (`MeshBasicMaterial`). Non è un'ombra vera, è un contatto: costa zero e toglie l'effetto "figura che galleggia".

- [ ] **Luci:** alza il contrasto — `AmbientLight(0xffffff, 1.1)`, chiave `DirectionalLight(0xffffff, 2.0)` da `(2, 4, 3)`, controluce `DirectionalLight(0xffffff, 0.7)` da `(-3, 2, -2)`. Niente ombre proiettate.

- [ ] `npm test`, `npm run build` (chunk `Avatar3D-*.js` separato), commit:
  `"La forma la fa la mesh, il tessuto la foto: via l'adesivo curvo"`

---

## Task 5: la modalità piatta, tarata

**Files:** Modify `src/components/Avatar/AvatarSvg.jsx`

La bambolina di carta va bene com'è — è onesta, si capisce cos'è. Vanno solo tarati i riquadri di ancoraggio, guardando lo schermo:

- [ ] Le maniche del top escono dal corpo e le braccia lo bucano: allarga `top` e alza di poco l'ancoraggio.
- [ ] L'orlo del top copre la cintura dei jeans, e a destra spunta un frammento di cintura: abbassa il top o accorcia il bottom in cima.
- [ ] I jeans finiscono sopra la caviglia: allunga il riquadro `bottom` fino ai piedi.

Non c'è test automatico: si guarda. Screenshot prima/dopo.

- [ ] Commit: `"Modalita' piatta: maniche, orlo e lunghezza dei jeans tarati"`

---

## Task 6: verifica a schermo

- [ ] `mv .env.local .env.local.bak`, `npm run dev`, Chrome via `playwright-core` (`channel: 'chrome'`).
- [ ] Vestire top + bottom + scarpe con foto sintetiche di capi su sfondo uniforme (una con stampa, una in tinta unita, una a righe per provare la piastrella).
- [ ] Controllare, uno per uno: le maniche ci sono; i pantaloni sono **due gambe**, non una gonna; nessuna piastra che sporge ruotando; l'ombra a terra c'è; un capo in tinta unita non inventa stampe.
- [ ] **La prova della coerenza della stampa.** Preparare due magliette identiche salvo la posizione del logo: una col logo **al centro del petto**, una col logo **in alto a sinistra, sul taschino**. Vestirle una dopo l'altra: il logo deve comparire nei due punti diversi, corrispondenti alla foto. Se compare nello stesso punto in entrambi i casi, `printAt` non viene usata e il compito **non è fatto**. Screenshot affiancati.
- [ ] Provare anche dei jeans con una scritta su **una sola** tasca: deve comparire su una gamba sola, quella giusta.
- [ ] Ruotare di 360°: nessun artefatto.
- [ ] Zero errori in console. Screenshot in `docs/verifiche/2026-07-10-avatar-bellezza/`.
- [ ] Ripristinare `.env.local`.

---

## Autoverifica del piano

**Copertura.** "Forme vere" → Task 2 e 4. "Colore e tessuto dalla foto" → Task 1, 3, 4. "La stampa dove sta davvero sul capo" (richiesta di Lorenzo: «sarebbe carino vedere dove è posizionato nel capo e mantenere quella coerenza») → Task 1 (`printRegion` + `printPlacement`), 3 (`printUrl`), 4 (il piano curvo collocato con `printAt`). "Via la piastra che sporge" → Task 4, primo punto. Modalità piatta → Task 5.

**Coerenza dei tipi.** `fabricSwatch`/`printRegion` (Task 1) restituiscono rettangoli `{x,y,width,height}|null`; `printPlacement` restituisce `{cx,cy,w,h}|null` in frazioni. `extractGarment` li espone come `swatch`/`print`/`printAt`; `garmentImage.js` (Task 3) li trasforma in `swatchUrl`/`printUrl` conservando `printAt`; `Avatar3D.jsx` (Task 4) li consuma con quei nomi. `garmentParts` (Task 2) restituisce `{profile, offsetX, mirror}` e il Task 4 legge quei tre campi.

**Rischio dichiarato.** `printRegion` è euristica. Rifiuta in silenzio (`null`) più spesso di quanto sbagli: soglie strette, niente stampa attaccata al bordo, area fra 0.5% e 25%. Il caso peggiore è *non* mostrare una stampa che c'era, non inventarne una che non c'è. È la direzione giusta in cui sbagliare.

**Cosa questo piano non risolve.** La testa non ha volto. Il capo resta di forma generica: una maglietta è "una maglietta". Chi vuole il proprio capo esatto addosso usa la scheda "Sulla tua foto (AI)".
