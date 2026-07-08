# MEMORIA.md — Stato del progetto StyleVault

> File di ripartenza: se apri una nuova chat, leggi questo file per riprendere il lavoro
> esattamente da dove eravamo. Va aggiornato a ogni avanzamento significativo.

## Cos'è

**StyleVault** — app web guardaroba digitale (cartella "Web AP x MaryP"):
- registra capi via **foto + form manuale** o **link a shop online** (estrazione automatica
  immagine/titolo via metadati, fallback manuale);
- genera **3 outfit dal meteo reale** della città cercata (Open-Meteo, ricerca manuale città,
  niente GPS) per il giorno scelto (oggi–7gg) e l'occasione;
- **avatar SVG 2D** stilizzato configurato a mano (corporatura, carnagione, capelli) con
  foto di riferimento privata; prova outfit "a collage" sugli slot dell'avatar;
- wishlist, calendario outfit (pianificato/indossato, avviso ripetizione), statistiche;
- **consigli rule-based** (armonia colori, meteo, ripetizioni) — niente AI in v1;
- stile **lusso "light editorial"**: crema `#FAF7F2`, inchiostro `#1A1A1A`, accento terra
  `#8B7355`, Playfair Display + Inter, bordi sottili, maiuscoletto spaziato.

## Decisioni chiave (approvate dall'utente)

- Prodotto **pubblico multi-utente** come obiettivo; **Fase A = solo UI** con localStorage
  (in corso), **Fase B = Supabase** (auth email+Google, Postgres+RLS, Storage, Edge Function
  link) senza riscrivere le pagine.
- L'utente (Lorenzo, parla italiano) ha dato **piena autonomia**: niente domande di
  conferma, si procede fino al risultato finito e poi lo prova.
- Spec completa: `docs/superpowers/specs/2026-07-07-stylevault-design.md`
- Piano Fase A: `docs/superpowers/plans/2026-07-07-fase-a-ui.md`

## Architettura Fase A

- React 19 + Vite (JSX, **non** TS), react-router-dom 7, i18next (it/en), Vitest.
- Entry: `index.html` → `src/main.jsx` (provider: Auth → Settings → Profile → Wardrobe).
- Persistenza: localStorage nei context (`sv_*` keys). Auth è **mock** (Fase B: Supabase).
- `src/services/weather.js`: Open-Meteo geocoding + forecast 7gg + cache offline.
- Design system: `src/styles/tokens.css` + `global.css`; icone stroke in
  `src/components/common/Icon.jsx` (niente emoji).
- BottomNav (mobile): Guardaroba, Outfit, Aggiungi(+), Calendario, Profilo.
  Wishlist = tab dentro Guardaroba. Desktop: nav nell'header.

## Stato avanzamento (aggiornato 2026-07-08)

**FASE A COMPLETATA.** Tutto fatto, committato e verificato:
- [x] T1 Bootstrap React (template Vite rimosso, provider, build ok)
- [x] T2 Design system + restyle componenti + fix bug LanguageSwitch + icone SVG
- [x] T3 i18n esteso it/en
- [x] T4 `services/weather.js` Open-Meteo (geocoding, forecast, cache offline)
- [x] T5 Motore outfit: lock capi, penalità ripetizione 7gg, stagione dal giorno
      scelto + `utils/outfitAdvice.js` (consigli rule-based, chiavi i18n)
- [x] T6 `utils/imageUtils.js` + `services/linkMetadata.js` (microlink + fallback)
- [x] T7 Avatar SVG parametrico + editor con foto riferimento + prova a collage
- [x] T8 Shell: router protetto, AppLayout (header desktop/BottomNav mobile),
      CitySearch, ScrollToTop
- [x] T9 Tutte le 9 pagine (Login, Onboarding 2 step, Wardrobe+tab wishlist,
      ItemDetail, AddItem foto+link, Outfit, TryOn, Calendar, Profile+statistiche)
- [x] T10 SAMPLE_ITEMS solo in dev, favicon SV, README, **38 unit test verdi**,
      smoke test browser completo (Playwright su Chrome, 10 screenshot, 0 errori
      console): registrazione → onboarding → guardaroba → dettaglio → outfit con
      meteo reale Firenze → prova avatar → indossa → calendario → profilo → desktop

**FASE B COMPLETATA lato codice (2026-07-08).** Integrazione Supabase dual-mode:
- `src/services/supabaseClient.js`: client attivo solo con `VITE_SUPABASE_URL` +
  `VITE_SUPABASE_ANON_KEY` in `.env.local`; senza chiavi l'app resta in modalità
  locale Fase A (verificata di nuovo con smoke test browser, 0 errori).
- `supabase/migrations/001_init.sql`: tabelle (profiles, items, wishlist_items,
  outfits, calendar_entries) con RLS, bucket privati wardrobe-photos/profile-photos
  con policy per-utente, trigger profilo automatico alla registrazione.
- `supabase/functions/fetch-link-metadata/`: Edge Function per i link shop
  (client la usa con fallback automatico su microlink).
- `src/services/db.js`: mappers app↔DB, CRUD, upload foto + URL firmate (6gg).
- AuthContext: Supabase auth (email+password, Google OAuth, needsConfirmation)
  o mock locale. LoginPage mostra "Continua con Google" solo in cloud.
- ProfileContext: profilo su tabella profiles (avatar, foto riferimento su
  Storage, onboarded, lingua+città sincronizzate); `profileLoading` evita il
  rimbalzo verso l'onboarding; Protected in App.jsx lo aspetta.
- WardrobeContext: caricamento iniziale dal cloud + cache offline di lettura
  (`sv_cloud_cache_<uid>`), scritture ottimistiche write-through (fallimento →
  console.warn, dati restano locali).
- Deploy: `vercel.json` pronto; guida passo-passo in `docs/SETUP-CLOUD.md`.

**COSA MANCA (solo azioni dell'utente, non codice):** creare il progetto su
supabase.com, eseguire la migrazione SQL, mettere le chiavi in `.env.local`,
(facoltativi) provider Google + deploy Edge Function + progetto Vercel.
Il percorso cloud NON è stato provato live (servono le chiavi): alla prima
attivazione va rifatto un giro di verifica.

## Online (2026-07-08)

- **App live (demo, modalità locale):** https://fara2106.github.io/stylevault/
- **Repository:** https://github.com/Fara2106/stylevault (account GitHub: Fara2106)
- Deploy automatico: ogni push su `main` fa test + build e pubblica su GitHub Pages
  (workflow `.github/workflows/deploy.yml`, base path `/stylevault/`).
- La demo gira in modalità locale: capi di esempio precaricati, ogni visitatore
  ha i propri dati nel proprio browser. Con le chiavi Supabase su Vercel si passa
  alla versione con account veri (guida `docs/SETUP-CLOUD.md`).

## Comandi

- `npm run dev` — sviluppo
- `npm test` — test Vitest
- `npm run build` — build produzione

## Note tecniche da ricordare

- `generateOutfits` esistente usa `weather.temperature`, `weather.windSpeed`,
  `weather.rain`, `weather.uvIndex`; il servizio meteo produce giorni compatibili
  (temperature = media percepite del giorno).
- Foto utente: dataURL ridimensionati in localStorage (quota ~5MB: resize obbligatorio).
- i18n: chiavi consigli in `advice.*`, meteo `weather.*`; descrizioni meteo come
  `descriptionKey` da tradurre nel componente.
- Git: repo inizializzato in questa cartella, commit frequenti in italiano.
