# MEMORIA.md — Stato del progetto StyleVault

> File di ripartenza: se apri una nuova chat, leggi questo file per riprendere il lavoro
> esattamente da dove eravamo. Va aggiornato a ogni avanzamento significativo.

## Situazione attuale (2026-07-09)

**L'app è ONLINE in MODALITÀ CLOUD: account veri, dati e foto su Supabase.**

- **Feedback di Mary (2026-07-09): positivo** — "va bene", continuerà a provarla.
  Il nome resta "StyleVault" finché non se ne sceglie uno definitivo.
- **App live:** https://fara2106.github.io/stylevault/ — dal 2026-07-09 il sito
  pubblico è la versione cloud (registrazione vera; niente più capi demo).
  Chi aveva dati nella vecchia demo locale li ha ancora nel proprio browser,
  ma nel cloud si riparte da zero: Mary deve registrarsi.

**Novità 2026-07-09 — cloud Supabase attivato e verificato (prima volta live):**
- Progetto Supabase dell'account `lorefara97@gmail.com` (creato in automatico
  alla registrazione, piano Free, database in Irlanda):
  dashboard https://supabase.com/dashboard/project/frukvktbmxndyzgivwxq
- Migrazione `001_init.sql` eseguita nel SQL Editor e verificata: 5 tabelle,
  5 policy RLS pubbliche + 3 storage, 2 bucket foto, trigger profilo. ✔
- Chiavi nel formato nuovo (`sb_publishable_…`, sostituisce la anon key JWT;
  è pubblica per design, la sicurezza la fanno le policy RLS): in locale in
  `.env.local` (gitignorato), per il deploy come **GitHub Secrets**
  (`VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`) iniettate nel build dal
  workflow Pages — niente Vercel, stesso link di prima (scelta di Lorenzo:
  "tutte le prove su GitHub, migrazione altrove più avanti, forse").
- Config auth: **"Confirm email" DISATTIVATA** (scelta di Lorenzo: il free
  tier manda 2-4 email/ora, le conferme rischiano di non arrivare; si può
  riattivare in Authentication → Sign In / Providers). Site URL =
  https://fara2106.github.io/stylevault/ + redirect `…/stylevault/**` e
  `http://localhost:5173/**` (Authentication → URL Configuration).
- **Verifica end-to-end su localhost (tutta in modalità cloud)**: registrazione
  (utente test `lorefara97+svtest1@gmail.com`, pw `StyleVault.Test.2026` —
  eliminabile dalla dashboard), onboarding, capo aggiunto con foto → upload
  su Storage + URL firmata visibile, reload con sessione persistente, logout,
  login. Lingua e città sincronizzate sul profilo cloud. 0 errori console.
- **Bug trovato e corretto** (`ProfileContext.jsx`): al refresh di una pagina
  protetta in cloud si rimbalzava sull'onboarding anche con `onboarded=true`
  nel DB. Causa: `profileLoading` era uno stato acceso da un effect — nel
  render in cui la sessione ricompare l'effect non è ancora partito, il flag
  era `false` e Protected leggeva l'`onboarded=false` di default. Fix:
  `profileLoading` è ora **derivato** (`loadedUserId !== userId`), vero dal
  primo render con utente nuovo. (Il gemello locale era già stato fixato
  con il caricamento sincrono; questo era il gemello cloud.)
- Nota: le foto dallo Storage possono arrivare con qualche secondo di ritardo
  la prima volta (quel giorno Supabase segnalava anche un incident); non è
  un bug dell'app.

**Novità 2026-07-09 (bis) — protezioni contro la pausa del piano Free:**
- **Keep-alive**: `.github/workflows/keepalive.yml` fa una query minima al
  database lunedì e giovedì (cron): il progetto non resta mai 7 giorni senza
  attività. Se il ping fallisce **GitHub manda una email a Lorenzo** — quello
  è il segnale di andare a riattivare/controllare il progetto in dashboard.
  (Occhio: GitHub disattiva i cron dei repo fermi da 60 giorni, con preavviso
  via email; si riattivano da Actions o con un push.)
