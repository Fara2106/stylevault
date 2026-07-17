# Armocromia Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Da una foto, l'app legge pelle/capelli/occhi on-device, determina la sotto-stagione (12 toni) e propone palette, outfit con link shop, capi del guardaroba in palette e make-up — pagina `/armocromia` dal Profilo.

**Architecture:** Estrazione (MediaPipe, sottile, degrada a null) separata dalla logica pura (campionamento colore, classificatore a centroidi nei 3 assi Lab, dataset stagioni, link shop, match guardaroba — tutta TDD) e dalla UI. Persistenza nel profilo (locale + colonna `armocromia jsonb`).

**Tech Stack:** React+Vite, vitest, `@mediapipe/tasks-vision` (già in uso: `bodyAnalysis.js`), i18next. Zero nuove dipendenze.

**Spec:** `docs/superpowers/specs/2026-07-17-armocromia-design.md`

**NOTA di taratura:** formule degli assi, centroidi `SEASON_AXES` e le 12 fixture
sono stati PROTOTIPATI E VALIDATI in node prima di scrivere questo piano
(12/12 corrette; senza occhi le scure restano corrette; senza capelli la
confidenza scende sotto 0.3). Copiare i valori ESATTAMENTE: non sono indicativi.

## Global Constraints

- Tutto **on-device e gratis**: nessuna chiamata a API di analisi; MediaPipe/WASM da CDN come già fa `bodyAnalysis.js` (solo download di file, la foto non lascia il dispositivo).
- Branch: `feat/armocromia`. Dopo OGNI task: `npm test` verde **e** `npm run build` ok.
- `it.json` e `en.json` con set di chiavi **identici** dopo ogni task che li tocca.
- I moduli di "Su di te" (`modelImage/modelComposer/modelWarp/tryonComposer/garmentImage/personSilhouette/bodyAnalysis`) NON cambiano — `bodyAnalysis.js` si USA soltanto (import di `segmentBody`, `SEG_FACE_SKIN`, `SEG_HAIR`).
- Funzioni pure senza DOM/rete per tutto ciò che è testato; MediaPipe solo in `faceColorAnalysis.js` (import dinamico, ogni fallimento ⇒ null).
- Gli id stagione sono ESATTAMENTE i 12 di `SEASON_AXES` (Task 2); `armocromiaSeasons.js` e i18n devono usarli identici.

---

### Task 1: Fondamenta colore (`colorSampling.js`, puro)

**Files:**
- Create: `src/utils/colorSampling.js`
- Test: `src/utils/colorSampling.test.js`

**Interfaces:**
- Produces: `hexToRgb(hex)→{r,g,b}|null`, `rgbToHex({r,g,b})→'#rrggbb'`,
  `rgbToLab({r,g,b})→{L,a,b}`, `labToRgb({L,a,b})→{r,g,b}` (clampata 0-255),
  `deltaE(lab1,lab2)→number` (CIE76),
  `representativeColor(pixels, {trim=0.15}={})→'#rrggbb'|null` (pixels=`[{r,g,b}]`; ordina per L, scarta `floor(n*trim)` per estremo, mediana per canale in Lab, riconverte; `null` se vuoto),
  `maskedPixels(imageData, categories, wanted, maxSamples=4000)→[{r,g,b}]` (imageData=`{data,width,height}`; `categories` Uint8Array parallela ai pixel; `wanted` array di classi; passo di campionamento per non superare maxSamples).

- [ ] **Step 1: Test che fallisce**

```js
import { describe, it, expect } from 'vitest';
import {
  hexToRgb, rgbToHex, rgbToLab, labToRgb, deltaE,
  representativeColor, maskedPixels,
} from './colorSampling';

describe('conversioni', () => {
  it('hex↔rgb', () => {
    expect(hexToRgb('#ff8000')).toEqual({ r: 255, g: 128, b: 0 });
    expect(hexToRgb('zzz')).toBeNull();
    expect(rgbToHex({ r: 255, g: 128, b: 0 })).toBe('#ff8000');
  });
  it('rgbToLab su valori noti (D65)', () => {
    const white = rgbToLab({ r: 255, g: 255, b: 255 });
    expect(white.L).toBeCloseTo(100, 0);
    expect(Math.abs(white.a)).toBeLessThan(0.5);
    const black = rgbToLab({ r: 0, g: 0, b: 0 });
    expect(black.L).toBeCloseTo(0, 0);
    const red = rgbToLab({ r: 255, g: 0, b: 0 });
    expect(red.L).toBeCloseTo(53.2, 0);
    expect(red.a).toBeGreaterThan(70);
  });
  it('roundtrip rgb→lab→rgb entro ±2', () => {
    for (const c of [{ r: 12, g: 200, b: 99 }, { r: 240, g: 219, b: 200 }]) {
      const back = labToRgb(rgbToLab(c));
      expect(Math.abs(back.r - c.r)).toBeLessThanOrEqual(2);
      expect(Math.abs(back.g - c.g)).toBeLessThanOrEqual(2);
      expect(Math.abs(back.b - c.b)).toBeLessThanOrEqual(2);
    }
  });
  it('deltaE: zero su se stesso, simmetrica, cresce con la distanza', () => {
    const a = rgbToLab({ r: 100, g: 50, b: 50 });
    const b = rgbToLab({ r: 110, g: 60, b: 55 });
    const c = rgbToLab({ r: 20, g: 200, b: 240 });
    expect(deltaE(a, a)).toBe(0);
    expect(deltaE(a, b)).toBeCloseTo(deltaE(b, a), 10);
    expect(deltaE(a, c)).toBeGreaterThan(deltaE(a, b));
  });
});

describe('representativeColor', () => {
  it('con 8 pixel identici + 1 nero + 1 bianco, il taglio li scarta', () => {
    const mid = { r: 106, g: 137, b: 165 };
    const px = [...Array(8).fill(mid), { r: 0, g: 0, b: 0 }, { r: 255, g: 255, b: 255 }];
    expect(representativeColor(px)).toBe(rgbToHex(mid));
  });
  it('vuoto → null', () => {
    expect(representativeColor([])).toBeNull();
  });
});

describe('maskedPixels', () => {
  it('estrae solo i pixel delle classi volute', () => {
    // 2x2: [classe0, classe4, classe4, classe1]
    const imageData = {
      width: 2, height: 2,
      data: new Uint8ClampedArray([
        1, 2, 3, 255,   10, 20, 30, 255,
        40, 50, 60, 255, 7, 8, 9, 255,
      ]),
    };
    const categories = new Uint8Array([0, 4, 4, 1]);
    expect(maskedPixels(imageData, categories, [4])).toEqual([
      { r: 10, g: 20, b: 30 }, { r: 40, g: 50, b: 60 },
    ]);
  });
  it('rispetta maxSamples con passo di campionamento', () => {
    const n = 100;
    const imageData = { width: 10, height: 10, data: new Uint8ClampedArray(n * 4).fill(50) };
    const categories = new Uint8Array(n).fill(2);
    expect(maskedPixels(imageData, categories, [2], 10).length).toBeLessThanOrEqual(10);
  });
});
```

- [ ] **Step 2: Verifica che fallisca**

Run: `npx vitest run src/utils/colorSampling.test.js`
Expected: FAIL (modulo assente)

- [ ] **Step 3: Implementazione**

```js
/**
 * Fondamenta colore per l'armocromia: conversioni sRGB↔Lab (D65), distanza
 * percettiva CIE76 e campionamento robusto di regioni di pixel.
 * Puro: nessun DOM, nessuna rete. Unico posto per la matematica Lab.
 */

export const hexToRgb = (hex) => {
  const m = /^#?([0-9a-f]{6})$/i.exec(hex || '');
  if (!m) return null;
  const n = parseInt(m[1], 16);
  return { r: (n >> 16) & 255, g: (n >> 8) & 255, b: n & 255 };
};

export const rgbToHex = ({ r, g, b }) =>
  `#${[r, g, b].map((v) => Math.round(v).toString(16).padStart(2, '0')).join('')}`;

const srgbToLinear = (c) => {
  const v = c / 255;
  return v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4;
};
const linearToSrgb = (v) =>
  255 * (v <= 0.0031308 ? 12.92 * v : 1.055 * v ** (1 / 2.4) - 0.055);

export const rgbToLab = ({ r, g, b }) => {
  const R = srgbToLinear(r), G = srgbToLinear(g), B = srgbToLinear(b);
  const X = (0.4124564 * R + 0.3575761 * G + 0.1804375 * B) / 0.95047;
  const Y = 0.2126729 * R + 0.7151522 * G + 0.072175 * B;
  const Z = (0.0193339 * R + 0.119192 * G + 0.9503041 * B) / 1.08883;
  const f = (t) => (t > 0.008856 ? Math.cbrt(t) : 7.787 * t + 16 / 116);
  const fx = f(X), fy = f(Y), fz = f(Z);
  return { L: 116 * fy - 16, a: 500 * (fx - fy), b: 200 * (fy - fz) };
};

export const labToRgb = ({ L, a, b }) => {
  const fy = (L + 16) / 116;
  const fx = fy + a / 500;
  const fz = fy - b / 200;
  const inv = (t) => (t ** 3 > 0.008856 ? t ** 3 : (t - 16 / 116) / 7.787);
  const X = inv(fx) * 0.95047, Y = inv(fy), Z = inv(fz) * 1.08883;
  const R = 3.2404542 * X - 1.5371385 * Y - 0.4985314 * Z;
  const G = -0.969266 * X + 1.8760108 * Y + 0.041556 * Z;
  const B = 0.0556434 * X - 0.2040259 * Y + 1.0572252 * Z;
  const clamp = (v) => Math.max(0, Math.min(255, Math.round(linearToSrgb(v))));
  return { r: clamp(R), g: clamp(G), b: clamp(B) };
};

/** Distanza percettiva CIE76: sufficiente per palette e guardaroba. */
export const deltaE = (l1, l2) =>
  Math.sqrt((l1.L - l2.L) ** 2 + (l1.a - l2.a) ** 2 + (l1.b - l2.b) ** 2);

/**
 * Colore rappresentativo di una regione: Lab, ordina per L, scarta gli
 * estremi (ombre/riflessi), mediana per canale, riconverte in hex.
 */
export function representativeColor(pixels, { trim = 0.15 } = {}) {
  if (!pixels || pixels.length === 0) return null;
  const labs = pixels.map(rgbToLab).sort((p, q) => p.L - q.L);
  const cut = Math.floor(labs.length * trim);
  const kept = labs.slice(cut, labs.length - cut);
  if (kept.length === 0) return null;
  const median = (arr) => {
    const s = [...arr].sort((x, y) => x - y);
    const m = s.length >> 1;
    return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
  };
  return rgbToHex(labToRgb({
    L: median(kept.map((p) => p.L)),
    a: median(kept.map((p) => p.a)),
    b: median(kept.map((p) => p.b)),
  }));
}

