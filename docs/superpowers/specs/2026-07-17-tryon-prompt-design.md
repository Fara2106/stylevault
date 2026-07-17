# Prova AI via prompt + rimozione avatar — Design

**Data:** 2026-07-17
**Stato:** approvato dall'utente (brainstorming completato)
**Branch:** `feat/tryon-prompt`

## 1. Visione

Due cambi coordinati sulla pagina **Prova**:

1. **Via Google AI Studio.** La scheda "Sulla tua foto (AI)" non chiama più Gemini
   con la chiave dell'utente. Diventa **"Prompt AI"**: l'app **genera il prompt
   ottimale** (modificabile) e le **istruzioni**, e Mary lo incolla in
   **Gemini/ChatGPT** — app che ha già gratis e che caricano foto — per ottenere
   l'immagine. Niente chiave, niente costi, niente proxy.
2. **Via l'avatar, del tutto.** Si rimuove l'intera feature avatar (scheda Prova,
   editor nel profilo, onboarding, codice 3D/mesh). La scheda **"Su di te"** (la
   persona vera) **resta** ed è l'unico try-on visivo dentro l'app.

Risultato: pagina Prova con **2 schede** — "Su di te" e "Prompt AI".

## 2. Decisioni chiave (dal brainstorming)

| Aspetto | Decisione |
|---|---|
| Chi scrive il prompt | **L'app** (template puro dai capi dell'outfit), gratis, offline, senza chiave |
| Prompt | In inglese (rende meglio coi modelli immagine), **modificabile** prima di copiare |
| AI esterna per il prompt | **No** (Grok è a pagamento; una chiave nel sito statico va nascosta in un proxy → rimette la chiave che si vuole togliere) |
| Immagine finale | La genera Mary in Gemini/ChatGPT (carica sua foto + immagini capi + prompt) |
| Avatar | **Rimosso interamente** (scelta utente 2026-07-17) |
| "Su di te" | **Mantenuto** — non condivide codice con l'avatar |
| three.js | Rimosso dal bundle (lo usava solo `Avatar3D`) |
| Costi | Zero |

## 3. Parte A — Scheda "Prompt AI"

### 3.1 Logica del prompt (`src/utils/tryOnPrompt.js`, puro, testato)

