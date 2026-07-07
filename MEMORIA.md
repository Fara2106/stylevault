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

Fatto e committato:
- [x] T1 Bootstrap React (template Vite rimosso, provider, build ok)
- [x] T2 Design system + restyle di tutti i componenti + fix bug LanguageSwitch
      (importava SettingsContext come named export) + OutfitCard con API definitiva
      (lock capi, prova avatar) + WeatherBadge per dati Open-Meteo
- [x] T3 i18n esteso it/en (onboarding, avatar, consigli, meteo, statistiche...)
- [x] T4 `services/weather.js` con 11 test verdi

Da fare:
- [ ] T5 Estensioni motore outfit: `generateOutfits(items, weather, occasion, count, options)`
      con `options.lockedItems` e `options.recentWear` (penalità 7gg) + `utils/outfitAdvice.js`
      (consigli come chiavi i18n con parametri) — TDD
- [ ] T6 `utils/imageUtils.js` (resize foto → dataURL max 600px) +
      `services/linkMetadata.js` (microlink.io con fallback manuale)
- [ ] T7 Avatar: `components/Avatar/{AvatarSvg,AvatarEditor,OutfitOnAvatar}.jsx`
      (opzioni già in `utils/avatarOptions.js`, stato in `context/ProfileContext.jsx`)
- [ ] T8 Shell: `App.jsx` router + ProtectedRoute + layout (header desktop)
- [ ] T9 Pagine (cartelle vuote in `src/pages/`): Login, Onboarding, Wardrobe(+tab wishlist),
      ItemDetail, AddItem (foto+link), Outfit (città+giorno+occasione, genera/blocca/salva,
      consigli, prova avatar), Calendar, Profile (avatar editor + statistiche)
- [ ] T10 Rifinitura: SAMPLE_ITEMS solo in dev, favicon, README, verifica finale browser

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