/**
 * Pixel RGB delle classi volute da una maschera di segmentazione parallela
 * all'imageData. Campiona a passo costante per non superare maxSamples.
 */
export function maskedPixels(imageData, categories, wanted, maxSamples = 4000) {
  const want = new Set(wanted);
  const idx = [];
  for (let i = 0; i < categories.length; i++) if (want.has(categories[i])) idx.push(i);
  const step = Math.max(1, Math.ceil(idx.length / maxSamples));
  const out = [];
  for (let k = 0; k < idx.length; k += step) {
    const o = idx[k] * 4;
    out.push({ r: imageData.data[o], g: imageData.data[o + 1], b: imageData.data[o + 2] });
  }
  return out;
}
```

- [ ] **Step 4: Verifica che passi**

Run: `npx vitest run src/utils/colorSampling.test.js`
Expected: PASS (8 test)

- [ ] **Step 5: Commit**

```bash
git add src/utils/colorSampling.js src/utils/colorSampling.test.js
git commit -m "feat(armocromia): fondamenta colore — Lab, deltaE, campionamento robusto"
```

---

### Task 2: Classificatore a 12 stagioni (`armocromiaClassifier.js`, puro — cuore)

**Files:**
- Create: `src/utils/armocromiaClassifier.js`
- Test: `src/utils/armocromiaClassifier.test.js`

**Interfaces:**
- Consumes: `hexToRgb`, `rgbToLab` da `./colorSampling`.
- Produces: `classifySeason({skin,hair,eyes})→{season,axes:{lightDeep,warmCool,brightSoft},confidence}|null` (hex o null per campo; `null` se mancano SIA pelle SIA capelli), `SEASON_AXES` (oggetto con i 12 id stagione → centroidi; è la lista canonica degli id).

**I valori numerici qui sotto sono TARATI (12/12 sul prototipo): copiarli esatti.**

- [ ] **Step 1: Test che fallisce**

```js
import { describe, it, expect } from 'vitest';
import { classifySeason, SEASON_AXES } from './armocromiaClassifier';

// Terne rappresentative (pelle, capelli, occhi) — una per stagione.
const FIXTURES = {
  'light-spring': { skin: '#f7dcc9', hair: '#e9c98f', eyes: '#8fb6a8' },
  'light-summer': { skin: '#f0d9d2', hair: '#cfc4b0', eyes: '#a9c1cf' },
  'true-spring': { skin: '#edc39e', hair: '#a9752e', eyes: '#6f8f55' },
  'true-summer': { skin: '#e6c4bd', hair: '#7e7468', eyes: '#6f8dad' },
  'true-autumn': { skin: '#cf9c6b', hair: '#6b4423', eyes: '#63512c' },
  'true-winter': { skin: '#e3c0b8', hair: '#2e2a28', eyes: '#4f6b8f' },
  'bright-spring': { skin: '#f4cdb0', hair: '#a86f2f', eyes: '#2e8b74' },
  'bright-winter': { skin: '#f0cabe', hair: '#221d1c', eyes: '#1e63c8' },
  'soft-autumn': { skin: '#ddb394', hair: '#8a6b4a', eyes: '#84805f' },
  'soft-summer': { skin: '#e5c6bf', hair: '#9a8f83', eyes: '#8496a0' },
  'deep-autumn': { skin: '#b97f4e', hair: '#4a2d17', eyes: '#5a3d20' },
  'deep-winter': { skin: '#a9765c', hair: '#1d1a19', eyes: '#3a4a63' },
};

describe('classifySeason', () => {
  for (const [season, input] of Object.entries(FIXTURES)) {
    it(`riconosce ${season}`, () => {
      expect(classifySeason(input).season).toBe(season);
    });
  }
  it('espone assi e confidenza', () => {
    const r = classifySeason(FIXTURES['deep-winter']);
    expect(r.axes.lightDeep).toBeLessThan(0);
    expect(r.confidence).toBeGreaterThan(0);
    expect(r.confidence).toBeLessThanOrEqual(1);
  });
  it('senza occhi le stagioni scure restano corrette', () => {
    expect(classifySeason({ ...FIXTURES['deep-winter'], eyes: null }).season).toBe('deep-winter');
    expect(classifySeason({ ...FIXTURES['true-autumn'], eyes: null }).season).toBe('true-autumn');
  });
  it('senza capelli la confidenza crolla (la UI inviterà a correggere)', () => {
    const r = classifySeason({ ...FIXTURES['light-spring'], hair: null });
    expect(r.confidence).toBeLessThan(0.3);
  });
  it('senza pelle e capelli → null', () => {
    expect(classifySeason({ skin: null, hair: null, eyes: '#4f6b8f' })).toBeNull();
  });
  it('SEASON_AXES ha esattamente i 12 id', () => {
    expect(Object.keys(SEASON_AXES).sort()).toEqual([
      'bright-spring', 'bright-winter', 'deep-autumn', 'deep-winter',
      'light-spring', 'light-summer', 'soft-autumn', 'soft-summer',
      'true-autumn', 'true-spring', 'true-summer', 'true-winter',
    ]);
  });
});
```

- [ ] **Step 2: Verifica che fallisca**

Run: `npx vitest run src/utils/armocromiaClassifier.test.js`
Expected: FAIL (modulo assente)

- [ ] **Step 3: Implementazione**

```js
/**
 * Classificatore armocromia a 12 sotto-stagioni (sistema sci-art).
 * Tre assi da pelle/capelli/occhi in Lab:
 *   lightDeep  — valore (chiaro>0, scuro<0), capelli col peso maggiore;
 *   warmCool   — sottotono (caldo>0): componente gialla b al netto del rosa;
 *   brightSoft — croma di occhi/pelle/capelli + contrasto capelli↔pelle.
 * Stagione = centroide più vicino in questo spazio (sottotono pesato di più:
 * caldo/freddo è l'asse primario dell'armocromia). Numeri TARATI su fixture
 * validate: non ritoccare senza rifare la taratura.
 */
import { hexToRgb, rgbToLab } from './colorSampling';

export const SEASON_AXES = {
  'light-spring': { lightDeep: 0.9, warmCool: 0.5, brightSoft: -0.45 },
  'light-summer': { lightDeep: 0.9, warmCool: -0.4, brightSoft: -0.85 },
  'true-spring': { lightDeep: 0.3, warmCool: 1.3, brightSoft: 0.3 },
  'true-summer': { lightDeep: 0.3, warmCool: -0.5, brightSoft: -0.5 },
  'true-autumn': { lightDeep: -0.2, warmCool: 1.1, brightSoft: 0.1 },
  'true-winter': { lightDeep: -0.3, warmCool: -0.7, brightSoft: -0.15 },
  'bright-spring': { lightDeep: 0.3, warmCool: 0.85, brightSoft: 0.75 },
  'bright-winter': { lightDeep: -0.25, warmCool: -0.85, brightSoft: 0.55 },
  'soft-autumn': { lightDeep: 0.15, warmCool: 0.6, brightSoft: -0.45 },
  'soft-summer': { lightDeep: 0.45, warmCool: -0.35, brightSoft: -0.9 },
  'deep-autumn': { lightDeep: -0.55, warmCool: 1.0, brightSoft: 0.1 },
  'deep-winter': { lightDeep: -0.75, warmCool: -0.3, brightSoft: -0.3 },
};

// Il sottotono è l'asse primario dell'armocromia: pesa di più nella distanza.
const AXIS_WEIGHT = { lightDeep: 1, warmCool: 1.4, brightSoft: 1 };

const toLab = (hex) => {
  const rgb = hexToRgb(hex);
  return rgb ? rgbToLab(rgb) : null;
};

/** Media pesata che ignora i termini null e rinormalizza i pesi. */
const wsum = (pairs) => {
  const act = pairs.filter(([v]) => v !== null && v !== undefined);
  if (act.length === 0) return null;
  const tot = act.reduce((t, [, w]) => t + w, 0);
  return act.reduce((t, [v, w]) => t + v * (w / tot), 0);
};

export function computeAxes({ skin, hair, eyes }) {
  const s = skin ? toLab(skin) : null;
  const h = hair ? toLab(hair) : null;
  const e = eyes ? toLab(eyes) : null;

  const value = wsum([[h && h.L, 0.5], [s && s.L, 0.35], [e && e.L, 0.15]]);
  const lightDeep = (value - 53) / 34;

  const warmOf = (lab, bNeutral) => (lab.b - bNeutral) - 0.35 * Math.max(0, lab.a - 14);
  const warmCool = wsum([
    [s && warmOf(s, 15), 0.45],
    [h && warmOf(h, 10), 0.35],
    [e && (e.b - 2), 0.2],
  ]) / 16;

  const chroma = (lab) => Math.sqrt(lab.a * lab.a + lab.b * lab.b);
  const contrast = s && h ? Math.abs(s.L - h.L) : 0;
  const brightSoft =
    (wsum([[e && chroma(e), 0.45], [s && chroma(s), 0.25], [h && chroma(h), 0.3]]) - 27) / 26 +
    (contrast - 34) / 90;

  return { lightDeep, warmCool, brightSoft };
}

export function classifySeason({ skin, hair, eyes }) {
  if (!skin && !hair) return null; // occhi da soli non bastano
  const a = computeAxes({ skin, hair, eyes });
  const dist = (c) =>
    Math.sqrt(
      AXIS_WEIGHT.lightDeep * (a.lightDeep - c.lightDeep) ** 2 +
        AXIS_WEIGHT.warmCool * (a.warmCool - c.warmCool) ** 2 +
        AXIS_WEIGHT.brightSoft * (a.brightSoft - c.brightSoft) ** 2
    );
  const ranked = Object.entries(SEASON_AXES)
    .map(([season, c]) => [season, dist(c)])
    .sort((x, y) => x[1] - y[1]);
  const [best, d1] = ranked[0];
  const d2 = ranked[1][1];
  // Margine fra i due centroidi migliori: vicini ⇒ verdetto incerto.
  const confidence = Math.round(((d2 - d1) / (d2 + d1)) * 100) / 100;
  return { season: best, axes: a, confidence };
}
```

- [ ] **Step 4: Verifica che passi**

Run: `npx vitest run src/utils/armocromiaClassifier.test.js`
Expected: PASS (17 test)

- [ ] **Step 5: Commit**

```bash
git add src/utils/armocromiaClassifier.js src/utils/armocromiaClassifier.test.js
git commit -m "feat(armocromia): classificatore a centroidi — 12 stagioni, 3 assi Lab"
```

---

### Task 3: Dati delle stagioni + i18n (`armocromiaSeasons.js`)

**Files:**
- Create: `src/utils/armocromiaSeasons.js`
- Test: `src/utils/armocromiaSeasons.test.js`
- Modify: `src/i18n/it.json`, `src/i18n/en.json` (nuovo blocco `armocromia`)

**Interfaces:**
- Consumes: `SEASON_AXES` da `./armocromiaClassifier` (per il test di coerenza id), `hexToRgb` da `./colorSampling` (test hex validi).
- Produces: `SEASONS` — oggetto id→`{ id, nameKey, descKey, palette:[{hex,nameKey}], avoid:[{hex,nameKey}], neutrals:[{hex,nameKey}], metal:'gold'|'silver'|'both', makeup:{ lips:[{hex,nameKey}], blush:[{hex,nameKey}], eyes:[{hex,nameKey}], foundationUndertone:'warm'|'cool'|'neutral' } }`; `getSeason(id)→SEASONS[id]|null`. Tutti i `nameKey` dei colori sono `armocromia.colors.<id>`; stagioni `armocromia.seasons.<id>.name/.desc`.

- [ ] **Step 1: Test che fallisce**

```js
import { describe, it, expect } from 'vitest';
import { SEASONS, getSeason } from './armocromiaSeasons';
import { SEASON_AXES } from './armocromiaClassifier';
import { hexToRgb } from './colorSampling';
import it_ from '../i18n/it.json';
import en from '../i18n/en.json';