- `buildTryOnPrompt(items, { lang } = {})` → stringa.
- Riusa e **arricchisce** il testo già presente in `geminiTryon.buildTryOnRequest`:
  identità preservata (viso, capelli, corporatura, posa, sfondo), sostituzione dei
  **soli** vestiti, lista capi con **colore + categoria** (dai dati dell'outfit),
  inquadratura intera testa-piedi, luce naturale, "usa le immagini fornite",
  "restituisci solo la foto". Esempio dell'output nel §7.
- Puro (nessun DOM, nessuna rete): testato con più capi, un capo, zero capi,
  accessori, e presenza/assenza del colore.

### 3.2 UI (scheda "Prompt AI" in `TryOnPage.jsx`)

- **Textarea modificabile** pre-riempita col prompt + pulsante **"Copia prompt"**.
- **Istruzioni passo-passo** numerate: apri ChatGPT/Gemini → carica la tua foto →
  carica le foto dei capi → incolla il prompt → genera.
- Link **"Apri ChatGPT"** / **"Apri Gemini"**.
- **Accesso alle immagini dei capi** dell'outfit da caricare in chat: per ogni capo
  un modo per prenderla (scarica se locale/dataURL, apri in nuova scheda se remota).
- i18n IT/EN (le istruzioni nella lingua dell'app, il prompt in inglese).

### 3.3 Rimozioni (percorso Google AI Studio)

- `src/services/geminiTryon.js`: eliminato l'accesso rete (`generateTryOnPhoto`,
  `toInlinePart`, endpoint, storage chiave `getGeminiKey/setGeminiKey`,
  `sv_gemini_key`). Il solo pezzo utile (costruzione del prompt) migra in
  `tryOnPrompt.js`; il file sparisce (o resta il minimo indispensabile).
- `TryOnPage.jsx`: via l'uso di `getGeminiKey/generateTryOnPhoto`, i messaggi
  "serve la chiave", il link al profilo per la chiave.
- `ProfilePage.jsx`: via la sezione per impostare la chiave Gemini.
- `geminiTryon.test.js`: aggiornato/rimosso di conseguenza.

## 4. Parte B — Rimozione avatar

### 4.1 Da RIMUOVERE (file interi)

- Componenti: `Avatar3D.jsx`, `Avatar3DBoundary.jsx`, `AvatarSvg.jsx`,
  `AvatarEditor.jsx`, `OutfitOnAvatar.jsx`.
- Utils: `avatarOptions.js`, `avatarMesh.js`, `garmentMesh.js`, `garmentPanel.js`,
  `webgl.js` (verificare che non li usi "Su di te").
- Test: `avatarMesh.test.js`, `garmentMesh.test.js`, `garmentPanel.test.js`.
- Dipendenza `three` in `package.json` (solo `Avatar3D` la usa).

### 4.2 Da MANTENERE (li usa "Su di te", NON sono l'avatar)

- `ModelTryOn.jsx` e `Avatar.css` (rinominabili in seguito, non ora).
- Utils: `modelImage.js`, `modelComposer.js`, `modelWarp.js`, `tryonComposer.js`,
  `garmentImage.js`, `garmentTexture.js`, `garmentCutoutCache.js`,
  `personSilhouette.js`, `bodyAnalysis.js`, `backgroundRemoval.js` (+ i loro test).

### 4.3 Da RITOCCARE (consumatori)

- `ProfileContext.jsx`: via `avatarConfig` e l'import di `avatarOptions`; **resta
  `referencePhoto`**. `DEFAULT_PROFILE`/serializzazione aggiornati.
- `OnboardingPage.jsx`: via gli step di configurazione avatar; resta (se serve) il
  solo caricamento della foto di riferimento.
- `ProfilePage.jsx`: via la sezione editor avatar.
- `TryOnPage.jsx`: via l'import e la scheda `OutfitOnAvatar`; restano 2 schede.
- i18n: via le chiavi `avatar.*` non più usate.
- Cloud: la colonna `avatar_config` in `profiles` può restare inutilizzata (nessuna
  migrazione distruttiva necessaria); `fetchProfile/upsertProfile` smettono di
  leggerla/scriverla.

### 4.4 Vincolo di sicurezza

Dopo ogni rimozione: **`npm test` verde** e **`npm run build` ok**, e **"Su di te"
funziona a schermo**. Se qualcosa in §4.2 risultasse importato solo dall'avatar,
si sposta in §4.1; se qualcosa in §4.1 servisse a "Su di te", si sposta in §4.2.

## 5. Reconciliation con lo spec Armocromia

Lo spec `2026-07-17-armocromia-design.md` va aggiornato **prima di costruire
l'armocromia**: rimuovere il bonus "usa questi colori per l'avatar" e ogni
dipendenza da `avatarOptions` (che qui viene cancellato). L'armocromia usa i colori
rilevati direttamente e definisce da sé eventuali campioni di riferimento.

## 6. Ordine consigliato

Costruire **prima questa** (feat/tryon-prompt), farne il merge in `main`, poi
l'armocromia off `main` aggiornato. Motivo: entrambe toccano `ProfilePage`/
`OnboardingPage`; farle in serie evita conflitti e l'armocromia parte dal codice
già semplificato (niente avatar).

## 7. Esempio di prompt generato (outfit: camicia bianca + chino blu + sneakers)

```
Photorealistic virtual try-on.

Image 1 is a real person — preserve their exact face, hairstyle, skin tone,
body shape, height, pose and background with total fidelity. Do not change
their identity in any way.

Dress this same person in the garments shown in the next images:
1. White cotton button-up shirt (Image 2) — long sleeves.
2. Navy-blue chino trousers (Image 3) — straight fit, full length.
3. White low-top sneakers (Image 4).

Replace ONLY the person's current clothing with these garments. Fit each item
naturally with realistic folds, seams and shadows, matching the lighting and
perspective of Image 1. Full-body framing, head to feet, sharp focus, natural
light. Return only the final edited photograph, no text.
```

## 8. Test e verifica

- **Puro, TDD:** `tryOnPrompt` (lista capi, colori, EN, casi limite).
- **Rimozione:** `npm test` verde e `npm run build` ok a ogni passo; "Su di te"
  provata a schermo (`docs/verifiche/2026-07-17-prova-prompt/`).
- Non si introduce nessun accesso di rete nuovo.

## 9. Fuori scope

- Chiamare qualsiasi API immagine dall'app (Gemini, Raphael, Cloudflare…).
- Prompt scritto da un'AI esterna (rimette la chiave da togliere).
- Rinominare i file `ModelTryOn`/`Avatar.css` (cosmetico, in un secondo momento).
