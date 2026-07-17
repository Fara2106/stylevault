# Prova AI via prompt + rimozione avatar — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** La scheda AI della pagina Prova genera un prompt di try-on da copiare in Gemini/ChatGPT (niente chiave, niente costi) e l'intera feature avatar viene rimossa, lasciando la sola "Su di te".

**Architecture:** Un modulo puro `tryOnPrompt.js` costruisce il prompt dai capi dell'outfit (lessici EN interni). La UI mostra prompt modificabile + istruzioni + link. Si elimina il percorso Gemini (chiave inclusa) e tutti i moduli avatar, verificando a ogni passo che "Su di te" e la build reggano.

**Tech Stack:** React 19 + Vite, react-router 7, i18next (IT/EN), Vitest.

## Global Constraints

- Nessun nuovo accesso di rete: l'app **non** chiama API immagine (né Gemini, né altro).
- Il prompt è in **inglese**; le istruzioni UI nella lingua dell'app (IT/EN).
- Dopo OGNI task: `npm test` verde **e** `npm run build` ok.
- La scheda **"Su di te" deve continuare a funzionare** (moduli in §4.2 dello spec: `modelImage/modelComposer/modelWarp/tryonComposer/garmentImage/personSilhouette/bodyAnalysis` NON si toccano).
- Funzioni pure senza DOM/rete per tutto ciò che è testato.
- Spec di riferimento: `docs/superpowers/specs/2026-07-17-tryon-prompt-design.md`.

---

### Task 1: Lessici EN + descrittore del capo (`tryOnPrompt.js`, puro)

**Files:**
- Create: `src/utils/tryOnPrompt.js`
- Test: `src/utils/tryOnPrompt.test.js`

**Interfaces:**
- Produces: `garmentDescriptor(item) → string` dove `item = { name, subcategory, colors }`. Ritorna es. `"white button-up shirt"`; colore sconosciuto/assente → solo il capo; sotto-categoria sconosciuta → ripiego su `item.name`.

- [ ] **Step 1: Test che fallisce**

```js
import { describe, it, expect } from 'vitest';
import { garmentDescriptor } from './tryOnPrompt';

describe('garmentDescriptor', () => {
  it('unisce colore inglese e capo', () => {
    expect(garmentDescriptor({ subcategory: 'shirt', colors: ['white'] }))
      .toBe('white button-up shirt');
  });
  it('denim usa la parola blu', () => {
    expect(garmentDescriptor({ subcategory: 'jeans', colors: ['denim'] }))
      .toBe('denim-blue jeans');
  });
  it('colore sconosciuto: solo il capo', () => {
    expect(garmentDescriptor({ subcategory: 'sneakers', colors: ['fuxia'] }))
      .toBe('sneakers');
  });
  it('sotto-categoria sconosciuta: ripiego sul nome', () => {
    expect(garmentDescriptor({ subcategory: 'zzz', colors: ['black'], name: 'Kimono' }))
      .toBe('black Kimono');
  });
});
```

- [ ] **Step 2: Verifica che fallisca**

Run: `npx vitest run src/utils/tryOnPrompt.test.js`
Expected: FAIL ("garmentDescriptor is not a function" / modulo assente)

- [ ] **Step 3: Implementazione minima**

```js
/**
 * Costruzione del prompt di try-on da copiare in Gemini/ChatGPT.
 * Puro: nessun DOM, nessuna rete. Il prompt è in inglese (rende meglio coi
 * modelli immagine); le istruzioni nella UI restano nella lingua dell'app.
 */

/** Colore (id come in categories.js CLOTHING_COLORS) → parola inglese. */
const COLOR_EN = {
  black: 'black', white: 'white', gray: 'gray', navy: 'navy-blue', blue: 'blue',
  lightblue: 'light-blue', red: 'red', burgundy: 'burgundy', pink: 'pink',
  green: 'green', olive: 'olive-green', brown: 'brown', tan: 'tan', beige: 'beige',
  cream: 'cream', yellow: 'yellow', orange: 'orange', purple: 'purple',
  lavender: 'lavender', coral: 'coral', gold: 'gold', silver: 'silver',
  denim: 'denim-blue', khaki: 'khaki',
};

/** Sotto-categoria (id come in categories.js) → sostantivo inglese del capo. */
const SUBCATEGORY_EN = {
  tshirt: 't-shirt', shirt: 'button-up shirt', hoodie: 'hoodie', sweater: 'sweater',
  tank: 'tank top', polo: 'polo shirt', croptop: 'crop top', blouse: 'blouse',
  jeans: 'jeans', trousers: 'trousers', shorts: 'shorts', skirt: 'skirt',
  joggers: 'joggers', leggings: 'leggings', dresspants: 'dress trousers',
  jacket: 'jacket', coat: 'coat', puffer: 'puffer jacket', blazer: 'blazer',
  trench: 'trench coat', vest: 'vest', raincoat: 'raincoat', cardigan: 'cardigan',
  shortdress: 'short dress', longdress: 'long dress', jumpsuit: 'jumpsuit',
  eveningdress: 'evening dress',
  sneakers: 'sneakers', boots: 'boots', loafers: 'loafers', sandals: 'sandals',
  heels: 'heels', ankleboots: 'ankle boots', pumps: 'pumps',
  hat: 'hat', scarf: 'scarf', belt: 'belt', bag: 'bag', sunglasses: 'sunglasses',
  jewelry: 'jewelry',
};

export function garmentDescriptor(item) {
  const noun = SUBCATEGORY_EN[item.subcategory] || item.name || 'garment';
  const colorId = Array.isArray(item.colors) ? item.colors[0] : undefined;
  const color = COLOR_EN[colorId];
  return color ? `${color} ${noun}` : noun;
}
```