const tKey = (obj, dotted) => dotted.split('.').reduce((o, k) => o && o[k], obj);

describe('integrità SEASONS', () => {
  it('le 12 stagioni combaciano col classificatore', () => {
    expect(Object.keys(SEASONS).sort()).toEqual(Object.keys(SEASON_AXES).sort());
  });
  it('ogni stagione è completa e con hex validi', () => {
    for (const s of Object.values(SEASONS)) {
      expect(s.palette.length).toBeGreaterThanOrEqual(5);
      expect(s.avoid.length).toBeGreaterThanOrEqual(2);
      expect(s.neutrals.length).toBeGreaterThanOrEqual(3);
      expect(['gold', 'silver', 'both']).toContain(s.metal);
      expect(s.makeup.lips.length).toBeGreaterThanOrEqual(2);
      expect(s.makeup.blush.length).toBeGreaterThanOrEqual(1);
      expect(s.makeup.eyes.length).toBeGreaterThanOrEqual(2);
      expect(['warm', 'cool', 'neutral']).toContain(s.makeup.foundationUndertone);
      for (const c of [...s.palette, ...s.avoid, ...s.neutrals,
                       ...s.makeup.lips, ...s.makeup.blush, ...s.makeup.eyes]) {
        expect(hexToRgb(c.hex)).not.toBeNull();
        expect(c.nameKey).toMatch(/^armocromia\.colors\./);
      }
    }
  });
  it('ogni chiave i18n esiste in IT e in EN', () => {
    const keys = new Set();
    for (const s of Object.values(SEASONS)) {
      keys.add(s.nameKey);
      keys.add(s.descKey);
      for (const c of [...s.palette, ...s.avoid, ...s.neutrals,
                       ...s.makeup.lips, ...s.makeup.blush, ...s.makeup.eyes]) {
        keys.add(c.nameKey);
      }
    }
    for (const k of keys) {
      expect(tKey(it_, k), `IT manca ${k}`).toBeTruthy();
      expect(tKey(en, k), `EN manca ${k}`).toBeTruthy();
    }
  });
  it('getSeason', () => {
    expect(getSeason('deep-winter').metal).toBe('silver');
    expect(getSeason('nope')).toBeNull();
  });
});
```

- [ ] **Step 2: Verifica che fallisca**

Run: `npx vitest run src/utils/armocromiaSeasons.test.js`
Expected: FAIL (modulo assente)

- [ ] **Step 3: Implementazione** — dataset curato (canone armocromia)

```js
/**
 * Le 12 sotto-stagioni: palette, colori da evitare, neutri, metallo, make-up.
 * Dati curati sul canone armocromia (sci-art 12 toni). I nameKey puntano a
 * i18n: i nomi colore servono anche come query per i link shop.
 */
const C = (hex, id) => ({ hex, nameKey: `armocromia.colors.${id}` });

const season = (id, data) => [id, {
  id, nameKey: `armocromia.seasons.${id}.name`, descKey: `armocromia.seasons.${id}.desc`, ...data,
}];

export const SEASONS = Object.fromEntries([
  season('light-spring', {
    palette: [C('#ffcba4', 'pesca'), C('#f4a460', 'albicocca'), C('#ff7f6a', 'corallo'),
              C('#b2d8b2', 'menta'), C('#87ceeb', 'azzurro-polvere'), C('#fff44f', 'limone')],
    avoid: [C('#000000', 'nero'), C('#4b0082', 'viola'), C('#800020', 'bordeaux')],
    neutrals: [C('#fffdd0', 'crema'), C('#f5f5dc', 'beige'), C('#c3b091', 'sabbia')],
    metal: 'gold',
    makeup: {
      lips: [C('#ff7f6a', 'corallo'), C('#ffb09a', 'pesca')],
      blush: [C('#ffb09a', 'pesca')],
      eyes: [C('#c3b091', 'sabbia'), C('#b87333', 'rame')],
      foundationUndertone: 'warm',
    },
  }),
  season('light-summer', {
    palette: [C('#e6c9d3', 'rosa-cipria'), C('#b6a8d4', 'lavanda'), C('#a9c1cf', 'azzurro-polvere'),
              C('#98b4a6', 'menta'), C('#d3a4b5', 'malva'), C('#a3b8cc', 'blu-ghiaccio')],
    avoid: [C('#ff5f00', 'arancio'), C('#8b4513', 'ruggine'), C('#000000', 'nero')],
    neutrals: [C('#c9c0bb', 'grigio-perla'), C('#b8a89a', 'tortora'), C('#f2efe9', 'bianco-caldo')],
    metal: 'silver',
    makeup: {
      lips: [C('#d38fa4', 'rosa-antico'), C('#c98b9b', 'malva')],
      blush: [C('#e3b7c0', 'rosa-cipria')],
      eyes: [C('#b8a89a', 'tortora'), C('#8e9aaf', 'blu-ghiaccio')],
      foundationUndertone: 'cool',
    },
  }),
  season('true-spring', {
    palette: [C('#ffa812', 'giallo-dorato'), C('#7bb661', 'verde-erba'), C('#ff7f50', 'corallo'),
              C('#40e0d0', 'turchese'), C('#ff6347', 'rosso-pomodoro'), C('#ffcba4', 'pesca')],
    avoid: [C('#000000', 'nero'), C('#c9c0bb', 'grigio-perla'), C('#722f37', 'vinaccia')],
    neutrals: [C('#fffdd0', 'crema'), C('#c19a6b', 'cammello'), C('#f2efe9', 'bianco-caldo')],
    metal: 'gold',
    makeup: {
      lips: [C('#ff7f50', 'corallo'), C('#ff6347', 'rosso-pomodoro')],
      blush: [C('#ffcba4', 'pesca')],
      eyes: [C('#c19a6b', 'cammello'), C('#b87333', 'rame')],
      foundationUndertone: 'warm',
    },
  }),
  season('true-summer', {
    palette: [C('#7f9bb3', 'azzurro-polvere'), C('#c98b9b', 'malva'), C('#8e6c88', 'prugna'),
              C('#98b4a6', 'menta'), C('#6e7f9e', 'blu-navy'), C('#d38fa4', 'rosa-antico')],
    avoid: [C('#ff5f00', 'arancio'), C('#ffa812', 'giallo-dorato'), C('#8b4513', 'ruggine')],
    neutrals: [C('#c9c0bb', 'grigio-perla'), C('#5d6970', 'grigio-antracite'), C('#f2efe9', 'bianco-caldo')],
    metal: 'silver',
    makeup: {
      lips: [C('#c98b9b', 'malva'), C('#b76e79', 'rosa-antico')],
      blush: [C('#e3b7c0', 'rosa-cipria')],
      eyes: [C('#8e9aaf', 'blu-ghiaccio'), C('#9a8f83', 'tortora')],
      foundationUndertone: 'cool',
    },
  }),
  season('true-autumn', {
    palette: [C('#b7410e', 'ruggine'), C('#808000', 'oliva'), C('#e2725b', 'terracotta'),
              C('#ffdb58', 'senape'), C('#b87333', 'rame'), C('#01796f', 'verde-pino')],
    avoid: [C('#ff69b4', 'rosa-shocking'), C('#a3b8cc', 'blu-ghiaccio'), C('#c9c0bb', 'grigio-perla')],
    neutrals: [C('#c19a6b', 'cammello'), C('#7b3f00', 'marrone-cioccolato'), C('#c3b091', 'kaki')],
    metal: 'gold',
    makeup: {
      lips: [C('#e2725b', 'terracotta'), C('#b7410e', 'ruggine')],
      blush: [C('#e2725b', 'terracotta')],
      eyes: [C('#7b3f00', 'marrone-cioccolato'), C('#808000', 'oliva')],
      foundationUndertone: 'warm',
    },
  }),
  season('true-winter', {
    palette: [C('#e0115f', 'fucsia'), C('#4169e1', 'blu-royal'), C('#50c878', 'smeraldo'),
              C('#dc143c', 'rosso-ciliegia'), C('#8e4585', 'viola'), C('#00a86b', 'verde-pino')],
    avoid: [C('#e2725b', 'terracotta'), C('#ffdb58', 'senape'), C('#c3b091', 'sabbia')],
    neutrals: [C('#000000', 'nero'), C('#ffffff', 'bianco-puro'), C('#36454f', 'grigio-antracite')],
    metal: 'silver',
    makeup: {
      lips: [C('#dc143c', 'rosso-ciliegia'), C('#e0115f', 'fucsia')],
      blush: [C('#d38fa4', 'rosa-antico')],
      eyes: [C('#36454f', 'grigio-antracite'), C('#4f2f4f', 'prugna')],
      foundationUndertone: 'cool',
    },
  }),
  season('bright-spring', {
    palette: [C('#ff4040', 'rosso-pomodoro'), C('#2e8b74', 'smeraldo'), C('#ff7f50', 'corallo'),
              C('#00bfff', 'turchese'), C('#ffd700', 'giallo-dorato'), C('#ff69b4', 'rosa-shocking')],
    avoid: [C('#9a8f83', 'tortora'), C('#c9c0bb', 'grigio-perla'), C('#808000', 'oliva')],
    neutrals: [C('#fffdd0', 'crema'), C('#36454f', 'grigio-antracite'), C('#c19a6b', 'cammello')],
    metal: 'gold',
    makeup: {
      lips: [C('#ff4040', 'rosso-pomodoro'), C('#ff7f50', 'corallo')],
      blush: [C('#ffb09a', 'pesca')],
      eyes: [C('#b87333', 'rame'), C('#2e8b74', 'smeraldo')],
      foundationUndertone: 'warm',
    },
  }),
  season('bright-winter', {
    palette: [C('#ff1493', 'fucsia'), C('#0047ab', 'blu-royal'), C('#00ffef', 'turchese'),
              C('#dc143c', 'rosso-ciliegia'), C('#9932cc', 'viola'), C('#01796f', 'verde-pino')],
    avoid: [C('#c3b091', 'sabbia'), C('#e2725b', 'terracotta'), C('#9a8f83', 'tortora')],
    neutrals: [C('#000000', 'nero'), C('#ffffff', 'bianco-puro'), C('#2c3539', 'grigio-antracite')],
    metal: 'silver',
    makeup: {
      lips: [C('#dc143c', 'rosso-ciliegia'), C('#ff1493', 'fucsia')],
      blush: [C('#e3b7c0', 'rosa-cipria')],
      eyes: [C('#2c3539', 'grigio-antracite'), C('#191970', 'blu-navy')],
      foundationUndertone: 'cool',
    },
  }),
  season('soft-autumn', {
    palette: [C('#c3a38a', 'sabbia'), C('#9caf88', 'verde-salvia'), C('#d19a6a', 'miele'),
              C('#b5836d', 'terracotta'), C('#8f9779', 'oliva'), C('#c08081', 'rosa-antico')],
    avoid: [C('#ff1493', 'fucsia'), C('#0047ab', 'blu-royal'), C('#000000', 'nero')],
    neutrals: [C('#b8a89a', 'tortora'), C('#c3b091', 'kaki'), C('#f5f5dc', 'beige')],
    metal: 'gold',
    makeup: {
      lips: [C('#c08081', 'rosa-antico'), C('#b5836d', 'terracotta')],
      blush: [C('#d19a6a', 'miele')],
      eyes: [C('#8f9779', 'oliva'), C('#b8a89a', 'tortora')],
      foundationUndertone: 'neutral',
    },
  }),
  season('soft-summer', {
    palette: [C('#8496a0', 'blu-ghiaccio'), C('#c8a2c8', 'lilla'), C('#9caf88', 'verde-salvia'),
              C('#b784a7', 'malva'), C('#6e7f9e', 'blu-navy'), C('#c08081', 'rosa-antico')],
    avoid: [C('#ff5f00', 'arancio'), C('#ffd700', 'giallo-dorato'), C('#b7410e', 'ruggine')],
    neutrals: [C('#c9c0bb', 'grigio-perla'), C('#b8a89a', 'tortora'), C('#5d6970', 'grigio-antracite')],
    metal: 'silver',
    makeup: {
      lips: [C('#b784a7', 'malva'), C('#c08081', 'rosa-antico')],
      blush: [C('#e3b7c0', 'rosa-cipria')],
      eyes: [C('#8496a0', 'blu-ghiaccio'), C('#9a8f83', 'tortora')],
      foundationUndertone: 'cool',
    },
  }),
  season('deep-autumn', {
    palette: [C('#722f37', 'vinaccia'), C('#01796f', 'verde-pino'), C('#b7410e', 'ruggine'),
              C('#ffdb58', 'senape'), C('#7b3f00', 'marrone-cioccolato'), C('#e2725b', 'terracotta')],
    avoid: [C('#e6c9d3', 'rosa-cipria'), C('#a3b8cc', 'blu-ghiaccio'), C('#c9c0bb', 'grigio-perla')],
    neutrals: [C('#3d2b1f', 'marrone-cioccolato'), C('#000000', 'nero'), C('#c19a6b', 'cammello')],
    metal: 'gold',
    makeup: {
      lips: [C('#722f37', 'vinaccia'), C('#b7410e', 'ruggine')],
      blush: [C('#e2725b', 'terracotta')],
      eyes: [C('#3d2b1f', 'marrone-cioccolato'), C('#01796f', 'verde-pino')],
      foundationUndertone: 'warm',
    },
  }),
  season('deep-winter', {
    palette: [C('#800020', 'bordeaux'), C('#191970', 'blu-navy'), C('#50c878', 'smeraldo'),
              C('#8e4585', 'prugna'), C('#dc143c', 'rosso-ciliegia'), C('#008080', 'petrolio')],
    avoid: [C('#ffcba4', 'pesca'), C('#c3b091', 'sabbia'), C('#d19a6a', 'miele')],
    neutrals: [C('#000000', 'nero'), C('#ffffff', 'bianco-puro'), C('#36454f', 'grigio-antracite')],
    metal: 'silver',
    makeup: {
      lips: [C('#800020', 'bordeaux'), C('#dc143c', 'rosso-ciliegia')],
      blush: [C('#8e4585', 'prugna')],
      eyes: [C('#36454f', 'grigio-antracite'), C('#191970', 'blu-navy')],
      foundationUndertone: 'cool',
    },
  }),
]);

