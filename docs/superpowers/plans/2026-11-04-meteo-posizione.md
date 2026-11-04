# Meteo della posizione, giornata ora per ora e Meteo di Apple — piano

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** la pagina Outfit usa il meteo di dove si trova l'utente (o di una città scelta a mano), mostra la giornata in tre fasce, consiglia in base alle ore fuori casa, e l'app iOS è pronta a usare il Meteo di Apple appena acceso.

**Architecture:** tutta la logica meteo resta nel sito, in funzioni pure: Open-Meteo dà anche i dati orari e `parseForecastPayload` ne ricava fasce, `rainFrom` e la temperatura delle ore 8–20. L'app iOS dà al sito la posizione (`requestLocation` → `svNative.setLocation`) e, quando WeatherKit sarà acceso, una previsione **nello stesso formato del payload Open-Meteo** (condizioni Apple → codici WMO), così il sito la legge con lo stesso `parseForecastPayload`.

**Tech Stack:** React 18 + Vite + Vitest (sito); SwiftUI, WKWebView, CoreLocation, MapKit/CLGeocoder, WeatherKit (app, iOS 17), XcodeGen.

**Spec:** `docs/superpowers/specs/2026-11-04-meteo-posizione-design.md` (con le "Scelte" in fondo).

## Global Constraints

- L'outfit si genera **sempre**: posizione negata, lenta, assente o meteo Apple spento non bloccano né svuotano la pagina; si parte subito dalla città predefinita.
- Fasce (ora locale del luogo): **mattina 8–12, pomeriggio 12–17, sera 17–20**; ore considerate: `8 ≤ h < 20`.
- Soglia pioggia oraria: `RAIN_PROBABILITY_THRESHOLD` (45) di `src/services/weather.js`.
- Consiglio "a strati" se tra la fascia considerata più fredda e la più calda ci sono **≥ 8°**.
- Nel browser la posizione si chiede **solo al tocco** di "Usa la mia posizione"; si ricorda solo la scelta, **mai le coordinate**; le coordinate non vanno a Supabase né a servizi diversi dal fornitore del meteo.
- iOS: solo `NSLocationWhenInUseUsageDescription` in più; **niente** entitlement WeatherKit ora; `AppleWeather.isEnabled = false`.
- Testi in `src/i18n/it.json` e `en.json`; stile coi token `--sv-*`.
- Test: sito `npx vitest run`; app sul simulatore **solo** `-destination 'id=18361580-2FC8-4A18-AED3-7461008C6569'` con `CODE_SIGNING_ALLOWED=NO` e `-project StyleVault.xcodeproj` (simulatore condiviso con altre app: non toccarle).
- Dopo modifiche a `ios/project.yml`: `cd ios && xcodegen generate`.
- Commit in italiano che finiscono con `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; commit locali sì, push no.

## Review Focus

1. Pagina aperta dopo le 20 o prima delle 8 (oggi) → tutte le ore 8–20 contano; nessuna divisione per zero, nessuna fascia vuota mostrata come `NaN°`.
2. Payload senza `hourly` (cache vecchia, Calendario, meteo manuale) → giorno come oggi, senza `parts`; la striscia non compare.
3. Posizione che arriva **dopo** che l'utente ha scelto a mano una città → la scelta a mano resta.
4. Nome posto con apici o caratteri speciali (es. `L'Aquila`) passato dall'app al sito → arriva intatto, nessun errore JavaScript.
5. Luogo con fuso diverso dal telefono (città scelta a mano a New York) → "adesso" e le ore passate calcolati nel fuso del luogo (`utc_offset_seconds`), non del telefono.

Ognuno ha il suo test nel task che possiede il codice.

---

### Task 1: Fasce della giornata (funzione pura)

**Files:**
- Create: `src/utils/dayParts.js`
- Test: `src/utils/dayParts.test.js`

