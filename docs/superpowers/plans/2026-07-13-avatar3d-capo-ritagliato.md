# Avatar 3D — capo ritagliato sul manichino Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Nell'avatar 3D il capo appare come un capo intero ritagliato dalla foto e messo sul manichino, non come piastrella di tessuto ripetuta.

**Architecture:** L'avatar 3D smette di tilare `swatchUrl` e usa `textureUrl` (il ritaglio del capo intero con sfondo trasparente, già prodotto da `garmentImage.js`). Il ritaglio viene mappato su un **pannello curvo** (arco di cilindro) davanti al corpo + una copia dietro, dimensionato per stare nella zona del capo rispettando le proporzioni. La matematica del pannello vive in un modulo puro testabile; la costruzione three.js sta in `Avatar3D.jsx`.

**Tech Stack:** React, three.js 0.180 (`CylinderGeometry`, `TextureLoader`, `MeshStandardMaterial`), Vitest per le funzioni pure.

## Global Constraints

- **Non toccare** il lavoro non committato sulle sagome per genere (`avatarMesh.js`, `avatarOptions.js`, `AvatarEditor.jsx`, ecc.): non è parte di questo piano. Committare **solo** i file elencati in ogni task.
- **Committare su un branch dedicato**, non su `main` (es. `feat/avatar3d-capo-ritagliato`). Crearlo prima del primo commit.
- **three.js non gira nei test** (vincolo del progetto): nessun test unitario sul rendering 3D. Le funzioni pure vanno testate; il rendering si verifica a schermo.
- **Non modificare** la modalità piatta 2D (`AvatarSvg.jsx`, `OutfitOnAvatar.jsx`) né l'estrazione del capo (`garmentTexture.js`, `garmentImage.js`): `textureUrl` esiste già.
- Regola sui test (memoria del progetto): ogni test va prima visto **fallire in rosso** con l'implementazione assente/rotta, poi passare.
- Fallback invariato: capo non ritagliabile (`kind: 'flat'`, niente `textureUrl`) → capo in tinta unita col colore dominante. "Brutto no, sbagliato mai."

---

## File Structure

- **Create:** `src/utils/garmentPanel.js` — funzione pura `panelPlacement(...)` che, dato il profilo della parte principale del capo e l'aspect ratio del ritaglio, calcola posizione/dimensioni del pannello (numeri puri, niente three.js).
- **Create:** `src/utils/garmentPanel.test.js` — test Vitest di `panelPlacement`.
- **Modify:** `src/components/Avatar/Avatar3D.jsx` — usare `textureUrl` → pannelli; rimuovere il ramo piastrella (`garmentMaterial` swatch) e il decal separato (`printDecal`) dal percorso 3D; tenere il fallback tinta unita.

---

## Task 1: Modulo puro `garmentPanel` (geometria del pannello)

**Files:**
- Create: `src/utils/garmentPanel.js`
- Test: `src/utils/garmentPanel.test.js`

**Interfaces:**
- Consumes: niente (modulo puro autonomo).
- Produces:
  ```js
  // input: { profile: [[r,y],...], offsetX?: number, mirror?: boolean,
  //          aspect: number /* larghezza/altezza del ritaglio */,
  //          arc: number /* apertura max del pannello in radianti */,
  //          gap: number /* stacco dal corpo */ }
  // output: { yCenter: number, height: number, radius: number, arcAngle: number }
  export function panelPlacement(input): { yCenter, height, radius, arcAngle }
  ```
  Regole:
  - `radius = (mirror ? offsetX + maxRaggioProfilo : maxRaggioProfilo) + gap`
  - `frontWidth = radius * arc`; `regionAspect = frontWidth / heightZona`
  - se `aspect >= regionAspect` → limite in larghezza: `panelWidth = frontWidth`, `panelHeight = frontWidth / aspect`
  - altrimenti → limite in altezza: `panelHeight = heightZona`, `panelWidth = heightZona * aspect`
  - `arcAngle = panelWidth / radius`; `yCenter = (yMin + yMax) / 2`

- [ ] **Step 1: Write the failing test**

