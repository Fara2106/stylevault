# MEMORIA.md — Stato del progetto StyleVault

> File di ripartenza: se apri una nuova chat, leggi questo file per riprendere il lavoro
> esattamente da dove eravamo. Va aggiornato a ogni avanzamento significativo.

## Situazione attuale (2026-07-08)

**L'app è completa (Fase A + Fase B lato codice) e ONLINE come demo.**

- **App live:** https://fara2106.github.io/stylevault/ — condivisa con Mary,
  **siamo in attesa del suo feedback** (in particolare su: avatar, consigli,
  nome dell'app — "StyleVault" è un nome di lavoro).
- **Repository:** https://github.com/Fara2106/stylevault (account GitHub: Fara2106,
  repo pubblico — serve per GitHub Pages gratuito). Ogni push su `main` fa
  test + build e ripubblica da solo (`.github/workflows/deploy.yml`, base `/stylevault/`).
- La demo gira in **modalità locale**: capi di esempio precaricati, ogni visitatore
  ha i propri dati nel proprio browser, login simulato senza email di conferma.

**Novità 2026-07-08 (sera) — try-on fotografico con Google Gemini:**
- Nuova sezione "Prova con la tua foto" nella pagina Prova sull'Avatar: l'AI
  di Google (`gemini-2.5-flash-image`, "Nano Banana") veste una foto reale
  dell'utente con i capi scelti. Scelta di Lorenzo: niente backend — la
  chiave API la fornisce l'utente e resta SOLO nel browser (localStorage
  `sv_gemini_key`); chiamata diretta browser→Google, il sito resta statico.
- Chiave: sezione "Try-on fotografico (AI)" nel Profilo, con istruzioni e
  link a aistudio.google.com/apikey (gratuita, ~500 immagini/giorno; sul
  tier gratuito Google può usare i contenuti per migliorare i prodotti).
