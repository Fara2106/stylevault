# Meteo della posizione, giornata ora per ora e Meteo di Apple — design

Data: 2026-11-04. Richiesta di Lorenzo durante la prova dell'app sull'iPhone.

## Perché

Oggi la pagina Outfit prende il meteo da Open-Meteo per una città scelta a mano
(di partenza la "città predefinita" del Profilo) e usa solo il riassunto del
giorno: minima, massima, media delle percepite, pioggia. Lorenzo vuole:

- il meteo **di dove si trova**, senza sceglierlo;
- **un'idea di com'è la giornata** (mattina, pomeriggio, sera);
- suggerimenti migliori su cosa indossare, che tengano conto di come cambia il
  tempo durante il giorno;
- per chi **viaggia**: poter impostare a mano un altro posto;
- il **Meteo di Apple** (WeatherKit) appena Apple approva il suo account Apple
  Developer (già pagato, in attesa di approvazione). Fino ad allora Open-Meteo.

Regola già data da Lorenzo e valida anche qui: **l'outfit si genera sempre**;
ciò che non torna diventa un avviso, mai un blocco.

## Obiettivi

1. **Posizione del telefono** come luogo di partenza nella pagina Outfit.
2. **Luogo scelto a mano** (viaggi) che resta finché l'utente non torna a "La
   mia posizione".
3. **Striscia "la giornata"** sotto la scheda del meteo: mattina, pomeriggio,
   sera, con icona, temperatura e probabilità di pioggia.
4. **Calcolo sulle ore fuori casa** (8–20) e consigli nuovi: "a strati" quando
   tra mattina e pomeriggio cambia molto, "pioggia da una certa ora".
5. **Meteo di Apple preparato** nell'app, spento finché l'account non è
   approvato; acceso, sostituisce Open-Meteo nell'app.

## Non obiettivi

- Città diverse per giorni diversi (itinerario di viaggio): si sceglie un posto
  alla volta.