export const getSeason = (id) => SEASONS[id] || null;
```

- [ ] **Step 4: i18n** — aggiungere in `it.json` E `en.json` un blocco top-level `armocromia` (stesse chiavi nei due file). IT:

```json
"armocromia": {
  "seasons": {
    "light-spring": { "name": "Primavera Chiara", "desc": "Colori caldi, chiari e delicati: pesca, menta, crema. Ti illuminano tinte tenui e luminose, mai pesanti." },
    "light-summer": { "name": "Estate Chiara", "desc": "Colori freddi, chiari e polverosi: lavanda, rosa cipria, azzurro polvere. Meglio i toni tenui dei contrasti forti." },
    "true-spring": { "name": "Primavera Assoluta", "desc": "Colori caldi e vivaci: corallo, verde erba, giallo dorato. Il calore è la tua cifra: evita il nero vicino al viso." },
    "true-summer": { "name": "Estate Assoluta", "desc": "Colori freddi e morbidi: malva, azzurri, prugna chiaro. L'argento e i toni polverosi ti donano." },
    "true-autumn": { "name": "Autunno Assoluto", "desc": "Colori caldi e terrosi: ruggine, oliva, senape, rame. I toni delle spezie e della terra sono i tuoi." },
    "true-winter": { "name": "Inverno Assoluto", "desc": "Colori freddi e netti: fucsia, blu royal, rosso ciliegia, bianco e nero. Il contrasto pulito è il tuo punto di forza." },
    "bright-spring": { "name": "Primavera Brillante", "desc": "Colori caldi e accesi: corallo vivo, turchese, giallo oro. Più il colore è vivo, più funziona." },
    "bright-winter": { "name": "Inverno Brillante", "desc": "Colori freddi e accesi: fucsia, blu elettrico, rosso ciliegia. Contrasti netti e tinte sature ti esaltano." },
    "soft-autumn": { "name": "Autunno Soft", "desc": "Colori caldi e attenuati: salvia, miele, terracotta spenta. I toni fusi e polverosi valorizzano più dei colori puri." },
    "soft-summer": { "name": "Estate Soft", "desc": "Colori freddi e attenuati: lilla, salvia, blu ghiaccio. Sfumature morbide, mai tinte urlate." },
    "deep-autumn": { "name": "Autunno Profondo", "desc": "Colori caldi e profondi: vinaccia, verde pino, cioccolato. Le tinte ricche e scure incorniciano il viso." },
    "deep-winter": { "name": "Inverno Profondo", "desc": "Colori freddi e profondi: bordeaux, navy, smeraldo. Scuri intensi e contrasto col bianco puro." }
  },
  "colors": {
    "pesca": "pesca", "albicocca": "albicocca", "corallo": "corallo", "menta": "verde menta",
    "azzurro-polvere": "azzurro polvere", "limone": "giallo limone", "nero": "nero",
    "viola": "viola", "bordeaux": "bordeaux", "crema": "crema", "beige": "beige",
    "sabbia": "sabbia", "rame": "rame", "rosa-cipria": "rosa cipria", "lavanda": "lavanda",
    "malva": "malva", "blu-ghiaccio": "blu ghiaccio", "arancio": "arancio",
    "ruggine": "ruggine", "grigio-perla": "grigio perla", "tortora": "tortora",
    "bianco-caldo": "bianco panna", "rosa-antico": "rosa antico", "giallo-dorato": "giallo dorato",
    "verde-erba": "verde erba", "turchese": "turchese", "rosso-pomodoro": "rosso pomodoro",
    "vinaccia": "vinaccia", "cammello": "cammello", "prugna": "prugna", "blu-navy": "blu navy",
    "grigio-antracite": "grigio antracite", "oliva": "verde oliva", "terracotta": "terracotta",
    "senape": "senape", "verde-pino": "verde pino", "rosa-shocking": "rosa shocking",
    "kaki": "kaki", "marrone-cioccolato": "marrone cioccolato", "fucsia": "fucsia",
    "blu-royal": "blu royal", "smeraldo": "verde smeraldo", "rosso-ciliegia": "rosso ciliegia",
    "bianco-puro": "bianco ottico", "verde-salvia": "verde salvia", "miele": "miele",
    "lilla": "lilla", "petrolio": "petrolio"
  },
  "undertone": { "warm": "sottotono caldo", "cool": "sottotono freddo", "neutral": "sottotono neutro" },
  "metal": { "gold": "oro", "silver": "argento", "both": "oro e argento" }
}
```

EN (stesse chiavi):

```json
"armocromia": {
  "seasons": {
    "light-spring": { "name": "Light Spring", "desc": "Warm, light, delicate colors: peach, mint, cream. Soft luminous shades suit you — never heavy ones." },
    "light-summer": { "name": "Light Summer", "desc": "Cool, light, dusty colors: lavender, powder pink, powder blue. Gentle tones beat strong contrast." },
    "true-spring": { "name": "True Spring", "desc": "Warm, lively colors: coral, grass green, golden yellow. Warmth is your signature: keep black away from your face." },
    "true-summer": { "name": "True Summer", "desc": "Cool, soft colors: mauve, blues, light plum. Silver and dusty tones flatter you." },
    "true-autumn": { "name": "True Autumn", "desc": "Warm, earthy colors: rust, olive, mustard, copper. Spice and earth tones are yours." },
    "true-winter": { "name": "True Winter", "desc": "Cool, crisp colors: fuchsia, royal blue, cherry red, black and white. Clean contrast is your strength." },
    "bright-spring": { "name": "Bright Spring", "desc": "Warm, vivid colors: bright coral, turquoise, golden yellow. The brighter the color, the better it works." },
    "bright-winter": { "name": "Bright Winter", "desc": "Cool, vivid colors: fuchsia, electric blue, cherry red. Sharp contrast and saturated shades light you up." },
    "soft-autumn": { "name": "Soft Autumn", "desc": "Warm, muted colors: sage, honey, dusty terracotta. Blended dusty tones flatter more than pure brights." },
    "soft-summer": { "name": "Soft Summer", "desc": "Cool, muted colors: lilac, sage, ice blue. Soft shades, never loud ones." },
    "deep-autumn": { "name": "Deep Autumn", "desc": "Warm, deep colors: wine, pine green, chocolate. Rich dark shades frame your face." },
    "deep-winter": { "name": "Deep Winter", "desc": "Cool, deep colors: burgundy, navy, emerald. Intense darks with pure white contrast." }
  },
  "colors": {
    "pesca": "peach", "albicocca": "apricot", "corallo": "coral", "menta": "mint green",
    "azzurro-polvere": "powder blue", "limone": "lemon yellow", "nero": "black",
    "viola": "purple", "bordeaux": "burgundy", "crema": "cream", "beige": "beige",
    "sabbia": "sand", "rame": "copper", "rosa-cipria": "powder pink", "lavanda": "lavender",
    "malva": "mauve", "blu-ghiaccio": "ice blue", "arancio": "orange",
    "ruggine": "rust", "grigio-perla": "pearl gray", "tortora": "taupe",
    "bianco-caldo": "off-white", "rosa-antico": "dusty rose", "giallo-dorato": "golden yellow",
    "verde-erba": "grass green", "turchese": "turquoise", "rosso-pomodoro": "tomato red",
    "vinaccia": "wine", "cammello": "camel", "prugna": "plum", "blu-navy": "navy blue",
    "grigio-antracite": "charcoal", "oliva": "olive green", "terracotta": "terracotta",
    "senape": "mustard", "verde-pino": "pine green", "rosa-shocking": "hot pink",
    "kaki": "khaki", "marrone-cioccolato": "chocolate brown", "fucsia": "fuchsia",
    "blu-royal": "royal blue", "smeraldo": "emerald green", "rosso-ciliegia": "cherry red",
    "bianco-puro": "pure white", "verde-salvia": "sage green", "miele": "honey",
    "lilla": "lilac", "petrolio": "teal"
  },
  "undertone": { "warm": "warm undertone", "cool": "cool undertone", "neutral": "neutral undertone" },
  "metal": { "gold": "gold", "silver": "silver", "both": "gold and silver" }
}
```

- [ ] **Step 5: Verifica che passi**

Run: `npx vitest run src/utils/armocromiaSeasons.test.js` poi `npm test`
Expected: PASS; suite intera verde

- [ ] **Step 6: Commit**

```bash
git add src/utils/armocromiaSeasons.js src/utils/armocromiaSeasons.test.js src/i18n/it.json src/i18n/en.json
git commit -m "feat(armocromia): dataset 12 stagioni + i18n (palette, neutri, metallo, make-up)"
```

---

### Task 4: Link agli shop (`shopLinks.js`, puro)

**Files:**
- Create: `src/utils/shopLinks.js`
- Test: `src/utils/shopLinks.test.js`

**Interfaces:**
- Produces: `buildShopLinks({ kind:'clothing'|'makeup', query:string, lang:'it'|'en' })→[{shop,label,url}]`. La query arriva GIÀ localizzata dal chiamante (es. `"maglione bordeaux"`); qui solo encoding e template.

- [ ] **Step 1: Test che fallisce**

```js
import { describe, it, expect } from 'vitest';
import { buildShopLinks } from './shopLinks';