**Interfaces:**
- Produces: `summarizeDay(hours, { nowHour }) → { temperature: number|null, parts: Part[], rainFrom: number|null, rainFromStart: boolean }`
  - `hours`: `{ hour: number (0–23), apparent: number|null, precipProb: number|null, code: number|null }[]` di **un** giorno.
  - `nowHour`: ora locale del luogo se il giorno è oggi, altrimenti `null`. Se `nowHour == null`, `< 8` o `≥ 20` contano tutte le ore 8–19.
  - `Part`: `{ key: 'morning'|'afternoon'|'evening', temperature: number|null, code: number|null, precipProb: number|null, past: boolean }`; `temperature` = media delle `apparent` della fascia; `code` = il **massimo** codice WMO della fascia; `precipProb` = massimo; `past` = tutte le ore della fascia `< nowHour` (con le regole sopra).
  - `temperature` = media delle `apparent` delle ore considerate (non passate); `null` se nessuna.
  - `rainFrom` = prima ora considerata con `precipProb ≥ 45`, o `null`; `rainFromStart` = `rainFrom` è la prima ora considerata.
  - Valori `null` nelle ore si saltano nelle medie e nei massimi.

- [ ] **Step 1: Test che falliscono** — in `dayParts.test.js`, con un helper che costruisce 24 ore:
  - `fasce e media sulle ore 8–20 per un giorno futuro`: apparent = h per ogni ora → `temperature` = 13.5, `parts.map(p => p.temperature)` = `[9.5, 14, 18]`, nessuna `past`.
  - `oggi alle 15 conta solo da adesso`: `nowHour: 15` → `temperature` = media di 15..19 = 17; `parts[0].past === true`, `parts[1].past === false`.
  - `dopo le 20 o prima delle 8 conta tutta la giornata`: `nowHour: 21` e `nowHour: 6` → `temperature` 13.5, nessuna `past`.
  - `rainFrom: prima ora considerata con probabilità ≥ 45`: precipProb 50 dalle 18 → `rainFrom` 18, `rainFromStart` false; con 50 dalle 8 → `rainFromStart` true.
  - `codice e pioggia della fascia sono i massimi`: codici 3 e 61 nel pomeriggio → `parts[1].code` 61.
  - `ore senza dati`: tutte `apparent: null` → `temperature` null e fasce con `temperature` null (nessun `NaN`).
- [ ] **Step 2:** `npx vitest run src/utils/dayParts.test.js` → FAIL (modulo mancante).
- [ ] **Step 3:** implementa `summarizeDay` in `src/utils/dayParts.js` (esporta anche `DAY_PARTS = [{key:'morning',from:8,to:12},{key:'afternoon',from:12,to:17},{key:'evening',from:17,to:20}]`).
- [ ] **Step 4:** stesso comando → PASS.
- [ ] **Step 5:** commit `feat(meteo): fasce della giornata e pioggia ora per ora`.

### Task 2: Previsione oraria da Open-Meteo e cache per fonte

**Files:**
- Modify: `src/services/weather.js` (`parseForecastPayload`, `fetchForecastWithCache`, `cacheKey`)
- Test: `src/services/weather.test.js`

**Interfaces:**
- Consumes: `summarizeDay` (Task 1), `mapWeatherCode` (esistente).
- Produces:
  - `parseForecastPayload(payload, cityLabel, now = new Date())`: se `payload.hourly.time` c'è, ogni giorno riceve `parts` (con `icon` e `descriptionKey` da `mapWeatherCode(part.code)` oltre ai campi di Task 1), `rainFrom`, `rainFromStart`, e `temperature` = `summary.temperature` quando non è null. Senza `hourly`: giorno identico a oggi (nessun `parts`). "Oggi" e `nowHour` si calcolano nel fuso del luogo: `now + payload.utc_offset_seconds` (in UTC) → data `YYYY-MM-DD` e ora.
  - `fetchForecastWithCache(city, { source = 'openmeteo' } = {})`: richiesta con in più `hourly=apparent_temperature,precipitation_probability,weather_code`; chiave cache `sv_weather_<source>_<lat>_<lon>` (2 decimali).
  - `saveForecastToCache(city, source, days)` e la lettura della cache estratte in modo che Task 6 possa salvare i giorni arrivati dall'app con `source = 'apple'`.

