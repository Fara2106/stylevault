# Armocromia — Design

**Data:** 2026-07-17
**Stato:** approvato dall'utente (brainstorming completato)
**Branch di partenza:** `feat/scontorno-imgly`

## 1. Visione

Da una foto della persona, StyleVault legge i colori reali di **pelle del viso,
capelli e occhi**, determina la **sotto-stagione armocromatica** (sistema a 12
toni) e propone:

1. la **palette personale** (colori migliori, pochi da evitare, metallo oro/argento);
2. **outfit** a tema stagione, ognuno con **link di ricerca veri agli shop** (capi
   nuovi) **e** l'evidenza dei **capi del guardaroba** già in palette;
3. **make-up** per stagione (rossetto/blush/ombretto/fondotinta) con link agli shop.

Tutto **on-device e gratuito**: nessuna AI a pagamento, nessuna immagine generata,
la foto non lascia il dispositivo (stessa filosofia di `bodyAnalysis.js` e @imgly).

## 2. Decisioni chiave (dal brainstorming)

| Aspetto | Decisione |
|---|---|
| Analisi colori | On-device, MediaPipe (riuso infrastruttura `bodyAnalysis.js`) |
| Occhi | Inclusi (FaceLandmarker, landmark iride) |
| Profondità | 12 sotto-stagioni (sistema sci-art a 12 toni) |
| Rete di sicurezza | Colori rilevati mostrati e **correggibili con un tap** prima del calcolo |
| Outfit | Link di ricerca agli shop **+** match coi capi del guardaroba |
| Make-up | Famiglie di tinte per stagione con link agli shop |
| Link shop | URL di ricerca (query = categoria + colore, IT/EN) — robusti, gratis, niente API |
| Immagini generate | **Fuori scope** (decisione rimandata; possibile estensione futura gratis via Cloudflare) |
| Dove vive | Pagina nuova `/armocromia`, ingresso da una card nel Profilo (bottom-nav invariata) |
| Persistenza | Esito salvato nel profilo (locale + Supabase), non si rianalizza a ogni apertura |
| Lingue | Italiano e inglese (i18next) |
| Costi | Zero |

## 3. Architettura

Netta separazione tra **estrazione** (MediaPipe, non testabile in jsdom — sottile),
**logica pura** (classificatore, dati stagioni, link, match guardaroba — tutta
testata TDD) e **UI**.

```
foto ──▶ faceColorAnalysis.js ──▶ {skin,hair,eyes hex}
             (MediaPipe)                   │
                                           │ (correzione manuale opzionale)
                                           ▼
                                 armocromiaClassifier.js ──▶ {season, axes, confidence}
                                           │
             ┌─────────────────────────────┼──────────────────────────────┐
             ▼                              ▼                              ▼
     armocromiaSeasons.js           shopLinks.js               armocromiaWardrobe.js
     (palette, make-up,        (URL ricerca shop per       (capi del guardaroba
      metallo, descrizioni)     categoria+colore)            in palette, per deltaE)
             └─────────────────────────────┬──────────────────────────────┘
                                           ▼
                                    ArmocromiaPage (UI)
```

### 3.1 Unità e responsabilità

**`src/utils/colorSampling.js` (puro, testato)**
- `representativeColor(pixels)` — dato un elenco di pixel RGB, ritorna il colore
  rappresentativo di una regione: converte in Lab, scarta gli estremi (luci/ombre,
  es. 15% più chiaro e più scuro per L), ritorna la **mediana** → hex robusto.
- `rgbToLab` / `labToRgb` / `deltaE` (CIE76 sufficiente) — conversioni percettive.
  Se in `colorHarmony.js` mancano, vivono qui e restano l'unico posto per Lab.
- Nessuna dipendenza dal DOM.

**`src/utils/faceColorAnalysis.js` (sottile, MediaPipe, degrada a null)**
- `analyzeFaceColors(photoUrl)` → `{ skin, hair, eyes, confidence } | null`.
- Riusa il segmentatore selfie-multiclass di `bodyAnalysis.js`
  (`segmentBody` → maschera categorie): disegna la foto su canvas alla risoluzione
  della maschera, raccoglie i pixel `SEG_FACE_SKIN` e `SEG_HAIR`, li passa a
  `representativeColor`.