- Notifiche o avvisi meteo push.
- Meteo di Apple nel sito aperto dal browser (solo nell'app iOS).
- Cambiare la "città predefinita" del Profilo o il funzionamento del Calendario
  (che però riceve la stessa `temperature` migliorata: vedi le scelte sotto).

## Anti-obiettivi (sarebbe un fallimento anche se funziona)

- Chiedere la posizione all'apertura del sito nel browser: si chiede solo al
  tocco di "Usa la mia posizione".
- Pagina Outfit vuota o bloccata perché la posizione è negata, lenta o assente:
  si usa subito la città predefinita e la posizione la sostituisce quando arriva.
- Mandare le coordinate a servizi diversi dal fornitore del meteo, o salvarle
  sul server (Supabase).
- Rompere la firma dell'app con l'Apple ID gratuito aggiungendo ora il permesso
  WeatherKit.

## Vincoli

- Sito: React + Vite, test con Vitest (nessun test di componenti: la logica va
  in funzioni pure testate). Testi in `src/i18n/it.json` ed `en.json`.
- App: SwiftUI + WKWebView, ponte `svNative` (sito → app: `postMessage`
  `{type, payload}`; app → sito: `window.svNative.<funzione>(…)` dopo `ready`,
  come `setSession`). Solo le pagine del sito possono parlare col ponte.
- Permesso di posizione iOS: `NSLocationWhenInUseUsageDescription`, solo "mentre
  usi l'app"; basta la posizione approssimativa.
- Open-Meteo: gratuito, senza chiave; ha i dati orari (`hourly`) oltre ai
  giornalieri.
- WeatherKit: richiede l'Apple Developer Program a pagamento, la capability
  WeatherKit sull'App ID e l'entitlement `com.apple.developer.weatherkit`.
  Apple obbliga a mostrare il marchio Meteo di Apple e il link alle fonti legali
  ovunque si mostrino i suoi dati.
- Commit in italiano con `Co-Authored-By`; commit locali ok, push solo con l'ok
  di Lorenzo; deploy del sito solo con il suo ok.

## Come funziona

### Luogo

La pagina Outfit ha un **luogo**: "La mia posizione" oppure una città scelta.

- Nell'app iOS il luogo di partenza è **"La mia posizione"**. L'app chiede il
  permesso la prima volta che il sito lo domanda; con la posizione ottenuta
  (approssimativa) ricava il nome del posto dal telefono (geocodifica inversa di
  iOS) e lo passa al sito: `window.svNative.setLocation({latitude, longitude,
  name})`. Se il permesso è negato o la posizione non arriva, il sito resta sulla
  città predefinita, senza messaggi bloccanti (una riga discreta "Posizione non
  disponibile: uso <città>" nel selettore va bene).
- Nel browser il selettore ha "Usa la mia posizione": al tocco usa
  `navigator.geolocation`; il nome del posto è "La mia posizione" (niente
  geocodifica inversa con servizi esterni).
- **Città scelta a mano** (viaggi): con la ricerca città già esistente. La
  scelta si ricorda su quel dispositivo (localStorage) finché l'utente non tocca
  "La mia posizione"; si vede chiaramente che è un luogo scelto a mano (es.
  "Parigi · scelta a mano").
- Il luogo vale per tutti i 7 giorni della pagina.

### Previsione

Una sola forma dei dati per giorno, qualunque sia la fonte. Ai campi di oggi
(`city, date, tMin, tMax, temperature, windSpeed, uvIndex, precipProb, icon,
descriptionKey, rain, snow`) si aggiunge `parts`: tre fasce **mattina 8–12,
pomeriggio 12–17, sera 17–20** (ora locale del luogo), ognuna con temperatura
percepita media, icona e probabilità massima di pioggia; e `rainFrom`: la prima
ora della fascia 8–20 con pioggia probabile (stessa soglia di oggi), o null.

`temperature` (quella che decide quanto coprirsi) diventa la **media delle
percepite tra le 8 e le 20**; senza dati orari resta il calcolo di oggi.

Fonti:
- **Open-Meteo** (sito, sempre disponibile): si aggiungono alla richiesta i dati
  orari necessari; la cache attuale resta.
- **Meteo di Apple** (solo app, quando acceso): l'app ottiene la previsione con
  WeatherKit per la posizione o la città e la passa al sito già in questa forma;
  il sito la usa al posto di Open-Meteo. Se WeatherKit fallisce, Open-Meteo.

### Striscia della giornata

Sotto la scheda del meteo, tre colonne: Mattina, Pomeriggio, Sera, con icona,
temperatura e (se > 0) probabilità di pioggia. Se mancano i dati orari la
striscia non c'è.

### Consigli nuovi

Nell'elenco consigli dell'outfit (già esistente):
- **A strati**: se tra la fascia più fredda e la più calda ci sono almeno 8°
  di differenza → "A strati: X° la mattina, Y° il pomeriggio" (fasce reali).
- **Pioggia più tardi**: se c'è `rainFrom` e non piove già dal mattino →
  "Pioggia probabile dalle HH: porta l'ombrello".
I consigli non cambiano l'outfit generato e non lo bloccano.

### Meteo di Apple (preparato, spento)

- Codice nell'app: chiede a WeatherKit la previsione giornaliera e oraria e la
  converte nella forma sopra (conversione testata con dati finti).
- Spento da un interruttore nel codice; l'entitlement WeatherKit **non** si
  aggiunge ora.
- Quando è acceso, sotto la scheda del meteo compaiono il marchio Meteo di Apple
  e il link alle fonti legali (forniti da WeatherKit).
- Per accenderlo, dopo l'approvazione: capability WeatherKit sull'App ID,
  entitlement, interruttore acceso, prova sul telefono. Va scritto in MEMORIA.md
  come passo da fare.

## Lasciato a chi realizza

- Componenti e nomi dei file, purché la logica (fasce, `rainFrom`, consigli,
  scelta del luogo) stia in funzioni pure con test.
- Aspetto della striscia e del selettore, coerente con lo stile esistente
  (token `--sv-*`).
- Come l'app ottiene una posizione sola (richiesta singola, non continua).
- Quando il sito chiede la posizione all'app (all'apertura della pagina Outfit
  va bene) e come gestire una risposta che arriva tardi.

## Scelte di chi ha scritto il design (dopo il controllo del costruttore)

Decise da Claude, non da Lorenzo; da rivedere se qualcosa non convince.

1. **Calendario**: usa lo stesso lettore della previsione, quindi riceve anche
   lui la nuova `temperature` (media delle percepite 8–20). È un miglioramento,
   non un cambio di funzione; i test esistenti si aggiornano di conseguenza.
2. **Oggi, ore già passate**: per il giorno di oggi la media, le fasce e
   `rainFrom` contano solo le ore **da adesso** dentro 8–20; le fasce già
   passate nella striscia si vedono attenuate ("passata"). Dopo le 20 si usa
   tutta la fascia 8–20. Gli altri giorni: sempre 8–20 intera.
3. **Soglia della pioggia oraria**: la stessa `RAIN_PROBABILITY_THRESHOLD` di
   oggi, applicata alla probabilità di ogni ora. "Piove già dal mattino" =
   `rainFrom` coincide con la prima ora considerata: allora vale il consiglio
   pioggia di oggi e non quello "dalle HH".
4. **Posizione nel browser**: si ricorda (localStorage) solo la *scelta*
   "La mia posizione", mai le coordinate; alla visita dopo si richiede la
   posizione al browser (che di solito ricorda il permesso). Nell'app la
   posizione si chiede con una richiesta singola a ogni apertura della pagina
   Outfit.
5. **Sito nuovo in app vecchia (e viceversa)**: il sito parte sempre dalla città
   predefinita e passa alla posizione solo se arriva `setLocation`; nessuna
   attesa né errore se non arriva. Il sito chiede la posizione con un messaggio
   `requestLocation`; un'app vecchia lo ignora (i messaggi sconosciuti sono
   scartati da `BridgeMessage.parse`).
6. **Cache**: la chiave della cache della previsione include la fonte
   (Open-Meteo / Apple); il comportamento "dati non aggiornati" vale per
   entrambe.
7. **Condizioni di Apple → icone**: le condizioni WeatherKit si convertono nelle
   stesse icone e chiavi `weather.*` di `mapWeatherCode`; una condizione senza
   corrispondenza diventa "nuvoloso".
8. **Permessi**: ora si aggiunge solo `NSLocationWhenInUseUsageDescription`;
   il codice WeatherKit compila senza entitlement e resta spento.