- [ ] **Step 4: Verifica che passi**

Run: `npx vitest run src/utils/tryOnPrompt.test.js`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/utils/tryOnPrompt.js src/utils/tryOnPrompt.test.js
git commit -m "feat(prova): lessici EN e descrittore del capo per il prompt"
```

---

### Task 2: `buildTryOnPrompt(items)` — prompt completo (puro)

**Files:**
- Modify: `src/utils/tryOnPrompt.js`
- Test: `src/utils/tryOnPrompt.test.js`

**Interfaces:**
- Consumes: `garmentDescriptor` (Task 1).
- Produces: `buildTryOnPrompt(items) → string`. `items` = capi dell'outfit `[{name, subcategory, colors, photo}]`. Le immagini sono numerate da `Image 2` (la `Image 1` è la persona). Con `items` vuoto ritorna comunque un prompt valido senza righe capo.

- [ ] **Step 1: Test che fallisce**

```js
import { buildTryOnPrompt } from './tryOnPrompt';

describe('buildTryOnPrompt', () => {
  const items = [
    { subcategory: 'shirt', colors: ['white'] },
    { subcategory: 'trousers', colors: ['navy'] },
    { subcategory: 'sneakers', colors: ['white'] },
  ];
  it('numera i capi partendo da Image 2', () => {
    const p = buildTryOnPrompt(items);
    expect(p).toContain('1. white button-up shirt (Image 2)');
    expect(p).toContain('2. navy-blue trousers (Image 3)');
    expect(p).toContain('3. white sneakers (Image 4)');
  });
  it('preserva identità e chiede solo la foto finale', () => {
    const p = buildTryOnPrompt(items);
    expect(p).toMatch(/preserve their exact face/i);
    expect(p).toMatch(/return only the final edited photograph/i);
  });
  it('senza capi non lancia e resta valido', () => {
    expect(() => buildTryOnPrompt([])).not.toThrow();
    expect(buildTryOnPrompt([])).toMatch(/photorealistic virtual try-on/i);
  });
});
```

- [ ] **Step 2: Verifica che fallisca**

Run: `npx vitest run src/utils/tryOnPrompt.test.js`
Expected: FAIL ("buildTryOnPrompt is not a function")

- [ ] **Step 3: Implementazione minima**

```js
export function buildTryOnPrompt(items = []) {
  const lines = items.map(
    (item, i) => `${i + 1}. ${garmentDescriptor(item)} (Image ${i + 2}).`
  );
  const garments = lines.length
    ? `Dress this same person in the garments shown in the next images:\n${lines.join('\n')}`
    : 'Dress this same person in the garments shown in the following images.';

  return [
    'Photorealistic virtual try-on.',
    '',
    "Image 1 is a real person — preserve their exact face, hairstyle, skin tone, " +
      'body shape, height, pose and background with total fidelity. Do not change ' +
      'their identity in any way.',
    '',
    garments,
    '',
    "Replace ONLY the person's current clothing with these garments. Fit each item " +
      'naturally with realistic folds, seams and shadows, matching the lighting and ' +
      'perspective of Image 1. Full-body framing, head to feet, sharp focus, natural ' +
      'light. Return only the final edited photograph, no text.',
  ].join('\n');
}
```

- [ ] **Step 4: Verifica che passi**

Run: `npx vitest run src/utils/tryOnPrompt.test.js`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/utils/tryOnPrompt.js src/utils/tryOnPrompt.test.js
git commit -m "feat(prova): buildTryOnPrompt compone il prompt completo dai capi"
```

---

### Task 3: Scheda "Prompt AI" nella pagina Prova