- Occhi: `FaceLandmarker` (stesso pacchetto `@mediapipe/tasks-vision`, modello con
  landmark iride) → centro iride in pixel → campiona un piccolo disco escludendo
  pupilla (troppo scura) e catchlight (troppo chiaro) → `representativeColor`.
- Import dinamico (fuori dal bundle iniziale). Ogni fallimento ⇒ campo `null` e
  `confidence` più bassa; se cade tutto ritorna `null` e la UI parte dalla
  correzione manuale.
- La `confidence` combina: area/consistenza delle regioni segmentate e quanto gli
  assi si separano (vedi classificatore). Bassa ⇒ la UI invita a correggere i colori.

**`src/utils/armocromiaClassifier.js` (puro, testato — cuore)**
- `classifySeason({ skin, hair, eyes })` → `{ season, axes, confidence }`.
- Converte i 3 colori in Lab e calcola **tre assi**:
  - **Valore** (chiaro↔scuro): L pesata, capelli con peso maggiore (guidano il valore),
    pelle medio, occhi leggero.
  - **Sottotono** (caldo↔freddo): direzione/tinta prevalente (b positivo/giallo = caldo;
    spinta rosa/blu = freddo), combinando pelle + capelli (bruni caldi/rossi vs cenere)
    + occhi. Produce un punteggio con segno.
  - **Croma** (brillante↔soffuso): colorfulness Lab (√(a²+b²)) di occhi/pelle **più**
    il **contrasto** capelli↔pelle (alto contrasto ⇒ brillante/clear; basso ⇒ soffuso/muted).
- Mappa su una delle **12 sotto-stagioni** decidendo prima caldo/freddo, poi la
  caratteristica secondaria dominante (chiaro / scuro / brillante / soffuso), con
  spareggio sul valore per le stagioni "true":

  | | Caldo | Freddo |
  |---|---|---|
  | Chiaro | Light Spring | Light Summer |
  | Scuro | Deep Autumn | Deep Winter |
  | Brillante | Bright Spring | Bright Winter |
  | Soffuso | Soft Autumn | Soft Summer |
  | Bilanciato | True Spring / True Autumn* | True Summer / True Winter* |

  *spareggio: più chiaro ⇒ Spring/Summer, più scuro ⇒ Autumn/Winter.
- Soglie e pesi si tarano in TDD contro fixture di terne rappresentative (una per stagione).

**`src/utils/armocromiaSeasons.js` (dati puri, testato per integrità)**
- Le **12 stagioni**: `{ id, nameKey, descKey, palette:[{hex,nameKey}], avoid:[{hex,nameKey}],
  neutrals:[...], metal:'gold'|'silver'|'both', makeup:{ lips:[...], blush:[...],
  eyes:[...], foundationUndertone } }`.
- Dati curati (canone armocromia). Il nome colore serve anche a costruire la query shop.
- Test di integrità: le 12 esistono, ogni palette non vuota, ogni hex valido, ogni
  chiave i18n presente in IT ed EN.

**`src/utils/shopLinks.js` (puro, testato)**
- `buildShopLinks({ category, colorName, lang })` → `[{ shop, label, url }]`.
- Template per un set curato di shop, con varianti per lingua:
  - abbigliamento: Zalando, Asos, Amazon;
  - make-up: Sephora, Douglas, Amazon.
- Query testuale = colore + categoria localizzati (es. `maglione bordeaux`); URL di
  **ricerca** (non deep-link a filtri fragili) → stabili nel tempo. Encoding corretto.

**`src/utils/armocromiaWardrobe.js` (puro, testato)**
- `matchWardrobe(items, season)` → capi in palette, dal più vicino.
- Per ogni capo usa i suoi `colors` (id → hex da `CLOTHING_COLORS`), calcola il `deltaE`
  minimo verso la palette della stagione; "in palette" se sotto soglia. Ordina per distanza.