describe('buildShopLinks', () => {
  it('abbigliamento IT: Zalando, Asos, Amazon con query codificata', () => {
    const links = buildShopLinks({ kind: 'clothing', query: 'maglione bordeaux', lang: 'it' });
    expect(links.map((l) => l.shop)).toEqual(['zalando', 'asos', 'amazon']);
    expect(links[0].url).toBe('https://www.zalando.it/catalogo/?q=maglione%20bordeaux');
    expect(links[2].url).toBe('https://www.amazon.it/s?k=maglione%20bordeaux');
  });
  it('abbigliamento EN: domini internazionali', () => {
    const links = buildShopLinks({ kind: 'clothing', query: 'burgundy sweater', lang: 'en' });
    expect(links[0].url).toContain('zalando.co.uk');
    expect(links[2].url).toContain('amazon.com');
  });
  it('make-up IT: Sephora, Douglas, Amazon', () => {
    const links = buildShopLinks({ kind: 'makeup', query: 'rossetto corallo', lang: 'it' });
    expect(links.map((l) => l.shop)).toEqual(['sephora', 'douglas', 'amazon']);
    expect(links[0].url).toBe('https://www.sephora.it/ricerca?q=rossetto%20corallo');
  });
  it("l'encoding gestisce accenti e simboli", () => {
    const [l] = buildShopLinks({ kind: 'clothing', query: 'très & chic', lang: 'it' });
    expect(l.url).toContain('tr%C3%A8s%20%26%20chic');
  });
  it('lingua ignota → ripiego su it', () => {
    const links = buildShopLinks({ kind: 'clothing', query: 'x', lang: 'de' });
    expect(links[0].url).toContain('zalando.it');
  });
});
```

- [ ] **Step 2: Verifica che fallisca**

Run: `npx vitest run src/utils/shopLinks.test.js`
Expected: FAIL (modulo assente)

- [ ] **Step 3: Implementazione**

```js
/**
 * Link di RICERCA agli shop (niente deep-link a filtri fragili): query
 * testuale localizzata → URL stabile. Nessuna API, nessun costo.
 */
const SHOPS = {
  clothing: {
    it: [
      { shop: 'zalando', label: 'Zalando', base: 'https://www.zalando.it/catalogo/?q=' },
      { shop: 'asos', label: 'ASOS', base: 'https://www.asos.com/it/search/?q=' },
      { shop: 'amazon', label: 'Amazon', base: 'https://www.amazon.it/s?k=' },
    ],
    en: [
      { shop: 'zalando', label: 'Zalando', base: 'https://www.zalando.co.uk/catalog/?q=' },
      { shop: 'asos', label: 'ASOS', base: 'https://www.asos.com/search/?q=' },
      { shop: 'amazon', label: 'Amazon', base: 'https://www.amazon.com/s?k=' },
    ],
  },
  makeup: {
    it: [
      { shop: 'sephora', label: 'Sephora', base: 'https://www.sephora.it/ricerca?q=' },
      { shop: 'douglas', label: 'Douglas', base: 'https://www.douglas.it/it/search?query=' },
      { shop: 'amazon', label: 'Amazon', base: 'https://www.amazon.it/s?k=' },
    ],
    en: [
      { shop: 'sephora', label: 'Sephora', base: 'https://www.sephora.com/search?keyword=' },
      { shop: 'amazon', label: 'Amazon', base: 'https://www.amazon.com/s?k=' },
    ],
  },
};

export function buildShopLinks({ kind, query, lang }) {
  const byLang = SHOPS[kind] || SHOPS.clothing;
  const shops = byLang[lang] || byLang.it;
  const q = encodeURIComponent(query).replace(/\+/g, '%20');
  return shops.map(({ shop, label, base }) => ({ shop, label, url: base + q }));
}
```

- [ ] **Step 4: Verifica che passi**

Run: `npx vitest run src/utils/shopLinks.test.js`
Expected: PASS (5 test)

- [ ] **Step 5: Commit**

```bash
git add src/utils/shopLinks.js src/utils/shopLinks.test.js
git commit -m "feat(armocromia): link di ricerca agli shop, IT/EN"
```

---

### Task 5: Guardaroba in palette (`armocromiaWardrobe.js`, puro)

**Files:**
- Create: `src/utils/armocromiaWardrobe.js`
- Test: `src/utils/armocromiaWardrobe.test.js`

**Interfaces:**
- Consumes: `getSeason` (Task 3), `hexToRgb/rgbToLab/deltaE` (Task 1), `CLOTHING_COLORS` da `./categories` (`[{id,hex,...}]`).
- Produces: `matchWardrobe(items, seasonId)→[{item, distance, itemHex, paletteHex}]` — capi con almeno un colore a `deltaE ≤ 25` da palette∪neutrals, ordinati per distanza crescente. Item senza `colors` o con id colore ignoti si saltano.

- [ ] **Step 1: Test che fallisce**

```js
import { describe, it, expect } from 'vitest';
import { matchWardrobe, IN_PALETTE_MAX } from './armocromiaWardrobe';

const item = (id, colors) => ({ id, name: id, colors });

describe('matchWardrobe', () => {
  it('un capo bordeaux entra nella palette deep-winter, uno beige no', () => {
    const res = matchWardrobe([item('a', ['burgundy']), item('b', ['beige'])], 'deep-winter');
    expect(res.map((r) => r.item.id)).toEqual(['a']);
    expect(res[0].distance).toBeLessThanOrEqual(IN_PALETTE_MAX);
    expect(res[0].itemHex).toBeTruthy();
    expect(res[0].paletteHex).toBeTruthy();
  });
  it('ordina per distanza crescente', () => {
    const res = matchWardrobe(
      [item('lontano', ['navy']), item('vicino', ['burgundy'])],
      'deep-winter'
    );
    expect(res.length).toBe(2);
    expect(res[0].distance).toBeLessThanOrEqual(res[1].distance);
  });
  it('capi senza colori o con id ignoti si saltano; stagione ignota → []', () => {
    expect(matchWardrobe([item('x', []), item('y', ['colore-inventato'])], 'deep-winter')).toEqual([]);
    expect(matchWardrobe([item('a', ['burgundy'])], 'stagione-finta')).toEqual([]);
  });
});
```

- [ ] **Step 2: Verifica che fallisca**

Run: `npx vitest run src/utils/armocromiaWardrobe.test.js`
Expected: FAIL (modulo assente)

- [ ] **Step 3: Implementazione**

```js
/**
 * Capi del guardaroba "in palette" per una stagione: per ogni capo si prende
 * il deltaE minimo fra i suoi colori (id → hex di CLOTHING_COLORS) e
 * palette+neutri della stagione. Sotto soglia ⇒ in palette.
 */
import { getSeason } from './armocromiaSeasons';
import { hexToRgb, rgbToLab, deltaE } from './colorSampling';
import { CLOTHING_COLORS } from './categories';

export const IN_PALETTE_MAX = 25;