Create `src/utils/garmentPanel.test.js`:

```js
import { describe, it, expect } from 'vitest';
import { panelPlacement } from './garmentPanel';

// Profilo semplice: raggio max 0.2, quote da 1.0 a 1.5 (altezza zona = 0.5).
const profile = [
  [0.001, 1.0],
  [0.2, 1.1],
  [0.2, 1.4],
  [0.001, 1.5],
];
const arc = Math.PI; // 180°, frontWidth = radius * PI

describe('panelPlacement', () => {
  it('centra il pannello a metà della zona del capo', () => {
    const p = panelPlacement({ profile, aspect: 1, arc, gap: 0 });
    expect(p.yCenter).toBeCloseTo(1.25, 5);
  });

  it('senza mirror, raggio = raggio massimo del profilo + gap', () => {
    const p = panelPlacement({ profile, aspect: 1, arc, gap: 0.02 });
    expect(p.radius).toBeCloseTo(0.22, 5);
  });

  it('con mirror, raggio = offsetX + raggio massimo + gap (avvolge entrambe le gambe)', () => {
    const p = panelPlacement({ profile, offsetX: 0.06, mirror: true, aspect: 1, arc, gap: 0.02 });
    expect(p.radius).toBeCloseTo(0.28, 5);
  });

  it('capo alto e stretto (aspect piccolo): limite in altezza, usa tutta l’altezza zona', () => {
    const p = panelPlacement({ profile, aspect: 0.25, arc, gap: 0 });
    expect(p.height).toBeCloseTo(0.5, 5); // = altezza zona
    // panelWidth = 0.5 * 0.25 = 0.125; arcAngle = 0.125 / 0.2 = 0.625
    expect(p.arcAngle).toBeCloseTo(0.625, 5);
  });

  it('capo largo (aspect grande): limite in larghezza, non supera l’arco massimo', () => {
    const p = panelPlacement({ profile, aspect: 10, arc, gap: 0 });
    expect(p.arcAngle).toBeCloseTo(arc, 5); // arcAngle = frontWidth/radius = arc
    expect(p.height).toBeLessThan(0.5);      // altezza ridotta per tenere le proporzioni
  });

  it('più il capo è stretto, più l’arco è piccolo (monotònico)', () => {
    const stretto = panelPlacement({ profile, aspect: 0.2, arc, gap: 0 });
    const largo = panelPlacement({ profile, aspect: 0.6, arc, gap: 0 });
    expect(largo.arcAngle).toBeGreaterThan(stretto.arcAngle);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run src/utils/garmentPanel.test.js`
Expected: FAIL — `panelPlacement` non è definita / il modulo non esiste.

- [ ] **Step 3: Write minimal implementation**

Create `src/utils/garmentPanel.js`:

```js
/**
 * Geometria del pannello su cui si mappa il ritaglio del capo nell'avatar 3D.
 * Puro e senza three.js: così è testabile in Vitest (ambiente node).
 *
 * Il ritaglio (una foto di un capo, con la sua proporzione larghezza/altezza)
 * va inserito nella "zona del capo" sul corpo — l'intervallo di quota del
 * profilo — rispettando l'aspect: né schiacciato né tilato. Il pannello è un
 * arco di cilindro; qui si calcolano quota, altezza, raggio e ampiezza d'arco.
 */

/**
 * @param {Object} input
 * @param {Array<[number, number]>} input.profile  profilo [raggio, quota] della parte principale del capo
 * @param {number} [input.offsetX=0]   scostamento laterale (capi sdoppiati: gambe)
 * @param {boolean} [input.mirror=false] true se il capo è sdoppiato (pantaloni): il pannello deve avvolgere entrambe le istanze
 * @param {number} input.aspect        larghezza/altezza del ritaglio
 * @param {number} input.arc           apertura massima del pannello, in radianti
 * @param {number} input.gap           stacco dal corpo
 * @returns {{ yCenter: number, height: number, radius: number, arcAngle: number }}
 */
export function panelPlacement({ profile, offsetX = 0, mirror = false, aspect, arc, gap }) {
  const ys = profile.map(([, y]) => y);
  const yMin = Math.min(...ys);
  const yMax = Math.max(...ys);
  const regionHeight = yMax - yMin;

  const baseRadius = Math.max(...profile.map(([r]) => r));
  const radius = (mirror ? offsetX + baseRadius : baseRadius) + gap;

  const frontWidth = radius * arc;
  const regionAspect = frontWidth / regionHeight;

  let panelWidth;
  let panelHeight;
  if (aspect >= regionAspect) {
    // Ritaglio più largo della zona: riempie l'arco, si accorcia in altezza.
    panelWidth = frontWidth;
    panelHeight = frontWidth / aspect;
  } else {
    // Ritaglio più alto della zona: riempie l'altezza, si stringe d'arco.
    panelHeight = regionHeight;
    panelWidth = regionHeight * aspect;
  }

  return {
    yCenter: (yMin + yMax) / 2,
    height: panelHeight,
    radius,
    arcAngle: panelWidth / radius,
  };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npx vitest run src/utils/garmentPanel.test.js`