- [ ] **Step 1: Test che falliscono** in `weather.test.js`:
  - `con hourly aggiunge fasce e usa la media 8–20`: payload con `utc_offset_seconds: 3600`, 2 giorni, hourly 48 ore (apparent = h), `now` = giorno 2 alle 05:00 UTC → giorno 2 ha `temperature` 13.5 e `parts[0].icon` definita; giorno 1 (passato rispetto a now) ha `parts`.
  - `il fuso del luogo decide le ore passate`: stesso payload con `utc_offset_seconds: -18000`, `now` = giorno 1 alle 20:00 UTC (15 a New York) → giorno 1 `parts[0].past === true`.
  - `senza hourly il giorno è come prima`: payload di oggi del test esistente → nessuna chiave `parts`, `temperature` come prima.
  - `la chiave della cache contiene la fonte`: dopo `fetchForecastWithCache(city)` riuscito, `_memoryStorage` ha una chiave che inizia con `sv_weather_openmeteo_`.
  - Aggiorna l'asserzione esistente sui parametri della richiesta se controlla l'URL.
- [ ] **Step 2:** `npx vitest run src/services/weather.test.js` → FAIL.
- [ ] **Step 3:** implementa.
- [ ] **Step 4:** `npx vitest run` (tutto il sito) → PASS; Calendario e Outfit funzionano con o senza `parts`.
- [ ] **Step 5:** commit `feat(meteo): dati orari di Open-Meteo e temperatura delle ore fuori casa`.

### Task 3: Consigli "a strati" e "pioggia più tardi"

**Files:**
- Modify: `src/utils/outfitAdvice.js`, `src/i18n/it.json`, `src/i18n/en.json`
- Test: `src/utils/outfitAdvice.test.js`

**Interfaces:**
- Consumes: giorno con `parts`, `rainFrom`, `rainFromStart` (Task 2).
- Produces: in `getOutfitAdvice` due consigli nuovi:
  - `{ key: 'advice.layers', params: { cold, coldPart, warm, warmPart } }` se tra le fasce **non passate** con temperatura la differenza max−min è ≥ 8; `cold`/`warm` arrotondati; `coldPart`/`warmPart` = **chiave** della fascia (`'morning'|'afternoon'|'evening'`). La traduzione in "la mattina" ecc. la fa OutfitPage (Task 5) prima di chiamare `t(a.key, a.params)`.
  - `{ key: 'advice.rainLater', params: { hour } }` se `rainFrom != null && !rainFromStart`; `hour` = `"18:00"`.
  - Testi it: `"advice.layers": "A strati: {{cold}}° {{coldPart}}, {{warm}}° {{warmPart}}."`, `"advice.rainLater": "Pioggia probabile dalle {{hour}}: porta l'ombrello."`; `weather.part`: `{ "morning": "la mattina", "afternoon": "il pomeriggio", "evening": "la sera" }` e per la striscia `weather.partTitle`: `{ "morning": "Mattina", "afternoon": "Pomeriggio", "evening": "Sera" }`. En: `"Dress in layers: {{cold}}° {{coldPart}}, {{warm}}° {{warmPart}}."`, `"Rain likely from {{hour}}: take an umbrella."`, `in the morning / in the afternoon / in the evening`, `Morning / Afternoon / Evening`.

- [ ] **Step 1: Test che falliscono**: `strati con 9° la mattina e 19° il pomeriggio` → contiene `advice.layers` con `{cold: 9, coldPart: 'morning', warm: 19, warmPart: 'afternoon'}`; `niente strati sotto gli 8°`; `le fasce passate non contano` (mattina past a 2°, pomeriggio 15, sera 12 → niente strati); `pioggia dalle 18` → `advice.rainLater` `{hour: '18:00'}`; `pioggia dal mattino` (`rainFromStart: true`) → niente `rainLater`; `giorno senza parts` → nessuno dei due.
- [ ] **Step 2:** `npx vitest run src/utils/outfitAdvice.test.js` → FAIL.
- [ ] **Step 3:** implementa e aggiungi i testi.
- [ ] **Step 4:** PASS.
- [ ] **Step 5:** commit `feat(meteo): consigli a strati e pioggia più tardi`.

### Task 4: Scelta del luogo e ponte posizione nel sito