export function matchWardrobe(items, seasonId) {
  const season = getSeason(seasonId);
  if (!season) return [];
  const paletteLabs = [...season.palette, ...season.neutrals].map((c) => ({
    hex: c.hex,
    lab: rgbToLab(hexToRgb(c.hex)),
  }));
  const out = [];
  for (const item of items || []) {
    let best = null;
    for (const colorId of item.colors || []) {
      const cc = CLOTHING_COLORS.find((c) => c.id === colorId);
      if (!cc) continue;
      const lab = rgbToLab(hexToRgb(cc.hex));
      for (const p of paletteLabs) {
        const d = deltaE(lab, p.lab);
        if (!best || d < best.distance) {
          best = { distance: d, itemHex: cc.hex, paletteHex: p.hex };
        }
      }
    }
    if (best && best.distance <= IN_PALETTE_MAX) out.push({ item, ...best });
  }
  return out.sort((a, b) => a.distance - b.distance);
}
```

- [ ] **Step 4: Verifica che passi**

Run: `npx vitest run src/utils/armocromiaWardrobe.test.js` poi `npm test`
Expected: PASS. NB: se il test "bordeaux in deep-winter" fallisse per soglia,
NON alzare `IN_PALETTE_MAX` oltre 25: controllare l'hex di `burgundy` in
`CLOTHING_COLORS` e nel caso segnalare DONE_WITH_CONCERNS col valore reale.

- [ ] **Step 5: Commit**

```bash
git add src/utils/armocromiaWardrobe.js src/utils/armocromiaWardrobe.test.js
git commit -m "feat(armocromia): capi del guardaroba in palette per deltaE"
```

---

### Task 6: Estrazione colori dal viso (`faceColorAnalysis.js`, sottile)

**Files:**
- Create: `src/utils/faceColorAnalysis.js`

**Interfaces:**
- Consumes: `segmentBody`, `SEG_FACE_SKIN`, `SEG_HAIR` da `./bodyAnalysis` (NON modificarlo); `representativeColor`, `maskedPixels`, `rgbToHex` da `./colorSampling`.
- Produces: `analyzeFaceColors(photoUrl)→Promise<{skin,hair,eyes,confidence}|null>` — hex o `null` per campo; `null` totale se non si estrae nulla. **Niente test unit** (MediaPipe non gira in jsdom — lezione del repo): la matematica sta nei moduli puri già testati; la verifica è a schermo (Task 9).

- [ ] **Step 1: Implementazione**

```js
/**
 * Estrazione dei colori personali dalla foto, tutto on-device:
 * - pelle del viso e capelli: maschera del segmentatore selfie multiclass
 *   (riuso di segmentBody, già in bodyAnalysis.js) + colore rappresentativo;
 * - occhi: FaceLandmarker (stesso pacchetto MediaPipe, lazy) → centro iride
 *   → campiona un disco; il taglio del 35% esclude pupilla e riflessi.
 * Ogni pezzo che fallisce diventa null; se cade tutto → null totale:
 * la UI parte dalla correzione manuale.
 */
import { segmentBody, SEG_FACE_SKIN, SEG_HAIR } from './bodyAnalysis';
import { representativeColor, maskedPixels } from './colorSampling';

const VISION_VERSION = '0.10.35';
const WASM_URL = `https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@${VISION_VERSION}/wasm`;
const FACE_MODEL_URL =
  'https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/latest/face_landmarker.task';

// Landmark MediaPipe dell'iride (modello a 478 punti):
// 468 centro iride sinistra, 469-472 anello; 473 centro destra, 474-477 anello.
const IRIS = [
  { center: 468, ring: [469, 470, 471, 472] },
  { center: 473, ring: [474, 475, 476, 477] },
];

const MIN_REGION_PIXELS = 150;

let landmarkerPromise = null;
const getFaceLandmarker = () => {
  if (!landmarkerPromise) {
    landmarkerPromise = import('@mediapipe/tasks-vision').then(async (mp) => {
      const fileset = await mp.FilesetResolver.forVisionTasks(WASM_URL);
      return mp.FaceLandmarker.createFromOptions(fileset, {
        baseOptions: { modelAssetPath: FACE_MODEL_URL },
        runningMode: 'IMAGE',
        numFaces: 1,
      });
    });
  }
  return landmarkerPromise;
};

const loadImage = (src) =>
  new Promise((resolve, reject) => {
    const img = new Image();
    img.crossOrigin = 'anonymous';
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error('load'));
    img.src = src;
  });

const imageDataOf = (img, w, h) => {
  const canvas = document.createElement('canvas');
  canvas.width = w;
  canvas.height = h;
  const ctx = canvas.getContext('2d', { willReadFrequently: true });
  ctx.drawImage(img, 0, 0, w, h);
  return ctx.getImageData(0, 0, w, h);
};

/** Pixel in un disco attorno a (cx,cy) — coordinate già in pixel immagine. */
const discPixels = (imageData, cx, cy, radius) => {
  const out = [];
  const r2 = radius * radius;
  const { width, height, data } = imageData;
  for (let y = Math.max(0, Math.floor(cy - radius)); y <= Math.min(height - 1, Math.ceil(cy + radius)); y++) {
    for (let x = Math.max(0, Math.floor(cx - radius)); x <= Math.min(width - 1, Math.ceil(cx + radius)); x++) {
      if ((x - cx) ** 2 + (y - cy) ** 2 <= r2) {
        const o = (y * width + x) * 4;
        out.push({ r: data[o], g: data[o + 1], b: data[o + 2] });
      }
    }
  }
  return out;
};

async function eyesColor(img, imageData) {
  try {
    const lm = await getFaceLandmarker();
    const result = lm.detect(img);
    const points = result.faceLandmarks?.[0];
    if (!points) return null;
    const pixels = [];
    for (const { center, ring } of IRIS) {
      const c = points[center];
      if (!c) continue;
      const cx = c.x * imageData.width;
      const cy = c.y * imageData.height;
      const radius =
        (ring.reduce((t, i) => {
          const p = points[i];
          return t + Math.hypot(p.x * imageData.width - cx, p.y * imageData.height - cy);
        }, 0) / ring.length) * 0.7;
      if (radius < 1.5) continue; // iride troppo piccola per campionare
      pixels.push(...discPixels(imageData, cx, cy, radius));
    }
    if (pixels.length < 12) return null;
    return representativeColor(pixels, { trim: 0.35 }); // via pupilla e riflessi
  } catch {
    return null;
  }
}

export async function analyzeFaceColors(photoUrl) {
  try {
    const [seg, img] = await Promise.all([segmentBody(photoUrl), loadImage(photoUrl)]);
    let skin = null;
    let hair = null;
    let skinCount = 0;
    if (seg) {
      const maskData = imageDataOf(img, seg.width, seg.height);
      const skinPx = maskedPixels(maskData, seg.categories, [SEG_FACE_SKIN]);
      const hairPx = maskedPixels(maskData, seg.categories, [SEG_HAIR]);
      skinCount = skinPx.length;
      if (skinPx.length >= MIN_REGION_PIXELS) skin = representativeColor(skinPx);
      if (hairPx.length >= MIN_REGION_PIXELS) hair = representativeColor(hairPx);
    }
    // occhi alla risoluzione naturale (l'iride è piccola)
    const fullData = imageDataOf(img, img.naturalWidth, img.naturalHeight);
    const eyes = await eyesColor(img, fullData);

    if (!skin && !hair && !eyes) return null;
    const parts = [skin, hair, eyes].filter(Boolean).length;
    const confidence =
      Math.round(((parts / 3) * 0.7 + Math.min(1, skinCount / 2000) * 0.3) * 100) / 100;
    return { skin, hair, eyes, confidence };
  } catch {
    return null;
  }
}
```

- [ ] **Step 2: Gate**

Run: `npm test` e `npm run build`
Expected: verde (nessun nuovo test), build ok.

- [ ] **Step 3: Commit**

```bash
git add src/utils/faceColorAnalysis.js
git commit -m "feat(armocromia): estrazione pelle/capelli/occhi on-device (MediaPipe)"
```

---

### Task 7: Persistenza (`ProfileContext` + `db.js` + migrazione)

**Files:**
- Modify: `src/context/ProfileContext.jsx` (`DEFAULT_PROFILE` + setter)
- Modify: `src/services/db.js` (mappatura colonna `armocromia`)
- Create: `supabase/migrations/002_armocromia.sql`

**Interfaces:**
- Produces: dal `useProfile()`: `armocromia` (oggetto `{season, detected:{skin,hair,eyes}, axes, confidence, updatedAt}` o `null`) e `setArmocromia(value)` — stesso pattern di `referencePhoto`/`setReferencePhoto`.

- [ ] **Step 1** — `ProfileContext.jsx`: in `DEFAULT_PROFILE` aggiungere `armocromia: null`; accanto al setter esistente della foto aggiungere:

```js
const setArmocromia = useCallback((value) => {
  setProfile((prev) => ({ ...prev, armocromia: value }));
}, []);
```

ed esporlo nel value del provider (`armocromia: profile.armocromia, setArmocromia`). Seguire ESATTAMENTE come `referencePhoto` è esposto/salvato (locale e cloud: il salvataggio del blob profilo esiste già; verificare che il campo passi nel percorso di sync cloud come gli altri campi del profilo).

- [ ] **Step 2** — `db.js`: in `fetchProfile` mappare `armocromia: data.armocromia ?? null`; in `upsertProfile` scrivere `row.armocromia = profile.armocromia ?? null` (stesso stile dei campi esistenti).

- [ ] **Step 3** — migrazione:

```sql
-- supabase/migrations/002_armocromia.sql
alter table public.profiles
  add column if not exists armocromia jsonb;