Expected: PASS (6 test verdi).

- [ ] **Step 5: Commit**

```bash
git checkout -b feat/avatar3d-capo-ritagliato
git add src/utils/garmentPanel.js src/utils/garmentPanel.test.js
git commit -m "feat(avatar3d): modulo puro per la geometria del pannello capo"
```

---

## Task 2: Avatar3D usa il ritaglio su pannelli (via piastrella e decal)

**Files:**
- Modify: `src/components/Avatar/Avatar3D.jsx`
- (Verifica a schermo, nessun test unitario: three.js non gira nei test.)

**Interfaces:**
- Consumes: `panelPlacement({ profile, offsetX, mirror, aspect, arc, gap })` dal Task 1; `garmentParts(kind, config)` (→ `[{ profile, offsetX, mirror }]`), `garmentLayers(outfit)` (→ `{ kind, item }`), `textures[item.id]` (→ `{ textureUrl, colorHex, kind }`) già esistenti.
- Produces: niente per altri task (ultimo task).

- [ ] **Step 1: Aggiornare gli import in testa al file**

In `src/components/Avatar/Avatar3D.jsx`, sostituire l'import dei helper mesh (riga ~24) per **togliere `radiusAt`** (non più usato) e importare `panelPlacement`:

```jsx
import { bodyProfiles } from '../../utils/avatarMesh';
import { garmentParts } from '../../utils/garmentMesh';
import { garmentLayers } from '../../utils/tryonComposer';
import { panelPlacement } from '../../utils/garmentPanel';
```

- [ ] **Step 2: Rimuovere `garmentMaterial`, `printDecal` e `DECAL_ARC`; aggiungere i helper del pannello**

Eliminare la costante `DECAL_ARC` (riga ~28) e le due funzioni `garmentMaterial` (righe ~60-77) e `printDecal` (righe ~79-148). Al loro posto, a livello di modulo (vicino a `lathe`), aggiungere:

```jsx
// Il pannello del capo: un arco di cilindro davanti al corpo, su cui si mappa
// il ritaglio del capo. L'arco massimo lascia spazio al profilo (la stampa gira
// col corpo). Il raggio e l'ampiezza reali li calcola panelPlacement.
const PANEL_ARC = (150 * Math.PI) / 180;
const PANEL_GAP = 0.02;
const PANEL_RADIAL_SEGMENTS = 24;

/** Un pannello (arco di cilindro) con sopra la texture del ritaglio. */
const garmentPanel = (placement, thetaStart, map) => {
  const geometry = new CylinderGeometry(
    placement.radius,
    placement.radius,
    Math.max(placement.height, 0.001),
    PANEL_RADIAL_SEGMENTS,
    1,
    true, // aperto: è un guscio d'arco, non un cilindro pieno
    thetaStart,
    placement.arcAngle
  );
  const material = new MeshStandardMaterial({
    map,
    transparent: true,
    side: DoubleSide,
    roughness: 0.9,
  });
  const mesh = new Mesh(geometry, material);
  mesh.position.y = placement.yCenter;
  return mesh;
};

/**
 * Carica il ritaglio del capo e, quando l'immagine è pronta (serve l'aspect
 * ratio), aggiunge un pannello davanti e uno dietro. `isCancelled` evita di
 * aggiungere mesh a una figura già ripulita da una ricostruzione successiva.
 */
const addGarmentPanels = (figure, mainPart, url, onRender, isCancelled) => {
  const map = new TextureLoader().load(url, () => {
    if (isCancelled()) {
      map.dispose();
      return;
    }
    const aspect = (map.image?.width || 1) / (map.image?.height || 1);
    const placement = panelPlacement({
      profile: mainPart.profile,
      offsetX: mainPart.offsetX,
      mirror: mainPart.mirror,
      aspect,
      arc: PANEL_ARC,
      gap: PANEL_GAP,
    });

    map.colorSpace = SRGBColorSpace;
    // Davanti, centrato sul fronte (+Z, come faceva il vecchio decal a theta 0).
    figure.add(garmentPanel(placement, -placement.arcAngle / 2, map));

    // Dietro: stessa immagine, ribaltata in orizzontale così non appare
    // speculare guardando la schiena.
    const back = map.clone();
    back.colorSpace = SRGBColorSpace;
    back.wrapS = RepeatWrapping;
    back.repeat.x = -1;
    back.needsUpdate = true;
    figure.add(garmentPanel(placement, Math.PI - placement.arcAngle / 2, back));

    onRender();
  });
};
```

- [ ] **Step 3: Sostituire il ciclo dei capi nell'effect config/outfit/textures**

Nel terzo `useEffect` (quello con dipendenze `[config, outfit, textures]`), sostituire l'intero ciclo `for (const { kind, item } of garmentLayers(outfit)) { ... }` con questo, e aggiungere il flag `cancelled` + cleanup:

```jsx
  useEffect(() => {
    const { figure, render } = stateRef.current;
    if (!figure) return undefined;

    let cancelled = false;
    clearFigure(figure);

    const body = bodyProfiles(config);
    const skin = new MeshStandardMaterial({ color: new Color(body.skinHex), roughness: 0.85 });
    const hair = new MeshStandardMaterial({ color: new Color(body.hairHex), roughness: 0.95 });

    const shadowRadius = body.legOffsetX + Math.max(...body.leg.map(([r]) => r)) * 1.8;
    const shadow = new Mesh(
      new CircleGeometry(shadowRadius, 24),
      new MeshBasicMaterial({ color: 0x000000, transparent: true, opacity: 0.18 })
    );
    shadow.rotation.x = -Math.PI / 2;
    shadow.position.y = 0.002;
    figure.add(shadow);

    figure.add(new Mesh(lathe(body.torso), skin));
    for (const sign of [-1, 1]) {
      const leg = new Mesh(lathe(body.leg), skin);
      leg.position.x = sign * body.legOffsetX;
      figure.add(leg);
      const arm = new Mesh(lathe(body.arm), skin);
      arm.position.x = sign * body.armOffsetX;
      figure.add(arm);
    }

    const head = new Mesh(new SphereGeometry(body.head.radius, 24, 18), skin);
    head.position.y = body.head.y;
    head.scale.set(0.92, 1.12, 0.95);
    figure.add(head);

    if (body.hairStyle !== 'bald') {
      const cap = new Mesh(new SphereGeometry(body.head.radius * 1.06, 24, 18), hair);
      cap.position.y = body.head.y + 0.02;
      cap.scale.set(0.95, 1.0, 0.98);
      figure.add(cap);
    }

    for (const { kind, item } of garmentLayers(outfit)) {
      const parts = garmentParts(kind, config);
      if (!parts.length) continue;
      const texture = textures?.[item.id];

      if (texture?.textureUrl) {
        // Il capo intero ritagliato, messo sul corpo come un capo — non tilato.
        addGarmentPanels(
          figure,
          parts[0],
          texture.textureUrl,
          () => {
            if (!cancelled) render();
          },
          () => cancelled
        );
      } else {
        // Fallback: niente ritaglio (foto CORS o degradata) → tinta unita.
        const material = new MeshStandardMaterial({
          color: safeColor(texture?.colorHex),
          roughness: 0.95,
        });
        for (const part of parts) {
          const xs = part.mirror ? [-part.offsetX, part.offsetX] : [0];
          for (const dx of xs) {
            const mesh = new Mesh(lathe(part.profile), material);
            mesh.position.x = dx;
            figure.add(mesh);
          }
        }
      }
    }

    render();
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [config, outfit, textures]);
```