**`src/pages/ArmocromiaPage/ArmocromiaPage.jsx` (UI)**
- Flusso:
  1. Nessuna foto ⇒ invito a caricarla/scattarla (riuso l'uploader della foto di
     riferimento del profilo; hint "luce naturale, senza filtri/trucco pesante").
  2. Analisi ⇒ spinner "analizzo i tuoi colori" (pattern download MediaPipe dell'avatar).
  3. **Colori trovati** (campioni pelle/capelli/occhi) **correggibili con un tap**.
  4. **Verdetto stagione** + descrizione + confidenza.
  5. **Palette** (campioni) + pochi da evitare + metallo.
  6. **Outfit per te**: combo di colori dalla palette, ognuna con link shop per
     categoria **e** i tuoi capi in palette.
  7. **Make-up per te**: famiglie di tinte con link shop.
  8. Bonus opzionale: "usa questi colori per l'avatar" (auto-compila carnagione/capelli).
- Ingresso: card "I tuoi colori / Armocromia" nel Profilo. Route `/armocromia` dentro il layout protetto.

### 3.2 Persistenza

Nel profilo si aggiunge:
```js
armocromia: {
  season: 'bright-winter',
  detected: { skin: '#...', hair: '#...', eyes: '#...' },
  axes: { warmCool: number, lightDeep: number, brightSoft: number },
  confidence: number,
  updatedAt: '2026-07-17T...Z',
} // oppure null
```
- **Locale:** parte del blob profilo in `localStorage` (nessun lavoro extra).
- **Cloud:** nuova colonna `armocromia jsonb` in `profiles` (migrazione
  `supabase/migrations/002_armocromia.sql`); `fetchProfile`/`upsertProfile`
  la leggono/scrivono come già fanno per `avatar_config`.

## 4. Onestà sui limiti

- L'armocromia da foto dipende molto da **luce e filtri**: hint esplicito e
  **correzione manuale** dei colori come valvola di sicurezza.
- Non è un responso da armocromista professionista, ma una guida seria e coerente.
- I link agli shop sono **ricerche** per categoria+colore: portano a risultati
  pertinenti, non a un singolo prodotto garantito in stock.
- Occhi: l'iride è piccola; se il landmarker non è affidabile, il campo resta
  `null` e la stagione si calcola su pelle+capelli (l'utente può inserirlo a mano).

## 5. Test

- **Puri, TDD (rossi prima):** `colorSampling` (pixel→colore, scarto estremi, deltaE),
  `armocromiaClassifier` (una terna di fixture per ciascuna delle 12 stagioni + casi
  di confine caldo/freddo e bilanciato), `armocromiaSeasons` (integrità dati + i18n),
  `shopLinks` (URL/encoding/lingua), `armocromiaWardrobe` (in/out palette, ordinamento).
- **Non testabile in jsdom** (come three.js/MediaPipe nel resto): `faceColorAnalysis`
  resta sottile; la matematica del colore vive nelle funzioni pure testate.
- Verifica end-to-end a schermo su foto vere (come per "Su di te"), salvata in
  `docs/verifiche/2026-07-17-armocromia/`.

## 6. Fuori scope (v1)

- Immagini d'ispirazione generate (rimandato; eventualmente gratis via Cloudflare
  Workers AI, text-to-image — vedi nota).
- Deep-link a filtri colore specifici dei singoli shop (fragili) — si usano ricerche.
- Sotto-stagioni oltre le 12; drappeggi virtuali; analisi del contrasto occhi/sopracciglia.

## 7. Nota — immagini generate (decisione rimandata)

Valutati e per ora scartati per l'integrazione automatica: i servizi gratis
(Raphael, Cloudflare Workers AI / SDXL) sono **text-to-image** — inventano una
persona, non fanno try-on del viso/capi reali. Il try-on vero (image-to-image)
resta a pagamento (vedi decisione 2026-07-16 in MEMORIA.md). Se in futuro si
vorranno figurini **decorativi** (non la persona reale) accanto alle combo,
Cloudflare Workers AI è la via gratis e legittima. Non blocca questa feature.