```

- [ ] **Step 4: Gate**

Run: `npm test` e `npm run build`
Expected: verde, build ok.

- [ ] **Step 5: Commit**

```bash
git add src/context/ProfileContext.jsx src/services/db.js supabase/migrations/002_armocromia.sql
git commit -m "feat(armocromia): persistenza nel profilo (locale + colonna jsonb)"
```

---

### Task 8: Pagina `/armocromia` + card nel Profilo + i18n UI

**Files:**
- Create: `src/pages/ArmocromiaPage/ArmocromiaPage.jsx`, `src/pages/ArmocromiaPage/ArmocromiaPage.css`
- Modify: `src/App.jsx` (route), `src/pages/ProfilePage/ProfilePage.jsx` (card d'ingresso), `src/i18n/it.json`, `src/i18n/en.json` (blocco `armocromia.ui`)

**Interfaces:**
- Consumes: `analyzeFaceColors` (T6), `classifySeason` (T2), `getSeason` (T3), `buildShopLinks` (T4), `matchWardrobe` (T5), `useProfile` → `referencePhoto`, `armocromia`, `setArmocromia` (T7), `useWardrobe` → `items`, `resizeImageFile` da `../../utils/imageUtils`.

- [ ] **Step 1: i18n UI** — in `it.json` dentro il blocco `armocromia` (accanto a `seasons/colors/...`) aggiungere `ui`; EN speculare:

```json
"ui": {
  "title": "I tuoi colori",
  "profileCard": "Armocromia — scopri i tuoi colori",
  "intro": "Dalla tua foto leggo i colori di pelle, capelli e occhi e trovo la tua stagione. Tutto sul tuo dispositivo: la foto non va in rete.",
  "photoHint": "Meglio una foto a luce naturale, senza filtri né trucco pesante.",
  "usePhoto": "Analizza la foto del profilo",
  "uploadPhoto": "Carica una foto",
  "analyzing": "Analizzo i tuoi colori… (al primo uso scarico i modelli, ~20MB)",
  "analysisFailed": "Non sono riuscito a leggere i colori dalla foto. Puoi impostarli a mano qui sotto.",
  "detectedTitle": "Colori trovati — tocca per correggere",
  "skin": "Pelle",
  "hair": "Capelli",
  "eyes": "Occhi",
  "missingColor": "non trovato",
  "compute": "Scopri la mia stagione",
  "needTwo": "Servono almeno pelle e capelli (o correggili a mano).",
  "confidence": "Affidabilità",
  "confidenceLow": "Verdetto incerto: controlla i colori qui sopra e ricalcola.",
  "paletteTitle": "La tua palette",
  "avoidTitle": "Meglio evitare",
  "neutralsTitle": "I tuoi neutri",
  "metalTitle": "I tuoi metalli",
  "outfitsTitle": "Idee outfit nei tuoi colori",
  "wardrobeTitle": "Dal tuo guardaroba",
  "wardrobeEmpty": "Nessun capo del guardaroba è già nella tua palette.",
  "makeupTitle": "Make-up per te",
  "lips": "Labbra",
  "blush": "Blush",
  "eyeshadow": "Ombretto",
  "foundation": "Fondotinta",
  "shopFor": "Cerca negli shop",
  "redo": "Rifai l'analisi",
  "save": "Salva il risultato",
  "saved": "Salvato nel profilo",
  "outfitTop": "maglia", "outfitBottom": "pantaloni", "outfitShoes": "scarpe",
  "lipstick": "rossetto", "blushQuery": "blush", "eyeshadowQuery": "ombretto"
}
```

EN:

```json
"ui": {
  "title": "Your colors",
  "profileCard": "Color analysis — find your palette",
  "intro": "From your photo I read your skin, hair and eye colors and find your season. All on your device: the photo never leaves it.",
  "photoHint": "Best with natural light, no filters or heavy makeup.",
  "usePhoto": "Analyze profile photo",
  "uploadPhoto": "Upload a photo",
  "analyzing": "Reading your colors… (first use downloads models, ~20MB)",
  "analysisFailed": "I couldn't read colors from the photo. You can set them by hand below.",
  "detectedTitle": "Detected colors — tap to correct",
  "skin": "Skin",
  "hair": "Hair",
  "eyes": "Eyes",
  "missingColor": "not found",
  "compute": "Find my season",
  "needTwo": "At least skin and hair are needed (or set them by hand).",
  "confidence": "Confidence",
  "confidenceLow": "Uncertain verdict: check the colors above and recompute.",
  "paletteTitle": "Your palette",
  "avoidTitle": "Better to avoid",
  "neutralsTitle": "Your neutrals",
  "metalTitle": "Your metals",
  "outfitsTitle": "Outfit ideas in your colors",
  "wardrobeTitle": "From your wardrobe",
  "wardrobeEmpty": "No wardrobe item is in your palette yet.",
  "makeupTitle": "Makeup for you",
  "lips": "Lips",
  "blush": "Blush",
  "eyeshadow": "Eyeshadow",
  "foundation": "Foundation",
  "shopFor": "Search the shops",
  "redo": "Redo the analysis",
  "save": "Save the result",
  "saved": "Saved to profile",
  "outfitTop": "sweater", "outfitBottom": "trousers", "outfitShoes": "shoes",
  "lipstick": "lipstick", "blushQuery": "blush", "eyeshadowQuery": "eyeshadow"
}
```

- [ ] **Step 2: Pagina** — `ArmocromiaPage.jsx`:

```jsx
import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useProfile } from '../../context/ProfileContext';
import { useWardrobe } from '../../context/WardrobeContext';
import { Header, Button, Icon } from '../../components/common';
import { analyzeFaceColors } from '../../utils/faceColorAnalysis';
import { classifySeason } from '../../utils/armocromiaClassifier';
import { getSeason } from '../../utils/armocromiaSeasons';
import { buildShopLinks } from '../../utils/shopLinks';
import { matchWardrobe } from '../../utils/armocromiaWardrobe';
import { resizeImageFile } from '../../utils/imageUtils';
import './ArmocromiaPage.css';

/**
 * Armocromia: foto → colori personali (correggibili) → stagione → palette,
 * outfit con link shop, capi del guardaroba in palette, make-up.
 * Analisi on-device (faceColorAnalysis); qui solo orchestrazione e UI.
 */