**Files:**
- Modify: `src/pages/TryOnPage/TryOnPage.jsx` (sostituisce il corpo della scheda AI; toglie l'uso di `getGeminiKey/generateTryOnPhoto`)
- Modify: `src/pages/TryOnPage/TryOnPage.css` (stili textarea/istruzioni/link)
- Modify: `src/i18n/it.json`, `src/i18n/en.json` (chiavi `tryon.prompt*`)

**Interfaces:**
- Consumes: `buildTryOnPrompt` (Task 2).

- [ ] **Step 1: i18n** — aggiungere in `it.json` e `en.json` sotto `tryon`:
  `promptTitle`, `promptIntro`, `promptCopy`, `promptCopied`, `promptStep1..4`
  (apri ChatGPT/Gemini; carica la tua foto; carica le foto dei capi; incolla il
  prompt e genera), `promptOpenChatgpt`, `promptOpenGemini`, `promptGarments`
  (etichetta lista immagini capi). IT e EN coerenti.

- [ ] **Step 2: UI** — nel ramo della scheda AI di `TryOnPage.jsx`:
  - calcolare `const promptText = buildTryOnPrompt(outfitItems)` e tenerlo in uno
    stato locale editabile (`useState(promptText)`, risincronizzato quando cambia l'outfit);
  - `<textarea>` legata a quello stato + bottone **Copia** (`navigator.clipboard.writeText`, con stato "copiato");
  - lista numerata delle istruzioni (`promptStep1..4`);
  - link `https://chatgpt.com/` e `https://gemini.google.com/` (`target="_blank" rel="noopener"`);
  - lista delle immagini dei capi dell'outfit: per ognuna un `<a>` alla `item.photo`
    (`download` se `data:`/locale, altrimenti `target="_blank"`) così Mary le carica in chat;
  - rimuovere da questo ramo `getGeminiKey`, `generateTryOnPhoto`, i messaggi
    `photoNeedsKey/photoSetKey`, lo stato di caricamento della vecchia chiamata.

- [ ] **Step 3: Verifica manuale + test leggero**

Run: `npm run dev` → pagina Prova → scheda "Prompt AI": il prompt compare, "Copia"
copia, i link aprono, le immagini dei capi sono raggiungibili. "Su di te" invariata.
Run: `npm test` e `npm run build`
Expected: verde e build ok.

- [ ] **Step 4: Commit**

```bash
git add src/pages/TryOnPage/ src/i18n/it.json src/i18n/en.json
git commit -m "feat(prova): scheda Prompt AI — prompt copiabile + istruzioni, niente chiave"
```

---

### Task 4: Eliminare il servizio Gemini e la UI della chiave

**Files:**
- Delete: `src/services/geminiTryon.js`, `src/services/geminiTryon.test.js`
- Modify: `src/pages/ProfilePage/ProfilePage.jsx` (via la sezione "chiave Gemini")
- Modify: `src/pages/TryOnPage/TryOnPage.jsx` (rimuovere l'import residuo se presente)
- Modify: `src/i18n/it.json`, `src/i18n/en.json` (via chiavi della chiave Gemini se inutilizzate)

- [ ] **Step 1** — `git rm src/services/geminiTryon.js src/services/geminiTryon.test.js`
- [ ] **Step 2** — in `ProfilePage.jsx` rimuovere input/salvataggio della chiave e i relativi import.
- [ ] **Step 3: Nessun riferimento residuo**

Run: `grep -rn "geminiTryon\|getGeminiKey\|generateTryOnPhoto\|sv_gemini_key" src`
Expected: nessun risultato.

- [ ] **Step 4: Gate**

Run: `npm test` e `npm run build`
Expected: verde e build ok.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor(prova): via il percorso Gemini e la chiave utente"
```

---

### Task 5: Rimuovere l'USO dell'avatar dai consumatori

**Files:**
- Modify: `src/pages/TryOnPage/TryOnPage.jsx` (via import e scheda `OutfitOnAvatar`; restano 2 schede)
- Modify: `src/pages/ProfilePage/ProfilePage.jsx` (via editor avatar)
- Modify: `src/pages/OnboardingPage/OnboardingPage.jsx` (via step avatar; resta il caricamento foto se presente)
- Modify: `src/context/ProfileContext.jsx` (via `avatarConfig` e import `avatarOptions`; `DEFAULT_PROFILE` tiene `referencePhoto`, `onboarded`)
- Modify: `src/services/db.js` (fetch/upsert smettono di leggere/scrivere `avatar_config`)
- Modify: `src/i18n/it.json`, `src/i18n/en.json` (via chiavi `avatar.*`)

- [ ] **Step 1** — TryOnPage: eliminare l'import `OutfitOnAvatar` e il ramo/scheda "Sull'avatar"; la scheda predefinita diventa "Su di te" (mantenendo la logica esistente che apre "Su di te" con outfit+foto pronti).
- [ ] **Step 2** — ProfilePage: eliminare import e sezione `AvatarEditor`.
- [ ] **Step 3** — OnboardingPage: eliminare gli step di configurazione avatar (`AvatarEditor`/avatarOptions); se l'onboarding resta solo per la foto, tenerlo minimale, altrimenti coerente col flusso attuale.
- [ ] **Step 4** — ProfileContext: togliere `avatarConfig` da `DEFAULT_PROFILE` e l'import `DEFAULT_AVATAR_CONFIG`; `db.js` non tocca più `avatar_config`.
- [ ] **Step 5** — rimuovere da `it.json`/`en.json` le chiavi `avatar.*` non più referenziate.
- [ ] **Step 6: Nessun riferimento residuo nei consumatori**

Run: `grep -rn "OutfitOnAvatar\|AvatarEditor\|avatarConfig\|avatarOptions\|Avatar3D" src/pages src/context src/services`
Expected: nessun risultato.

- [ ] **Step 7: Gate**

Run: `npm test` e `npm run build`; `npm run dev` → "Su di te" funziona, Profilo e Prova ok.
Expected: verde, build ok, nessun errore a runtime.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "refactor(avatar): via l'uso dell'avatar da Prova, Profilo, Onboarding, Profilo-context"
```

---

### Task 6: Cancellare i file avatar orfani e la dipendenza three

**Files:**
- Delete: `src/components/Avatar/Avatar3D.jsx`, `Avatar3DBoundary.jsx`, `AvatarSvg.jsx`, `AvatarEditor.jsx`, `OutfitOnAvatar.jsx`
- Delete: `src/utils/avatarOptions.js`, `avatarMesh.js`, `garmentMesh.js`, `garmentPanel.js`, `webgl.js`
- Delete: `src/utils/avatarMesh.test.js`, `garmentMesh.test.js`, `garmentPanel.test.js`
- Modify: `package.json` (via `three`)

- [ ] **Step 1: Conferma che sono orfani** (nessuno li importa più a parte l'un l'altro)

Run: `grep -rn "avatarMesh\|garmentMesh\|garmentPanel\|avatarOptions\|webgl\|Avatar3D\|AvatarSvg\|AvatarEditor\|OutfitOnAvatar" src | grep -v "src/components/Avatar/\|src/utils/avatarMesh\|src/utils/garmentMesh\|src/utils/garmentPanel\|src/utils/avatarOptions\|src/utils/webgl"`
Expected: nessun risultato (solo auto-riferimenti interni ai file da cancellare).

- [ ] **Step 2: Verifica che `Avatar.css` e `ModelTryOn.jsx` NON siano tra i cancellati** (li usa "Su di te"): restano.

- [ ] **Step 3: Cancellazione**

```bash
git rm src/components/Avatar/Avatar3D.jsx src/components/Avatar/Avatar3DBoundary.jsx \
  src/components/Avatar/AvatarSvg.jsx src/components/Avatar/AvatarEditor.jsx \
  src/components/Avatar/OutfitOnAvatar.jsx \
  src/utils/avatarOptions.js src/utils/avatarMesh.js src/utils/garmentMesh.js \
  src/utils/garmentPanel.js src/utils/webgl.js \
  src/utils/avatarMesh.test.js src/utils/garmentMesh.test.js src/utils/garmentPanel.test.js
```

- [ ] **Step 4: Via three**

Run: `npm uninstall three`
Verifica: `grep -rn "from 'three'\|@react-three" src` → nessun risultato.

- [ ] **Step 5: Gate finale**

Run: `npm test` e `npm run build`; `npm run dev` → app parte, "Su di te" funziona.
Expected: verde, build ok (bundle più leggero), nessun import rotto.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor(avatar): cancellati i file avatar e la dipendenza three"
```

---

## Self-Review

- **Copertura spec:** §3.1 prompt → Task 1-2; §3.2 UI → Task 3; §3.3 rimozione Gemini → Task 4; §4.1 file da rimuovere → Task 6; §4.2 da mantenere → vincolo globale + Task 6 Step 2; §4.3 consumatori → Task 5; §4.4 gate → gate in ogni task. §7 esempio prompt → verificato dai test del Task 2.
- **Ordine sicuro:** prima si toglie l'USO (Task 5) poi si cancellano i file (Task 6), così la build non si rompe.
- **Placeholder:** nessuno; i passi di cancellazione sono comandi concreti, non codice inventato.
- **Coerenza tipi:** `garmentDescriptor(item)` e `buildTryOnPrompt(items)` usati come definiti; `item` sempre `{name, subcategory, colors, photo}`.
- **Fuori da questo piano:** aggiornare lo spec armocromia (togliere bonus avatar) va fatto quando si pianifica l'armocromia; qui non serve.