- La foto della persona è la `referencePhoto` del profilo (riusata: è la
  stessa dell'editor avatar); upload con resize a 1024px.
- Logica in `src/services/geminiTryon.js` (+5 test: parsing dataURL,
  costruzione richiesta, estrazione immagine); errori tipizzati con
  messaggi i18n (chiave non valida, quota, rete, capi non leggibili —
  le foto remote che bloccano CORS vengono escluse e segnalate).
- **NON ancora provato con una chiave vera** (verificato con API simulata
  nel browser: flusso completo ok, 0 errori console): alla prima prova
  reale di Lorenzo controllare eventuali errori di modello/endpoint.

**Novità 2026-07-08 (sera) — l'avatar ora è davvero vestito (fix bug):**
- Bug segnalato da Lorenzo: scegliendo un capo, la foto compariva solo come card
  *accanto* all'avatar ("avvicina l'abito ma non lo veste"). Causa: nessun layer
  veniva disegnato sul corpo — le card polaroid erano l'unica resa.
- Ora `AvatarSvg` accetta `outfit` e disegna sagome di indumenti (top, abito,
  pantaloni, scarpe, capospalla aperto) sopra la silhouette, riempite con la
  foto reale del capo via `clipPath`+`image`; scalano con la corporatura.
- Ordine di pittura in `garmentLayers()` (tryonComposer, +5 test): bottom →
  top/abito → capospalla → scarpe; accessori restano come card (nessuna sagoma).
- Le card intorno alla figura restano come controlli (＋/✕), ridimensionate.
- Verificato: 53 unit test, build, smoke browser (top/outfit completo/abito
  con esclusione bottom, salvataggio outfit, 0 errori console, screenshot).

**Novità 2026-07-08 — vestizione manuale dell'avatar:**
- La pagina "Prova sull'Avatar" ora funziona anche da sola: gli slot
  (capospalla, top/abito, bottom, scarpe, accessori) sono cliccabili e aprono
  il guardaroba filtrato per categoria; ✕ per togliere un capo; "Salva outfit".
- Entry point: bottone "Prova sull'avatar" nel dettaglio capo (precompila lo
  slot giusto) e visita diretta a /tryon; i flussi esistenti (Outfit/Calendario
  → Prova) restano e ora sono editabili.
- Logica in `src/utils/tryonComposer.js` (+10 unit test): abito e bottom si
  escludono a vicenda, accessori multipli (max 3, toggle).
- Nel picker del calendario gli outfit senza punteggio (composti a mano) sono
  etichettati "Outfit personalizzato".
- **Bugfix**: in modalità locale il refresh di una pagina protetta rimbalzava
  sull'onboarding (profilo caricato in un effect, troppo tardi per Protected);
  ora ProfileContext carica il profilo locale in modo sincrono durante il
  render al cambio di userId.

**Prossimi passi previsti:**
1. Raccogliere il feedback di Mary/Lorenzo e ritoccare la UI.
2. Attivare il cloud: Lorenzo crea il progetto su supabase.com, esegue
   `supabase/migrations/001_init.sql` nel SQL Editor, mette le chiavi in
   `.env.local` (guida completa: `docs/SETUP-CLOUD.md`). Facoltativi: provider
   Google, deploy Edge Function, hosting Vercel con env vars.
3. **Il percorso cloud NON è mai stato provato live** (mancano le chiavi):
   alla prima attivazione fare un giro di verifica completo.

## Cos'è

**StyleVault** — app web guardaroba digitale (cartella "Web AP x MaryP"):
- registra capi via **foto + form manuale** o **link a shop online** (estrazione
  automatica immagine/titolo via metadati, fallback manuale);
- genera **3 outfit dal meteo reale** della città cercata (Open-Meteo, ricerca
  manuale città, niente GPS) per il giorno scelto (oggi–7gg) e l'occasione,
  con blocco capi e rigenerazione parziale;
- **avatar SVG 2D** stilizzato configurato a mano (corporatura, carnagione, capelli)
  con foto di riferimento; prova outfit "a collage" sugli slot dell'avatar;
- wishlist, calendario outfit (pianificato/indossato, avviso ripetizione), statistiche;
- **consigli rule-based** (armonia colori, meteo, ripetizioni) — niente AI in v1;
- stile **lusso "light editorial"**: crema `#FAF7F2`, inchiostro `#1A1A1A`, accento
  terra `#8B7355`, Playfair Display + Inter, bordi sottili, maiuscoletto spaziato,
  icone stroke (niente emoji).

## Decisioni chiave (approvate dall'utente)

- Prodotto **pubblico multi-utente**. Fase A (solo UI, localStorage) ✅ e Fase B
  (Supabase) ✅ lato codice, senza riscrivere le pagine tra le due.
- Lorenzo (parla italiano, attento ai costi) ha dato **piena autonomia**: niente
  domande di conferma, si procede fino al risultato finito e poi lo prova.
- Spec completa: `docs/superpowers/specs/2026-07-07-stylevault-design.md`
- Piano Fase A: `docs/superpowers/plans/2026-07-07-fase-a-ui.md`

## Architettura (dual-mode)

- React 19 + Vite (JSX, **non** TS), react-router-dom 7, i18next (it/en), Vitest.
- Entry: `index.html` → `src/main.jsx` (provider: Auth → Settings → Profile → Wardrobe;
  `BrowserRouter basename={import.meta.env.BASE_URL}` per GitHub Pages).
- **Selettore di modalità**: `src/services/supabaseClient.js` — con
  `VITE_SUPABASE_URL` + `VITE_SUPABASE_ANON_KEY` in `.env.local` si attiva il
  cloud, senza si resta in locale (localStorage, auth mock, capi demo).
- **Cloud (Fase B):**
  - `supabase/migrations/001_init.sql`: profiles, items, wishlist_items, outfits,
    calendar_entries con RLS; bucket privati wardrobe-photos/profile-photos con
    policy per-utente; trigger profilo automatico alla registrazione.
  - `supabase/functions/fetch-link-metadata/`: Edge Function link shop
    (il client la usa con fallback automatico su microlink.io).
  - `src/services/db.js`: mappers app↔DB, CRUD, upload foto, URL firmate 6gg.
  - AuthContext: email+password, Google OAuth, `needsConfirmation`; LoginPage
    mostra "Continua con Google" solo in cloud.
  - ProfileContext: avatar/foto riferimento/onboarded/lingua/città su `profiles`;
    `profileLoading` evita il rimbalzo verso l'onboarding (Protected lo aspetta).
  - WardrobeContext: load iniziale dal cloud + cache offline `sv_cloud_cache_<uid>`,
    scritture ottimistiche write-through (fallimento → console.warn, dati locali).
- `src/services/weather.js`: Open-Meteo geocoding + forecast 7gg + cache offline.
- Design system: `src/styles/tokens.css` + `global.css`; icone in
  `src/components/common/Icon.jsx`.
- BottomNav (mobile): Guardaroba, Outfit, Aggiungi(+), Calendario, Profilo.
  Wishlist = tab dentro Guardaroba. Desktop: nav nell'header editoriale.
- Deploy alternativo pronto: `vercel.json` (serve per la versione cloud, dove
  vanno impostate le env vars — GitHub Pages non le gestisce).

## Verifiche fatte

- **58 unit test Vitest** (motore outfit incluse estensioni, meteo, statistiche,
  link metadata, armonia colori, composizione tryon) — tutti verdi.
- **Smoke test browser** (playwright-core + Chrome installato, `channel: 'chrome'`):
  registrazione → onboarding → guardaroba → dettaglio → outfit con meteo reale →
  prova avatar → indossa → calendario → profilo → desktop. 0 errori console.
  Rifatto dopo il refactor Fase B e ripetuto sul **sito live** dopo il deploy.
  (Lo script era nello scratchpad di sessione: se serve, va ricreato.)

## Comandi

- `npm run dev` — sviluppo su http://localhost:5173
- `npm test` — test Vitest
- `npm run build` — build produzione
- `git push` — pubblica anche online (workflow Pages automatico)

## Note tecniche da ricordare

- `generateOutfits(items, weather, occasion, count, {lockedItems, recentWear,
  referenceDate})`; il servizio meteo produce giorni compatibili
  (temperature = media delle percepite del giorno).
- Foto: dataURL ridimensionati a max 600px (`utils/imageUtils.js`) — quota
  localStorage ~5MB in locale; in cloud si caricano su Storage.
- i18n: consigli in `advice.*`, meteo come `descriptionKey` da tradurre nel
  componente; file JSON riformattati multi-riga.
- In modalità locale i SAMPLE_ITEMS sono sempre precaricati (locale = demo);
  in cloud si parte dal guardaroba vuoto.
- Git: commit in italiano; remote `origin` → github.com/Fara2106/stylevault.