- [ ] **Step 4: Rimuovere gli import three.js diventati inutilizzati**

Dopo aver tolto `garmentMaterial`/`printDecal`, verificare quali simboli three.js non sono più usati e toglierli dall'import in testa. `RepeatWrapping` **resta** (serve al ribaltamento del pannello dietro). Controllare con:

Run: `npx eslint src/components/Avatar/Avatar3D.jsx`
Expected: nessun errore `no-unused-vars`. Se ne segnala, rimuovere quei nomi dall'import di `'three'`.

- [ ] **Step 5: Far girare la suite di test (regressione)**

Run: `npm test`
Expected: PASS — inclusi i test del Task 1; nessuna rottura altrove (i test di `garmentTexture`/`garmentMesh` non sono toccati).

- [ ] **Step 6: Verifica a schermo (obbligatoria — è qui che si vede il fix)**

```bash
npm run dev -- --host 127.0.0.1
```
Aprire `http://127.0.0.1:5173/`, andare all'avatar 3D e comporre un outfit con capi che hanno una foto. Controllare, ruotando la figura:

1. il capo appare come **un capo intero** sul busto/gambe (una maglietta che sembra una maglietta), **non** come strisce/pattern ripetuto;
2. le proporzioni del capo sono rispettate (non schiacciato/stirato);
3. ruotando c'è il **dietro** e il capo resta sul corpo, non solo una faccia;
4. un capo con **logo** mostra il logo al posto giusto (è dentro il ritaglio);
5. un capo con foto **non ritagliabile** (o senza foto) ricade sulla **tinta unita** senza errori in console.

Annotare l'esito. Se 1–5 sono ok, procedere; altrimenti aprire un ciclo di debug (systematic-debugging) prima di committare.

- [ ] **Step 7: Commit**

```bash
git add src/components/Avatar/Avatar3D.jsx
git commit -m "feat(avatar3d): capo reso come ritaglio su pannello, non più piastrella tilata"
```

---

## Self-Review (svolta)

- **Copertura spec:**
  - "capo diventa un pannello, non pattern" → Task 2, Step 3 (`addGarmentPanels`).
  - "usa `textureUrl` esistente" → Task 2, Step 3 (`texture.textureUrl`).
  - "pannello davanti + copia dietro, proporzioni rispettate" → Task 1 (`panelPlacement`) + Task 2 (`garmentPanel` front/back).
  - "via piastrella e decal" → Task 2, Step 2 (rimozione `garmentMaterial`/`printDecal`).
  - "fallback tinta unita" → Task 2, Step 3 (ramo `else`).
  - "zone per tipo dai `garmentParts`" → Task 2 usa `parts[0].profile`.
  - "pantaloni: pannello unico frontale che avvolge le gambe" → deciso: `mirror` in `panelPlacement` porta `radius = offsetX + baseRadius + gap`, pannello unico centrato (Task 1, test `mirror`).
  - "verifica a schermo" → Task 2, Step 6.
- **Placeholder scan:** nessun TBD/TODO; ogni step ha codice o comando concreto.
- **Coerenza tipi:** `panelPlacement` restituisce `{ yCenter, height, radius, arcAngle }` in Task 1 e viene consumato con quegli stessi nomi in `garmentPanel`/`addGarmentPanels` (Task 2). `garmentPanel(placement, thetaStart, map)` e `addGarmentPanels(figure, mainPart, url, onRender, isCancelled)` usati con le stesse firme in Step 3.
