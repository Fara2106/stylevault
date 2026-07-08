# StyleVault

Guardaroba digitale con outfit guidati dal meteo. Stile lusso "light editorial".

## Cosa fa

- **Guardaroba**: registra i tuoi capi con foto (ridimensionate sul dispositivo) o
  incollando il link di uno shop online (immagine e nome estratti automaticamente).
- **Outfit**: scegli città (meteo reale Open-Meteo), giorno (fino a 7 giorni) e occasione;
  l'app propone 3 outfit con punteggio meteo + armonia colori e consigli di stile.
  Blocca i capi che vuoi tenere e rigenera il resto.
- **Avatar**: silhouette personalizzabile (corporatura, carnagione, capelli) con la tua
  foto come riferimento; prova gli outfit a collage sugli slot dell'avatar.
- **Calendario**: pianifica gli outfit dei prossimi giorni (con previsione accanto),
  segna cosa hai indossato, avvisi se ripeti un capo indossato da poco.
- **Wishlist**: capi desiderati via link, provabili con i tuoi capi, spostabili nel
  guardaroba dopo l'acquisto.
- **Statistiche**: più/meno indossati, ripartizione per colore e categoria,
  costo per utilizzo.
- Italiano e inglese.

## Stack

React 19 + Vite, react-router 7, i18next, Vitest. Nessun backend in questa fase:
i dati vivono in localStorage (Fase B prevista: Supabase — vedi
`docs/superpowers/specs/2026-07-07-stylevault-design.md`).

## Comandi

```bash
npm install
npm run dev      # sviluppo (dati di esempio precaricati)
npm test         # unit test (motore outfit, meteo, statistiche...)
npm run build    # build di produzione (guardaroba vuoto al primo avvio)
npm run preview  # anteprima della build
```

## Struttura

- `src/utils/` — motore outfit, armonia colori, meteo→calore, consigli, statistiche
- `src/services/` — Open-Meteo (geocoding + forecast con cache), metadati link
- `src/context/` — Auth (mock), Settings, Profile (avatar), Wardrobe (localStorage)
- `src/components/` — design system (tokens in `src/styles/`), avatar SVG, card
- `src/pages/` — Login, Onboarding, Guardaroba, Dettaglio, Aggiungi, Outfit,
  Prova avatar, Calendario, Profilo

Stato del progetto e ripartenza: vedi `MEMORIA.md`.