export default function ArmocromiaPage() {
  const { t, i18n } = useTranslation();
  const navigate = useNavigate();
  const { referencePhoto, armocromia, setArmocromia } = useProfile();
  const { items } = useWardrobe();
  const lang = i18n.language?.startsWith('en') ? 'en' : 'it';

  // fase: idle | analyzing | detected | result
  const [phase, setPhase] = useState(armocromia ? 'result' : 'idle');
  const [detected, setDetected] = useState(
    armocromia?.detected || { skin: null, hair: null, eyes: null }
  );
  const [confidence, setConfidence] = useState(armocromia?.confidence ?? null);
  const [failed, setFailed] = useState(false);
  const [verdict, setVerdict] = useState(armocromia || null);
  const [savedNow, setSavedNow] = useState(false);

  const analyze = async (photoUrl) => {
    setPhase('analyzing');
    setFailed(false);
    const res = await analyzeFaceColors(photoUrl);
    if (res) {
      setDetected({ skin: res.skin, hair: res.hair, eyes: res.eyes });
      setConfidence(res.confidence);
    } else {
      setDetected({ skin: null, hair: null, eyes: null });
      setConfidence(null);
      setFailed(true);
    }
    setPhase('detected');
  };

  const handleUpload = async (e) => {
    const file = e.target.files?.[0];
    e.target.value = '';
    if (!file) return;
    try {
      const dataUrl = await resizeImageFile(file, 1024, 0.85);
      analyze(dataUrl);
    } catch {
      setFailed(true);
      setPhase('detected');
    }
  };

  const compute = () => {
    const r = classifySeason(detected);
    if (!r) return;
    setVerdict({
      season: r.season,
      detected,
      axes: r.axes,
      confidence: r.confidence,
      updatedAt: new Date().toISOString(),
    });
    setSavedNow(false);
    setPhase('result');
  };

  const season = verdict ? getSeason(verdict.season) : null;
  const wardrobeMatches = season ? matchWardrobe(items, season.id) : [];

  // Tre combo outfit dalla palette: [colore, neutro, neutro/colore]
  const outfits = season
    ? [
        [season.palette[0], season.neutrals[0], season.neutrals[1]],
        [season.palette[1], season.palette[3], season.neutrals[0]],
        [season.palette[2], season.neutrals[2] || season.neutrals[0], season.palette[4]],
      ]
    : [];
  const outfitParts = [t('armocromia.ui.outfitTop'), t('armocromia.ui.outfitBottom'), t('armocromia.ui.outfitShoes')];

  const swatchRow = (colors) => (
    <div className="armocromia__swatches">
      {colors.map((c) => (
        <span key={c.nameKey + c.hex} className="armocromia__swatch" title={t(c.nameKey)}>
          <i style={{ backgroundColor: c.hex }} />
          <small>{t(c.nameKey)}</small>
        </span>
      ))}
    </div>
  );

  const shopRow = (kind, query) => (
    <span className="armocromia__shops">
      {buildShopLinks({ kind, query, lang }).map((l) => (
        <a key={l.shop} href={l.url} target="_blank" rel="noopener">
          <Icon name="external" size={11} /> {l.label}
        </a>
      ))}
    </span>
  );

  return (
    <div className="sv-page armocromia">
      <Header title={t('armocromia.ui.title')} onBack={() => navigate(-1)} />

      {phase === 'idle' && (
        <section className="armocromia__intro">
          <p>{t('armocromia.ui.intro')}</p>
          <p className="sv-label">{t('armocromia.ui.photoHint')}</p>
          {referencePhoto && (
            <Button fullWidth onClick={() => analyze(referencePhoto)}>
              {t('armocromia.ui.usePhoto')}
            </Button>
          )}
          <label className="armocromia__upload">
            <Button fullWidth variant="secondary" icon={<Icon name="camera" size={15} />} as="span">
              {t('armocromia.ui.uploadPhoto')}
            </Button>
            <input type="file" accept="image/*" hidden onChange={handleUpload} />
          </label>
        </section>
      )}

      {phase === 'analyzing' && (
        <p className="armocromia__status sv-label">{t('armocromia.ui.analyzing')}</p>
      )}

      {(phase === 'detected' || phase === 'result') && (
        <section className="armocromia__detected">
          <h3 className="sv-label">{t('armocromia.ui.detectedTitle')}</h3>
          {failed && <p className="armocromia__failed">{t('armocromia.ui.analysisFailed')}</p>}
          <div className="armocromia__pickers">
            {['skin', 'hair', 'eyes'].map((part) => (
              <label key={part} className="armocromia__picker">
                <input
                  type="color"
                  value={detected[part] || '#888888'}
                  onChange={(e) => {
                    setDetected((prev) => ({ ...prev, [part]: e.target.value }));
                    setPhase('detected');
                  }}
                />
                <i style={{ backgroundColor: detected[part] || 'transparent' }} />
                <span className="sv-label">{t(`armocromia.ui.${part}`)}</span>
                {!detected[part] && <small>{t('armocromia.ui.missingColor')}</small>}
              </label>
            ))}
          </div>
          {phase === 'detected' && (
            <>
              <Button fullWidth onClick={compute} disabled={!detected.skin && !detected.hair}>
                {t('armocromia.ui.compute')}
              </Button>
              {!detected.skin && !detected.hair && (
                <p className="sv-label">{t('armocromia.ui.needTwo')}</p>
              )}
            </>
          )}
        </section>
      )}

      {phase === 'result' && season && (
        <section className="armocromia__result">
          <div className="armocromia__verdict">
            <h2>{t(season.nameKey)}</h2>
            <p>{t(season.descKey)}</p>
            <p className="sv-label">
              {t('armocromia.ui.confidence')}: {Math.round((verdict.confidence ?? 0) * 100)}%
              {' — '}{t(`armocromia.undertone.${season.makeup.foundationUndertone}`)}
            </p>
            {(verdict.confidence ?? 0) < 0.25 && (
              <p className="armocromia__failed">{t('armocromia.ui.confidenceLow')}</p>
            )}
          </div>

          <h3 className="sv-label">{t('armocromia.ui.paletteTitle')}</h3>
          {swatchRow(season.palette)}
          <h3 className="sv-label">{t('armocromia.ui.neutralsTitle')}</h3>
          {swatchRow(season.neutrals)}
          <h3 className="sv-label">{t('armocromia.ui.avoidTitle')}</h3>
          {swatchRow(season.avoid)}
          <p className="armocromia__metal sv-label">
            {t('armocromia.ui.metalTitle')}: <strong>{t(`armocromia.metal.${season.metal}`)}</strong>
          </p>

          <h3 className="sv-label">{t('armocromia.ui.outfitsTitle')}</h3>
          <div className="armocromia__outfits">
            {outfits.map((combo, i) => (
              <div key={i} className="armocromia__outfit">
                {combo.map((c, j) => (
                  <div key={j} className="armocromia__outfit-item">
                    <i style={{ backgroundColor: c.hex }} />
                    <span>{t(c.nameKey)} — {outfitParts[j]}</span>
                    {shopRow('clothing', `${outfitParts[j]} ${t(c.nameKey)}`)}
                  </div>
                ))}
              </div>
            ))}
          </div>

          <h3 className="sv-label">{t('armocromia.ui.wardrobeTitle')}</h3>
          {wardrobeMatches.length === 0 ? (
            <p className="sv-label">{t('armocromia.ui.wardrobeEmpty')}</p>
          ) : (
            <ul className="armocromia__wardrobe">
              {wardrobeMatches.slice(0, 8).map(({ item, paletteHex }) => (
                <li key={item.id}>
                  {item.photo && <img src={item.photo} alt={item.name} />}
                  <span>{item.name}</span>
                  <i style={{ backgroundColor: paletteHex }} />
                </li>
              ))}
            </ul>
          )}

          <h3 className="sv-label">{t('armocromia.ui.makeupTitle')}</h3>
          <div className="armocromia__makeup">
            {[
              ['lips', season.makeup.lips, t('armocromia.ui.lipstick')],
              ['blush', season.makeup.blush, t('armocromia.ui.blushQuery')],
              ['eyeshadow', season.makeup.eyes, t('armocromia.ui.eyeshadowQuery')],
            ].map(([key, colors, productQuery]) => (
              <div key={key} className="armocromia__makeup-row">
                <span className="sv-label">{t(`armocromia.ui.${key}`)}</span>
                {swatchRow(colors)}
                {shopRow('makeup', `${productQuery} ${t(colors[0].nameKey)}`)}
              </div>
            ))}
            <p className="sv-label">
              {t('armocromia.ui.foundation')}: {t(`armocromia.undertone.${season.makeup.foundationUndertone}`)}
            </p>
          </div>

          <div className="armocromia__actions">
            <Button
              fullWidth
              icon={<Icon name={savedNow ? 'check' : 'heart'} size={15} />}
              onClick={() => { setArmocromia(verdict); setSavedNow(true); }}
              disabled={savedNow}
            >
              {savedNow ? t('armocromia.ui.saved') : t('armocromia.ui.save')}
            </Button>
            <Button fullWidth variant="secondary" icon={<Icon name="refresh" size={14} />}
              onClick={() => { setPhase('idle'); setVerdict(null); }}>
              {t('armocromia.ui.redo')}
            </Button>
          </div>
        </section>
      )}
    </div>
  );
}
```

NB sul `Button as="span"`: se il componente `Button` non supporta `as`,
sostituire con un input file nascosto + `ref.click()` come fa TryOnPage
(`fileInputRef`) — NON aggiungere prop nuove a `Button`.

- [ ] **Step 3: CSS** — `ArmocromiaPage.css` (usare i token `--sv-*` esistenti):

```css
/* Armocromia: campioni colore, verdetto, combo outfit, make-up. */
.armocromia__intro { display: flex; flex-direction: column; gap: var(--sv-space-3); }
.armocromia__upload input { display: none; }
.armocromia__status { text-align: center; margin: var(--sv-space-5) auto; }
.armocromia__failed { color: var(--sv-error, #b3261e); font-size: 0.85rem; }

.armocromia__pickers { display: flex; gap: var(--sv-space-3); margin: var(--sv-space-3) 0; }
.armocromia__picker { position: relative; flex: 1; display: flex; flex-direction: column;
  align-items: center; gap: 4px; cursor: pointer; }
.armocromia__picker input[type='color'] { position: absolute; inset: 0; opacity: 0; cursor: pointer; }
.armocromia__picker i { width: 44px; height: 44px; border-radius: 50%;
  border: 1px solid var(--sv-border); display: block; }

.armocromia__verdict h2 { margin: var(--sv-space-3) 0 4px; }
.armocromia__swatches { display: flex; flex-wrap: wrap; gap: var(--sv-space-2);
  margin: var(--sv-space-2) 0 var(--sv-space-4); }
.armocromia__swatch { display: flex; flex-direction: column; align-items: center;
  gap: 2px; width: 64px; }
.armocromia__swatch i { width: 36px; height: 36px; border-radius: 8px;
  border: 1px solid var(--sv-border); display: block; }
.armocromia__swatch small { font-size: 0.65rem; text-align: center; line-height: 1.15; }

.armocromia__outfits { display: flex; flex-direction: column; gap: var(--sv-space-3);
  margin-bottom: var(--sv-space-4); }
.armocromia__outfit { border: 1px solid var(--sv-border); border-radius: 12px;
  padding: var(--sv-space-3); display: flex; flex-direction: column; gap: var(--sv-space-2); }
.armocromia__outfit-item { display: flex; align-items: center; gap: var(--sv-space-2);
  flex-wrap: wrap; font-size: 0.85rem; }
.armocromia__outfit-item i { width: 18px; height: 18px; border-radius: 4px;
  border: 1px solid var(--sv-border); flex-shrink: 0; }
.armocromia__shops { display: inline-flex; gap: var(--sv-space-2); margin-left: auto; }
.armocromia__shops a { display: inline-flex; align-items: center; gap: 3px;
  font-size: 0.75rem; text-decoration: underline; }

.armocromia__wardrobe { list-style: none; padding: 0; margin: 0 0 var(--sv-space-4);
  display: flex; flex-direction: column; gap: var(--sv-space-2); }
.armocromia__wardrobe li { display: flex; align-items: center; gap: var(--sv-space-2); }
.armocromia__wardrobe img { width: 40px; height: 40px; object-fit: cover; border-radius: 8px; }
.armocromia__wardrobe i { width: 16px; height: 16px; border-radius: 50%;
  border: 1px solid var(--sv-border); margin-left: auto; }

.armocromia__makeup-row { margin-bottom: var(--sv-space-3); }
.armocromia__actions { display: flex; flex-direction: column; gap: var(--sv-space-2);
  margin: var(--sv-space-4) 0; }
```

- [ ] **Step 4: Route e card** — in `App.jsx` importare la pagina e aggiungere la
route dentro il layout protetto, accanto alle altre:

```jsx
import ArmocromiaPage from './pages/ArmocromiaPage/ArmocromiaPage';
// ...
<Route path="/armocromia" element={<ArmocromiaPage />} />
```

In `ProfilePage.jsx`, sotto la sezione della foto di riferimento, una card/bottone:

```jsx
<Button
  fullWidth
  variant="secondary"
  icon={<Icon name="sparkle" size={15} />}
  onClick={() => navigate('/armocromia')}
>
  {t('armocromia.ui.profileCard')}
</Button>
```

(se `ProfilePage` non ha già `useNavigate`, aggiungerlo; seguire lo stile delle
altre azioni della pagina).

- [ ] **Step 5: Gate**

Run: `npm test` e `npm run build`
Expected: verde (i18n parity inclusa — il test del Task 3 copre le chiavi nuove
solo se sono nel blocco `armocromia`; controllare comunque a mano che it/en
abbiano lo stesso numero di chiavi) e build ok.

- [ ] **Step 6: Commit**

```bash
git add src/pages/ArmocromiaPage/ src/App.jsx src/pages/ProfilePage/ProfilePage.jsx src/i18n/it.json src/i18n/en.json
git commit -m "feat(armocromia): pagina /armocromia — analisi, verdetto, palette, shop, guardaroba, make-up"
```

---

### Task 9: Verifica a schermo (browser vero) + screenshot

**Files:**
- Create: `docs/verifiche/2026-07-18-armocromia/README.md` (+ screenshot)

**Metodo** (harness già rodato in questo repo — vedi memoria di sessione):
dev server in modalità locale (`VITE_SUPABASE_URL='' VITE_SUPABASE_ANON_KEY=''
npm run dev -- --port 5174 --strictPort`), puppeteer-core con il Chrome di
sistema headless, seed `localStorage` (`sv_auth_user`, `sv_profile_<id>` con
`referencePhoto` = foto VERA di persona — es. `docs/verifiche/2026-07-16-su-di-te/risultato-warping-posa.jpg`
in dataURL — e `onboarded: true`, `sv_items` con 2-3 capi con colori in/fuori palette).

- [ ] **Step 1** — flusso da verificare (driver come `drive.js` della memoria di sessione):
  1. `/profile` → la card armocromia c'è → tap → `/armocromia`;
  2. "Analizza la foto del profilo" → stato `analyzing` → entro 240s compaiono i 3 campioni (skin/hair non null su foto vera);
  3. "Scopri la mia stagione" → verdetto con nome stagione, palette ≥5 campioni, sezione outfit con ≥2 link shop per riga (href corretti `zalando.it/...q=...`), guardaroba (il capo seminato in palette compare, quello fuori no), make-up con link;
  4. tap su un campione → `input type=color` riceve il tap (basta verificarne la presenza e il change via JS) → ricalcolo cambia/conferma il verdetto;
  5. "Salva il risultato" → ricarica pagina → si riapre direttamente sul risultato salvato (persistenza locale);
  6. console: zero errori (gli INFO di TFLite sono attesi).
- [ ] **Step 2** — salvare screenshot (intro, colori trovati, verdetto+palette, outfit+shop, make-up) in `docs/verifiche/2026-07-18-armocromia/` con un `README.md` che li elenca; annotare esplicitamente che la VERIFICA UMANA di Lorenzo resta pendente.
- [ ] **Step 3: Gate finale**

Run: `npm test` e `npm run build`
Expected: verde, build ok.

- [ ] **Step 4: Commit**

```bash
git add docs/verifiche/2026-07-18-armocromia/
git commit -m "docs(armocromia): verifica a schermo — screenshot del flusso completo"
```

---

## Self-Review

- **Copertura spec:** §3.1 colorSampling→T1, classifier→T2, seasons→T3, shopLinks→T4, wardrobe→T5, faceColorAnalysis→T6, pagina→T8; §3.2 persistenza→T7; §5 test→T1-T5 (puri) + T9 (schermo); §2 correzione manuale→T8 (picker), 12 stagioni→T2/T3, link shop→T4/T8, make-up→T3/T8, ingresso dal Profilo→T8, persistenza→T7. Il "bonus avatar" NON esiste più nello spec ripulito. ✓
- **Placeholder:** nessun TBD/TODO; ogni step con codice ha il codice. La UI del Task 8 è la più lunga ma completa (JSX+CSS+i18n+route+card). ✓
- **Coerenza tipi:** id stagione identici in SEASON_AXES/SEASONS/i18n (test d'integrità del T3 li incrocia); `classifySeason` consumato dal T8 con la stessa firma del T2; `detected {skin,hair,eyes}` stessa forma in T6/T8/persistenza; `buildShopLinks({kind,query,lang})` uguale in T4/T8; `matchWardrobe(items, seasonId)` uguale in T5/T8. ✓
- **Numeri tarati:** formule assi, centroidi e fixture validati al 100% in prototipo node prima della stesura (nota in testa al piano). ✓