**Files:**
- Create: `src/utils/place.js`, `src/utils/place.test.js`
- Modify: `src/utils/nativeBridge.js` (+ test esistente se c'è, altrimenti `src/utils/nativeBridge.test.js`)

**Interfaces:**
- Produces (`place.js`):
  - `loadPlaceChoice() → { mode: 'position' } | { mode: 'city', city }` (localStorage `sv_outfit_place`; default `{ mode: 'position' }`; JSON rotto → default). Mai coordinate per `mode: 'position'`.
  - `savePlaceChoice(choice)`.
  - `resolvePlace({ choice, position, defaultCity }) → { city, kind: 'position'|'manual'|'default' }`: `city` manuale se `mode: 'city'`; la posizione (`{ name, latitude, longitude }`) se `mode: 'position'` e c'è; altrimenti `defaultCity` con `kind: 'default'`.
  - `getBrowserPosition() → Promise<{latitude, longitude}|null>` (`navigator.geolocation.getCurrentPosition`, `enableHighAccuracy: false`, `timeout: 10000`, `maximumAge: 600000`; errore o assente → `null`).
- Produces (`nativeBridge.js`):
  - `installNativeHooks({ setSession })` espone anche `window.svNative.setLocation(loc)` e `window.svNative.setForecast(data)` che inoltrano agli iscritti.
  - `onNativeLocation(cb) → unsubscribe`, `onNativeForecast(cb) → unsubscribe`.
  - `requestNativeLocation()` = `postToNative('requestLocation')`; `requestNativeForecast(city)` = `postToNative('requestForecast', { latitude, longitude, name })`.
  - L'ultima posizione ricevuta resta disponibile a chi si iscrive dopo (`onNativeLocation` la richiama subito).

- [ ] **Step 1: Test che falliscono**: `place.test.js` — default position; salva e rilegge una città; JSON rotto → default; `resolvePlace` nei tre casi; **posizione arrivata dopo una scelta manuale** → resta `manual` (Review Focus 3); `getBrowserPosition` con `navigator.geolocation` finto che fallisce → `null`. `nativeBridge.test.js` — con `globalThis.window = { webkit: { messageHandlers: { svNative: { postMessage: vi.fn() } } } }`: `installNativeHooks` poi `window.svNative.setLocation({...})` chiama l'iscritto; iscrizione dopo l'arrivo riceve l'ultima; `requestNativeLocation` manda `{ type: 'requestLocation', payload: {} }`.
- [ ] **Step 2:** `npx vitest run src/utils/place.test.js src/utils/nativeBridge.test.js` → FAIL.
- [ ] **Step 3:** implementa.
- [ ] **Step 4:** PASS.
- [ ] **Step 5:** commit `feat(meteo): scelta del luogo e posizione dal ponte con l'app`.

### Task 5: Pagina Outfit — luogo, striscia della giornata, consigli

**Files:**
- Create: `src/components/DayStrip/DayStrip.jsx`, `DayStrip.css`
- Modify: `src/pages/OutfitPage/OutfitPage.jsx`, `OutfitPage.css`, `src/components/CitySearch/CitySearch.jsx` (solo se serve un'azione in cima), i18n

**Interfaces:**
- Consumes: Task 2 (`parts`), Task 3 (consigli e testi), Task 4 (scelta luogo, ponte, `getBrowserPosition`).
- Comportamento:
  - Stato iniziale: `choice = loadPlaceChoice()`, città = `resolvePlace(...)` → con `mode: 'position'` e nessuna posizione si mostra subito la città predefinita e si genera.
  - Nell'app (`isNativeApp()`): con `mode: 'position'` all'apertura `requestNativeLocation()`; `onNativeLocation` aggiorna la posizione. Nel browser con `mode: 'position'` salvato da una visita precedente: `getBrowserPosition()` all'apertura (il permesso era già stato dato).
  - Controlli: chip/pulsante **"La mia posizione"** (attivo quando `kind === 'position'`) accanto alla ricerca città. Toccarlo: `savePlaceChoice({mode:'position'})` e (browser) `getBrowserPosition()`; se `null` → riga discreta `"Posizione non disponibile: uso {{city}}"`. Scegliere una città: `savePlaceChoice({mode:'city', city})`, e sotto la città la dicitura `"scelta a mano"`.
  - Cambio di luogo → svuota gli outfit e ricarica la previsione (come il cambio città di oggi).
  - `DayStrip({ parts })` sotto `WeatherBadge`: tre colonne con `t('weather.partTitle.<key>')`, `Icon` della fascia, temperatura arrotondata, `💧 n%` solo se `precipProb > 0`; fascia `past` con opacità ridotta; niente se `parts` assente o se tutte le temperature sono `null`.
  - Consigli: prima di `t(a.key, a.params)`, se `a.params?.coldPart` traducilo con `t('weather.part.' + key)` (idem `warmPart`).
  - Testi: `outfit.myPosition` "La mia posizione"/"My location", `outfit.positionUnavailable` "Posizione non disponibile: uso {{city}}"/"Location unavailable: using {{city}}", `outfit.chosenByHand` "scelta a mano"/"chosen manually".
- [ ] **Step 1:** implementa (nessun test di componente nel progetto: la logica è già testata nei Task 1–4).
- [ ] **Step 2:** `npx vitest run` → PASS; `npx vite build --outDir <scratchpad>/site-build --emptyOutDir` → build ok.
- [ ] **Step 3:** controllo nel pannello browser col dev server `stylevault-locale` (porta 5180, dati locali senza login): pagina Outfit con città predefinita, striscia visibile, scelta città "Parigi" → "scelta a mano", ricarica → resta Parigi; "La mia posizione" → (permesso negato nel pannello) riga "Posizione non disponibile". Screenshot.
- [ ] **Step 4:** commit `feat(meteo): luogo, giornata in tre fasce e consigli nella pagina Outfit`.

### Task 6: Posizione dall'app iOS

**Files:**
- Create: `ios/StyleVault/Weather/LocationProvider.swift`
- Modify: `ios/StyleVault/Web/WebBridge.swift` (`BridgeMessage.requestLocation`, `.requestForecast(ForecastRequest)`), `ios/StyleVault/Web/WebViewStore.swift` (`pushLocation`, `static func callScript(_ function: String, json: Data) -> String`), `ios/StyleVault/App/StyleVaultApp.swift`, `ios/project.yml` (`NSLocationWhenInUseUsageDescription: "Per mostrarti il meteo di dove sei e consigliarti cosa indossare."`)
- Test: `ios/StyleVaultTests/WebBridgeTests.swift`, `WebViewStoreTests.swift`

**Interfaces:**
- `struct ForecastRequest: Decodable, Equatable { let latitude: Double; let longitude: Double; let name: String? }`
- `struct PlacePayload: Encodable, Equatable { let latitude: Double; let longitude: Double; let name: String }`
- `@MainActor final class LocationProvider: NSObject, CLLocationManagerDelegate` con `func currentPlace() async -> PlacePayload?`: una richiesta singola (`requestWhenInUseAuthorization` se non deciso, poi `requestLocation()`), `desiredAccuracy = kCLLocationAccuracyReduced`; nome dal telefono (`MKReverseGeocodingRequest` se disponibile sul target, altrimenti `CLGeocoder`), ripiego `"La mia posizione"`; permesso negato/errore → `nil` (il sito resta sulla città predefinita).
- `WebViewStore.callScript("setLocation", json:)` → `"window.svNative && window.svNative.setLocation && window.svNative.setLocation(<json>)"` dove `<json>` è il JSON codificato (JSON è JavaScript valido: niente escape manuali).
- In `StyleVaultApp`: `.requestLocation` → `Task { if let place = await location.currentPlace() { web.pushLocation(place) } }`; `.requestForecast` → per ora delegato a `AppleWeather` (Task 7), che spento non fa niente.

- [ ] **Step 1: Test che falliscono**: `testRequestLocation` (`parse(["type":"requestLocation"]) == .requestLocation`); `testRequestForecast` con payload lat/lon/name; payload senza lat → `nil`; `testCallScriptConApici`: `PlacePayload(name: "L'Aquila")` → lo script contiene `"L'Aquila"` dentro una stringa JSON valida e inizia con `window.svNative &&` (Review Focus 4).
- [ ] **Step 2:** `cd ios && xcodegen generate` poi `xcodebuild test -project StyleVault.xcodeproj -scheme StyleVault -destination 'id=18361580-2FC8-4A18-AED3-7461008C6569' CODE_SIGNING_ALLOWED=NO -only-testing:StyleVaultTests/WebBridgeTests -only-testing:StyleVaultTests/WebViewStoreTests` → FAIL.
- [ ] **Step 3:** implementa.
- [ ] **Step 4:** stesso comando → PASS; poi tutta `StyleVaultTests` → PASS.
- [ ] **Step 5:** commit `feat(meteo): l'app passa al sito la posizione del telefono`.

### Task 7: Meteo di Apple preparato (spento)

**Files:**
- Create: `ios/StyleVault/Weather/AppleWeather.swift`, `ios/StyleVault/Weather/AppleWeatherPayload.swift`
- Modify: `ios/StyleVault/App/StyleVaultApp.swift`; sito: `src/pages/OutfitPage/OutfitPage.jsx`, `src/components/WeatherBadge/WeatherBadge.jsx` (attribuzione), i18n
- Test: `ios/StyleVaultTests/AppleWeatherPayloadTests.swift`; sito: test in `src/services/weather.test.js` per la fonte apple

**Interfaces:**
- `enum AppleWeather { static let isEnabled = false }` con `static func forecast(for: ForecastRequest) async -> AppleForecast?` che, se acceso, usa `WeatherService.shared.weather(for:including: .daily, .hourly)` e `WeatherService.shared.attribution`; spento → `nil` subito.
- Conversione pura e testabile (WeatherKit non ha inizializzatori pubblici per i suoi tipi): strutture proprie `AppleDay { date: String (YYYY-MM-DD); high, low, apparentHigh?, apparentLow?: Double; precipitationChance: Double (0–1); condition: WeatherCondition; windKmh, uv: Double }`, `AppleHour { time: String (YYYY-MM-DDTHH:00, ora locale); apparent: Double; precipitationChance: Double; condition: WeatherCondition }`.
- `static func wmoCode(_ condition: WeatherCondition) -> Int`: sereno/quasi sereno → 0; poco nuvoloso → 2; nuvoloso/coperto → 3; nebbia/foschia → 45; pioviggine → 51; pioggia/rovesci/pioggia forte → 61 (forte 65); neve/nevischio/grandine → 71; temporali → 95; tutto il resto → 3.
- `static func openMeteoPayload(days: [AppleDay], hours: [AppleHour], utcOffsetSeconds: Int) -> [String: Any]` con le stesse chiavi che legge `parseForecastPayload` (`daily.time`, `temperature_2m_max/min`, `apparent_temperature_max/min`, `precipitation_probability_max` in %, `weather_code`, `wind_speed_10m_max`, `uv_index_max`, `hourly.time`, `apparent_temperature`, `precipitation_probability`, `weather_code`, `utc_offset_seconds`).
- Verso il sito: `window.svNative.setForecast({ payload, source: 'apple', attribution: { logoLight, logoDark, legalURL } })` con `callScript` del Task 6.
- Sito: OutfitPage chiede `requestNativeForecast(city)` quando cambia il luogo (nell'app); se arriva `setForecast` per lo stesso luogo, usa `parseForecastPayload(payload, city.name)` al posto di Open-Meteo, salva in cache con fonte `apple`, e `WeatherBadge` riceve `attribution` → logo (chiaro/scuro con `prefers-color-scheme`) e link "Fonti dati" al `legalURL` sotto la scheda. Senza `setForecast` nulla cambia.

- [ ] **Step 1: Test che falliscono**: Swift — `wmoCode` per sereno, pioggia, pioggia forte, neve, temporale, una condizione non mappata; `openMeteoPayload` con 1 giorno e 3 ore → chiavi presenti, probabilità 0.6 → 60, `utc_offset_seconds` riportato. Sito — `parseForecastPayload` su un payload "apple" uguale nel formato produce gli stessi campi.
- [ ] **Step 2:** test → FAIL.
- [ ] **Step 3:** implementa; nessun entitlement; `isEnabled = false`.
- [ ] **Step 4:** test → PASS; build per simulatore e `npx vitest run` → PASS.
- [ ] **Step 5:** in `MEMORIA.md` la checklist per accenderlo: capability WeatherKit sull'App ID (developer.apple.com), entitlement `com.apple.developer.weatherkit` in `project.yml`, `isEnabled = true`, prova sul telefono, controllo del logo e del link.
- [ ] **Step 6:** commit `feat(meteo): Meteo di Apple pronto, spento finché l'account non è approvato`.

### Task 8: Prova sull'iPhone e chiusura

- [ ] **Step 1:** build Debug per l'iPhone di Lorenzo (`00008160-000661061A200036`) col sito dal Mac (`stylevault-cloud`), installa, apri: iOS chiede il permesso di posizione; la pagina Outfit mostra il posto vero, la striscia e i consigli.
- [ ] **Step 2:** aggiorna `MEMORIA.md`; chiedi a Lorenzo per push e deploy del sito.