- **Messaggi comprensibili quando il cloud non risponde** (scelta di Lorenzo:
  "mettere l'utente a conoscenza, dire di contattarmi"):
  - login/registrazione: gli errori di rete diventano il marker
    `service-unreachable` (AuthContext) e la LoginPage mostra
    `auth.serviceUnreachable` ("…va in pausa… avvisa Lorenzo… i dati sono
    al sicuro") invece di "Failed to fetch";
  - guardaroba: `WardrobeContext` espone `cloudOffline` (true se il load
    iniziale fallisce) e `StatusNotice` mostra il banner `app.cloudPausedNotice`;
    i capi restano visibili dalla cache offline `sv_cloud_cache_<uid>`;
  - modalità locale/demo: `StatusNotice` mostra un avviso chiudibile
    (`app.localNotice`): dati solo nel browser, Safari li cancella dopo ~7
    giorni di inutilizzo (flag di chiusura in
    `localStorage['sv_local_notice_dismissed']`).
  - Nessuna notifica push a Mary: impossibile su sito statico senza server
    push; la copertura è ping + email di GitHub a Lorenzo + messaggi in-app.
- Verificato in browser tutti e tre gli scenari (URL finto irraggiungibile per
  il login; throw temporaneo in `fetchAllData` per il banner; env vuote per la
  modalità locale). 58 test verdi.
- **Repository:** https://github.com/Fara2106/stylevault (account GitHub: Fara2106,
  repo pubblico — serve per GitHub Pages gratuito). Ogni push su `main` fa
  test + build e ripubblica da solo (`.github/workflows/deploy.yml`, base `/stylevault/`).
- La demo gira in **modalità locale**: capi di esempio precaricati, ogni visitatore
  ha i propri dati nel proprio browser, login simulato senza email di conferma.

**Novità 2026-07-08 (sera) — try-on fotografico con Google Gemini:**
- La pagina Prova sull'Avatar ha ora **due schede** (scelta di Lorenzo):
  "Sull'avatar" (default, gratis: capi nelle sagome SVG — pantaloni su gambe
  ecc.) e "Sulla tua foto (AI)" con Gemini; l'outfit si compone nella scheda
  avatar, la scheda foto avvisa se è vuoto.
- Foto AI: l'AI di Google (`gemini-2.5-flash-image`, "Nano Banana") veste una
  foto reale dell'utente con i capi scelti. Niente backend — la chiave API la
  fornisce l'utente e resta SOLO nel browser (localStorage `sv_gemini_key`);
  chiamata diretta browser→Google, il sito resta statico.
- Chiave: sezione "Try-on fotografico (AI)" nel Profilo, con istruzioni
  passo-passo (pensate per chi non ha mai creato una chiave API) e link a
  aistudio.google.com/apikey.
- La foto della persona è la `referencePhoto` del profilo (riusata: è la
  stessa dell'editor avatar); upload con resize a 1024px.
- Logica in `src/services/geminiTryon.js` (+5 test: parsing dataURL,
  costruzione richiesta, estrazione immagine); errori tipizzati con
  messaggi i18n (chiave non valida, quota, rete, capi non leggibili —
  le foto remote che bloccano CORS vengono escluse e segnalate).
- **Provato con la chiave vera di Lorenzo (2026-07-08 sera)**: chiave valida
  (i modelli testo rispondono 200), `gemini-2.5-flash-image` esiste, MA tutti
  i modelli immagine danno **429 con "limit: 0"**: il piano gratuito della
  Gemini API oggi NON include la generazione di immagini (l'informazione
  "~500 immagini/giorno gratis" era datata). Niente alternative gratuite:
  anche OpenRouter non ha modelli immagine `:free`. Per usare la funzione va
  attivata la fatturazione dell'account Google ("Set up billing" in AI
  Studio, ~$0.04/foto). Testi in-app aggiornati per non promettere il
  gratis; il 429 ora mostra un messaggio che spiega la fatturazione.
  La chiamata end-to-end con 200 non è quindi ancora stata vista: al primo
  uso con fatturazione attiva verificare che la risposta contenga l'immagine.

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

**Stato al 2026-07-09 sera: IN ATTESA del feedback di Mary sulla versione
cloud.** Decisione esplicita di Lorenzo: nessun altro sviluppo finché Mary
non l'ha provata — sarà l'uso reale a dire cosa serve.

**Prossimi passi (congelati fino al feedback):**
1. Lorenzo dice a Mary di **registrarsi sul sito** (il vecchio profilo demo
   resta nel suo browser, non migra).
2. **Bottone "Continua con Google" sul sito live: È UN PROBLEMA APERTO** —
   il bottone compare (modalità cloud) ma il provider Google su Supabase NON
   è attivato: cliccarlo dà errore. Lorenzo deve scegliere: attivare il
   provider (credenziali OAuth su Google Cloud Console, ~15 min, gratuito)
   oppure nascondere il bottone finché non è attivo. Da risolvere alla
   prossima sessione.
3. Facoltativi rimasti: Edge Function `fetch-link-metadata` (oggi fallback
   microlink.io, 50 req/giorno), fatturazione Google per il try-on AI
   (integrazione pronta, mai vista una chiamata 200: verificarla al primo
   uso), eliminare l'utente di test `lorefara97+svtest1@gmail.com` dalla
   dashboard (o tenerlo per prove), nome definitivo dell'app.
4. La pausa del piano Free è già coperta (keep-alive + messaggi in-app,
   vedi sopra): non serve fare nulla.

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
