# Fixture per il classificatore capi

Immagini vere per tarare/verificare `garmentClassifier.js` (i test sintetici non
bastano: bordi netti irreali). Usate da `garmentClassifier.real.test.js`.

## Positivi (attesi: `screenshot`)

- `screenshot-app-1.png`, `screenshot-app-2.png` — screenshot **reali dell'app
  StyleVault** (da `docs/verifiche/`). Sono screenshot autentici (UI, testo, molte
  isole di contenuto, molto sfondo).
  - ⚠️ **Limite:** sono screenshot della *nostra* app, non di app di **shopping**
    come quelli che carica l'utente. Ma hanno **meno** testo/UI di uno screenshot
    di shopping, quindi tararci sopra è **conservativo**: uno screenshot di
    shopping (più testo, più isole) scatterà ancora più facilmente.

## Negativi (attesi: NON `screenshot`)

- `capo-shirt.jpg`, `capo-jeans.jpg`, `capo-dress.jpg`, `capo-sweater.jpg` — foto
  di capi reali (loremflickr per parola chiave). Servono a controllare i **falsi
  positivi**: un capo vero non deve essere bloccato.

## Da aggiungere quando disponibile

Lo **screenshot vero che carica l'utente** (es. capo su un'app di shopping con
prezzo/badge) per confermare la taratura sul caso reale prima di considerarla
definitiva. Finché non c'è, la taratura è basata sui proxy qui sopra.

## Perché isole+sfondo e non testo

Misurato il 2026-07-14: il **testo** NON separa (una maglietta liscia ha densità di
testo maggiore di uno screenshot poco testuale). Separano **isole di contenuto**
(capi 1–9, screenshot 52–145) e **sfondo uniforme** (screenshot 0.84–0.95, capi
bassi). Il verdetto usa quelli.
