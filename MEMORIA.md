# MEMORIA.md — Stato del progetto StyleVault

> File di ripartenza: se apri una nuova chat, leggi questo file per riprendere il lavoro
> esattamente da dove eravamo. Va aggiornato a ogni avanzamento significativo.

## Novità 2026-11-06 (notte) — Bozza completa per Mary

Richiesta di Lorenzo: finire tutte le schermate nella notte e mandarla a Mary. Fatto sul ramo `feat/app-nativa`, nessun push.
- Nuove: Armocromia (`Armocromia/`, logica in `StyleVaultCore/Armocromia`, stagione anche a mano dal Profilo), primi passi (`Onboarding/`, solo
  a chi parte da zero), segnalazioni (`Feedback/`, serve un account), cambio password, esporta e importa (`Data/DataTransfer.swift`, zip nel Core),
  Prompt AI con consenso (`Avatar/TryOnPromptView.swift`), "Vedilo addosso" anche da Calendario e dettaglio, °C/°F, privacy e supporto nel Profilo.
- Calendario: niente doppioni nello stesso giorno, niente "indossato" su giorni futuri, conferma prima di togliere. Desideri: conferma. Sono due
  scelte fatte qui, che cambiano ciò che il sito faceva: i test sono stati aggiornati di conseguenza.
- Dati del sito: `scripts/esporta-da-supabase.mjs` li scrive nel formato di Profilo → Importa. Lo lancia Lorenzo, la chiave service_role resta nel
  suo terminale. Mai provato contro Supabase vero. Istruzioni in `docs/pubblicazione/portare-i-dati-di-mary.md`.
- Vision con foto vere: letto solo `persona.jpg`, foto al crepuscolo. L'affidabilità della stagione su foto di giorno è da verificare con Mary, e il
  confronto con MediaPipe chiesto dal design non è stato fatto. Si correggono i colori a mano o si sceglie la stagione.
- Guasto del simulatore: dopo ore l'app non parte più con "Library not loaded: /usr/lib/libSystem.B.dylib" e i test restano appesi senza errore.
  Si risolve riavviando quel simulatore. Causa non trovata. Lo script `suite-vigilata.sh` interrompe il lancio se il log resta fermo 15 minuti.
- Resta da fare prima dell'App Store: WeatherKit, iPhone Duo, schema CloudKit in Production (senza, in TestFlight i dati non passano fra dispositivi:
  da verificare), testi legali da riscrivere (la pagina privacy descrive ancora il sito).

## Novità 2026-11-11 (pomeriggio) — FASHN: catena intera in Swift, prova sul telefono

Lorenzo ha cambiato idea rispetto al 10/11: «Proviamo a metterci quell'IA on device e vediamo come va, prima di pubblicarla.
Facciamo questo test», e durante la generazione vuole «una barra che indichi il caricamento, con la percentuale accanto».
È una prova: nessuna decisione di pubblicarla. Style Vault non è toccata, la 1.0 (11) resta com'è.

- **Perché nell'app di prova e non dentro Style Vault:** una build di debug di Style Vault sul telefono userebbe l'iCloud di
  sviluppo (guardaroba vuoto) e sostituirebbe quella di TestFlight; una build TestFlight porterebbe 704 MB anche a Mary. La
  qualità si giudica uguale scegliendo le foto vere dalla libreria. Se convince, il passo dopo è «Vedilo addosso».
- **`tools/avatar-fashn/FashnKit`** (pacchetto Swift, iOS 18 e macOS 14): `Frame` (riquadro 576×864 e bordi come l'originale),
  `PoseSketch` (disegno della posa in grigio, come `draw_pose`), `VisionPose` (corpo, mani e viso con Apple Vision al posto di
  DWPose), `FashnPrepare` (foto → tensori, uscita → immagine senza bordi), `FashnSampler` (Eulero, guida 1,5, avanzamento a
  passaggi), `fashn-confronto` (strumento del Mac). Test 15/15.
- **Confronto sul Mac** (`docs/verifiche/2026-11-11-fashn-catena-swift/`): foto preparate a 0,2-0,4 su 255 dall'originale; posa
  di Vision 18 punti su 18, quasi sovrapposta a DWPose; immagine finale a 30 passi con lo stesso rumore equivalente a occhio
  a quella della pipeline originale. Il dubbio «posa sul telefono» del 10/11 sul Mac è chiuso; sull'iPhone va ancora visto.
- **App di prova** (`tools/avatar-fashn/bench`): scelta di persona e capo dalle foto, tipo di capo, capo indossato sì/no, 12/20/30
  passi, barra con percentuale, risultato da salvare, posa vista dal telefono. `--misura` riapre il banco dei tempi.
- **Prima prova di Lorenzo sul telefono (11/11, 15:10-15:18)**, quattro generazioni a 30 passi con le foto di prova: maglione e
  jeans da soli buoni (116 e 119 s, picco 716 MB), outfit intero buono (136 s), maglietta indossata sbagliata (pelle chiara
  della modella su braccia e pancia). Posa di Vision 18 su 18. **«Questa generazione ha fatto scaldare non poco il telefono»**;
  batteria 76% → 71% in quattro generazioni. È il costo da pesare insieme al tempo: funzione occasionale sì, anteprima di ogni
  outfit no.
- **Correzioni dopo la prova:** il capo indossato si isola con lo scontorno di Style Vault (`FashnWorn` usa `WornGarment` del
  Core, senza modificarlo) prima di darlo al modello: sul Mac la pelle torna quella della persona. L'app di prova ha «Da solo /
  Indossato / Indossato, intera», «Aggiungi un altro capo a questo risultato», pausa quando iOS segnala «caldo», temperatura e
  batteria a fine generazione. Con «Intero» su un outfit di due capi l'isolamento prende mezzo outfit: si fanno sopra e sotto.
- **Secondo giro di Lorenzo (15:32-15:35, 20 passi):** maglietta ancora sbagliata perché la scelta «Indossato» a mano non era
  attiva (difetto della schermata, non suo): ora il riconoscimento è automatico, come in Style Vault. **A telefono caldo e in
  carica 20 passi durano 160 s (8 s a passo, il doppio che a freddo)** con iOS che segna ancora «normale»/«tiepido»: i tempi
  del 10/11 valgono solo a freddo. Va rimisurato a freddo e a caldo con i secondi a passo che l'app ora scrive.
- **Permesso dell'11/11:** finché dura questa prova «Fashn Bench» si può reinstallare sull'iPhone di Lorenzo senza chiedere ogni
  volta («Sì, aggiorna pure»). Solo quell'app e solo quel telefono: per Style Vault resta «mai una build di debug senza chiedere».
- Restano del 10/11: origine dei dati di addestramento (mail a FASHN), 15 Pro di Mary, 704 MB da ospitare, etichetta «generato
  con IA», esclusione di intimo e costumi. Il modello non lavora con l'app in secondo piano.

## Novità 2026-11-11 — Build 1.0 (11) caricata

Con l'ok di Lorenzo («Sì, build 11»). Caricata alle 09:37 (`build11.sh`, `upload11.sh` in `.superpowers/sdd/rc/`). Dentro ci sono
le correzioni del 10/11 (sezione qui sotto): pantaloni della foto tolti sotto un capo nuovo, consiglio «già messo», statistiche,
guardaroba vuoto, calore di partenza dal tipo di capo.
- IPA controllata: 1.0 (11), "Style Vault", Apple Distribution, WeatherKit, CloudKit e push in Production, PrivacyInfo, nessuna copia
  " 2", nessun argomento `-SV`, niente Open-Meteo, nessuna eccezione ATS; `BodyBase`, `defaultWarmth` e `EmptyWardrobeHint` nei
  simboli, i due testi nuovi in it e en. Nel binario c'è `http://localhost:9999`, identico nella 10 e non del codice dell'app.
- TestFlight, letto alle 09:50 dell'11/11: build 11 «Pronta per l'invio», gruppo «Lorenzo e Marianna», 2 inviti, 0 installazioni.
- Non provato: sul telefono vero, la prova la fa Lorenzo da TestFlight. Da provare: avatar con un paio di pantaloni (quelli della
  foto del corpo non devono spuntare); un cappotto nuovo deve partire «Pesante»; il consiglio «già messo» il giorno dopo un outfit
  indossato deve dire quali capi. I cappotti già salvati a «Leggero» si correggono a mano dalla scheda del capo.

## Novità 2026-11-10 — FASHN misurato sull'iPhone, usabilità, pantaloni della foto

Richieste di Lorenzo nella stessa sessione: «Analizza l'app e migliorala», poi «il problema è lo scontorno dei capi e dell'avatar»,
poi, visto il confronto, «non è precisissimo, non so se si possa risolvere» e infine «mettiamo questo FASHN VTON v1.5» → «Sì, misuralo».
Sul ramo locale, **non in una build**: la 1.0 (10) su TestFlight non ha niente di questo.

**FASHN VTON v1.5 sull'iPhone 18 Pro Max** (`docs/verifiche/2026-11-10-fashn-iphone/prova-iphone.md`, app di prova in
`tools/avatar-fashn/bench/`, installata sul telefono con l'ok di Lorenzo, bundle `it.faraoni.stylevault.bench`):
- Generazione intera a 6 bit (704 MB) sulla GPU: **30 passi 121,7 s, 20 passi 81,1 s, 12 passi 49,5 s**, circa 3,9 s a passo.
  Picco di memoria misurato 669-854 MB (`phys_footprint`: la GPU potrebbe non esserci tutta). Immagine uguale a quella del Mac.
- A 20 passi le trecce del maglione restano; a 12 la forma è giusta ma la trama sparisce.
- Non misurato: 15 Pro di Mary, iPad, senza permesso di memoria aumentata, Neural Engine, capi indossati, pantaloni, vestiti,
  più generazioni di fila. **DWPose non è convertito**: le pose vengono ancora dal Mac, la catena intera sul telefono non esiste.
- Licenze, ricontrollate il 10/11 sul repository: codice e pesi Apache 2.0, DWPose e YOLOX Apache 2.0, origine dei dati di
  addestramento non dichiarata (18 milioni di coppie più 4 milioni di terne sintetiche). Il parser (solo ricerca) non serve.
- **Deciso da Lorenzo il 10/11 dopo la misura:** prima «non mi fido ancora di questi FASHN», poi «lasciala ai prossimi passi».
  FASHN non entra nella 1.0. Dopo l'uscita, nell'ordine: Lorenzo scrive a FASHN per l'origine dei dati; posa sul telefono
  nell'app di prova; misura sul 15 Pro di Mary. Solo con tre risposte buone entra in un aggiornamento, come download facoltativo.
  Non riproporlo prima e non integrarlo senza che lo dica lui.
- Da chiudere prima di integrarlo: rischio sui dati di addestramento (consigliato scrivere a FASHN), 704 MB da
  scaricare e dove ospitarli, 80-120 s di attesa a immagine. Poi: posa sul telefono (DWPose o Apple Vision), etichetta
  «generato con IA», segnalazione, esclusione di intimo e costumi, crediti, note per il revisore. La decisione 6 del design
  (prima versione senza avatar realistico) vale finché Lorenzo non la cambia.
- Gli script del Mac (`convert_coreml.py`, `coreml_pipeline.py`, `guard.sh`, README) stanno nel commit `68c2f5a`; i modelli
  convertiti in `tools/avatar-fashn/out/` (fuori da git).

**Avatar a collage** (`docs/verifiche/2026-11-10-pantaloni-della-foto/`, banco del Mac con Vision vero su 4 foto del corpo):
- `BodyBase` (Core, `Avatar/`): quando si mette un capo sotto, i pantaloni della foto del corpo si tolgono dalla vita in giù
  (stessa riga di `GarmentLayout.waistY`), pelle esclusa. Prima spuntavano tra le gambe e ai lati dei pantaloni nuovi.
- Il sopra non si tocca. Colorare «color pelle» maglia e braccia della foto è stato provato e scartato: macchie marroni, e in
  un caso anche la gonna dello stesso colore della giacca (`persona-18-color-pelle-scartato.jpg`).
- `WornGarment.mask` (estratta da `extract`, zone colore in `ColorZones`): bordo arrotondato (`Morphology.smoothed`) e ciocche di
  capelli dentro il profilo del capo tenute, se la testa è nella foto. Sul banco i ritagli cambiano poco. Cache `capo2`.
- Limite che resta: è un collage, il capo non prende la forma del corpo e sopra restano i vestiti della foto.

**Usabilità** (dalle 33 schermate dell'ultimo giro e dal codice):
- Consiglio «già indossato»: solo i sette giorni prima, mai il giorno stesso (compariva sull'outfit appena registrato e anche per
  capi messi mesi fa) e con i nomi dei capi: «Di recente hai già messo Jeans chiari (9 nov 2026)».
- Statistiche: «Dimenticati nell'armadio» non ripete «I più indossati».
- Guardaroba vuoto: una riga che dice come aggiungere un capo e a cosa serve, anche nella scheda Outfit.

**Verifiche del 10/11** (Mac a carico 300-900 per le altre sessioni, quindi in più passate):
- Core 212/212 (`swift test`). Test dell'app 226 passati.
- Suite UI iPhone: 53 test, tutti passati ma non in una sola esecuzione. In `round-12b` 50 su 53; i tre caduti su attese
  scadute (`testIlProfiloHaLeTreFoto…`, `testLaSegnalazioneBloccaIDatiSensibili…` con «main thread busy for 30s»,
  `testPosizioneNegataRestaSullaCitta`) rifatti da soli in `round-12c`: 3 su 3.
- Giri da utente da installazione pulita, 33 schermate: Duo, italiano chiaro, inglese, italiano scuro. Guardati i fogli:
  suggerimento nel guardaroba vuoto (it, en, scuro), niente «già messo» sull'outfit appena indossato, «Dimenticati» senza ripetizioni.
- Il giro scuro è caduto due volte al salvataggio del quarto capo (il foglio «aggiungi» resta aperto dopo «Salva», app che
  risponde) ed è passato alla terza. Causa non vista: lo script ora scatta `salva-non-chiude-N` se ricapita. Ipotesi: tocco sulla
  categoria andato a vuoto mentre il modulo scorre, quindi errore «categoria mancante». Se ricapita, guardare quella schermata.
- Nessun crash nei DiagnosticReports. Non provato: telefono vero, iPad, nessuna build nuova.
- `tools/avatar-fashn/bench/` (app «Fashn Bench» della misura) è nel repo per i prossimi passi; i modelli restano in `out/`,
  fuori da git. L'app di prova è ancora installata sull'iPhone di Lorenzo.

**Calore di partenza (corretto la sera del 10/11):** un capo nuovo partiva sempre con calore 2, anche un cappotto: chi non
toccava i pallini riceveva «Troppo leggero per 12°: aggiungi uno strato» con il cappotto addosso, e proposte peggiori col freddo.
- Ora `Catalog.defaultWarmth(category:subcategory:)` (Core) dà il punto di partenza sulla scala di `warmthTarget`: cappotto e
  piumino 5, maglione, felpa, giacca e stivali 4, jeans e sneakers 3, canotta, shorts e sandali 1; senza tipo vale la categoria
  (capispalla 4, pantaloni e scarpe 3, il resto 2).
- `ItemFormModel.warmthLevel` segue il tipo finché non si sceglie a mano; in modifica resta il valore salvato. I capi già nel
  guardaroba non cambiano: chi ha cappotti a 2 li corregge dalla scheda del capo.
- `round-13`, dopo la correzione: Core 216/216; suite iPhone 229 + 53 passati in una sola esecuzione; giri chiaro, scuro,
  inglese passati al primo colpo; Duo caduto su un'attesa (`profile-temperature`, carico 560-650) e passato rifatto. Sui fogli
  `foglio-r13-4`: stesso guardaroba, a 12° niente più «Troppo leggero», punteggio da 60 a 73. Nessun crash. Non sul telefono vero.

**TestFlight, letto il 10/11:** build 10 «Pronta per l'invio», gruppo «Lorenzo e Marianna», 1 installazione; anche la 9 ha il gruppo.

## Novità 2026-11-09 (sera) — Build 1.0 (10) caricata

Con l'ok di Lorenzo («Sì, caricala»). Caricata alle 19:48 (`build10.sh`, `upload10.sh` in `.superpowers/sdd/rc/`), numero di build in
`0ed77e1`. Dentro c'è l'avatar con solo il capo indossato (`575e10e`, sezione qui sotto).
- IPA controllata: 1.0 (10), "Style Vault", Apple Distribution, WeatherKit, CloudKit e push in Production, PrivacyInfo, nessuna copia " 2",
  nessun argomento `-SV`, niente Open-Meteo, nessuna eccezione ATS; `WornGarment` presente nei simboli dell'archivio.
- Non provato: sul telefono vero, la prova la fa Lorenzo da TestFlight. Da provare: un capo fotografato addosso a qualcuno (foto da negozio
  o per strada) deve comparire sull'avatar senza viso, braccia e sfondo, steso su spalle e fianchi.

## Novità 2026-11-09 — Sull'avatar solo il capo indossato, allineato al corpo

Screenshot di Lorenzo dalla build 9: maglia da negozio (modella tagliata sotto il mento) e foto a figura intera (gilet e pantaloni) finivano
sull'avatar come rettangoli con la persona intera, testa e braccia comprese. Sue parole: le foto «hanno un campo bianco dietro, lui lo ha
tolto ma non deve rimanere piatta la foto». Commit `575e10e`.
- `WornGarment` (Core, `Avatar/`): se nella foto del capo c'è una persona (`VNDetectHumanRectanglesRequest`), tiene solo il capo del posto:
  zone colore (k-means in Lab) prese sul petto per maglia e vestito, sulle maniche per la giacca (aperta mostra la pancia), sulle cosce per i
  pantaloni, sotto le caviglie per le scarpe; tolti pelle (colore del naso) e capelli (colore in testa), tranne se sono il colore principale
  del capo; righe limitate dal colletto all'orlo; solo le parti collegate, buchi chiusi, bordo sfumato.
- Allineamento (`GarmentLayout.wornTransform`): spalle e fianchi della foto su spalle e fianchi dell'avatar (pantaloni: fianchi e caviglie,
  o ginocchia), larghezza tenuta entro un terzo dell'altezza. Di lato, o senza posa (foto da negozio senza testa), vale il riquadro di prima
  con il solo capo. Senza persona nella foto non cambia nulla.
- Cache: `CutoutCache.piece`, file `<capo>-<posto>-capo1.png` + `.posa`, o `.nessuno` se il capo va intero. Il ritaglio lavora a 1600 px
  (circa 25 byte per pixel).
- Prove: pacchetto 201 su 201 (13 test nuovi senza Vision, 4 con Vision e due foto Unsplash). Banco del Mac su 16 foto di capi indossati e
  10 capi da soli: i capi da soli restano interi (giacca appesa, bomber tenuto in mano, gruccia, stivali); gli avatar prima e dopo sono in
  `docs/verifiche/2026-11-09-capo-indossato/`.
- Limiti: braccia incrociate davanti alla maglia lasciano un buco; capelli lunghi sul petto dello stesso colore della gonna restano; scarpe
  prese da una foto indossata portano l'orlo dei pantaloni se è dello stesso colore; maglia e pantaloni dello stesso colore non si separano
  bene; i vestiti della foto del corpo restano visibili dove il capo nuovo non copre. Il capo esatto addosso lo dà solo "Prova con ChatGPT o
  Gemini". Vale anche per i capi già nel guardaroba: il ritaglio si fa alla prima apertura dell'avatar.
- Simulatore, dopo il riavvio del Mac (`.superpowers/sdd/rc/round-10.sh` e `round-10b.sh`): suite iPhone 53/53 e giri da installazione nuova in chiaro (`r10b`), scuro (`r10d`), inglese (`r10be`) e su iPhone Duo (`duo10`) passati, 33 schermate ciascuno, nessun crash. Al primo passaggio tre parti erano cadute per tempo con il Mac a carico 215-440 e quattro simulatori di altre sessioni accesi (segnalazione, primo tocco nel campo nome, foglio che non si chiudeva in 30 s): rifatte uguali, passate. La schermata «Vedilo addosso» è identica pixel per pixel a quella della build 9 (nel simulatore c'è il corpo finto).
- Non provato: sul telefono vero, l'unico posto dove gira Vision. Serve la build 1.0 (10).

## Novità 2026-11-08 (sera) — Build 1.0 (9) caricata

Con l'ok di Lorenzo («Sì»). Caricata alle 21:49, va in TestFlight dopo l'elaborazione di Apple. Dentro c'è lo scontorno dei capi senza gli
oggetti tagliati dal bordo (`f8a9bef`, sezione qui sotto); numero di build in `7e99dc3`.
- IPA controllata: 1.0 (9), "Style Vault", Apple Distribution, WeatherKit, CloudKit e push in Production, PrivacyInfo, nessuna copia " 2",
  nessun argomento `-SV`, niente Open-Meteo, nessuna eccezione ATS; `garmentInstances` presente nei simboli dell'archivio.
- Suite iPad 279 su 279 sul codice della 9 (09/11), nessun crash. Non provato: la correzione sul telefono vero, la prova la fa Lorenzo da TestFlight.

## Novità 2026-11-08 (sera) — Secondo giro di scontorno: selfie allo specchio, foto da iPhone, accessori

Richiesta di Lorenzo: «Fai altre simulazioni e dimmi che trovi e correggilo». 15 capi e 10 persone nuovi da Unsplash, con lo stesso banco
del Mac del primo giro, più le foto come le salva l'iPhone (pixel coricati con orientamento EXIF 6, JPEG e HEIC). Programmi, esiti e
immagini: `docs/verifiche/2026-11-08-scontorno-sfondi-2/`.
- Trovato e corretto: per i capi l'app teneva tutti i soggetti di Vision, quindi occhiali sul tavolo uscivano con la tazzina e la tazza
  tagliate dal bordo. Ora `PersonCutout.garmentInstances`: se un soggetto sta tutto dentro la foto, si scartano quelli che toccano almeno
  due lati. Usata da `GarmentImage.cutout` e dall'avatar. Su 27 capi cambia solo quella foto; collana a tre fili e paio di stivali restano
  interi. Test: `testQualiSoggettiTieneUnCapo` con i lati misurati e `testCapoSenzaGliOggettiTagliatiDalBordo` (fixture
  `capo-occhiali-tazza.jpg`). Pacchetto 184 su 184. I capi già scontornati restano come sono: vale per le foto nuove.
- Provato e già giusto: foto da iPhone dritte sia JPEG sia HEIC, e la foto del corpo passa il controllo; selfie allo specchio intero
  accettato e avatar buono; gli altri selfie allo specchio e le foto con i piedi tagliati rifiutati come "non a figura intera" (giusto: i
  piedi non si vedono); seduta rifiutata. Capi singoli puliti anche bianchi e neri: occhiali su bianco, jeans, stivale, top nero
  nell'armadio, vestito su muro con ghirlande.
- Limiti rimasti, da dire a Mary: capo indossato da una persona (esce la persona intera, viso compreso), collana indossata (nessun
  soggetto, resta la foto), più camicie sullo stesso appendiabiti (blocco unico), gruccia attaccata al vestito, jeans piegati (l'avatar li
  incolla piegati).
- Dopo la correzione: suite iPhone passata; giri da installazione pulita in chiaro, scuro, inglese e su iPhone Duo passati, 33 schermate
  ciascuno, tutte viste, nessun crash. Non provati: suite iPad, la correzione su un telefono vero (serve una build 1.0 (9)).

## Novità 2026-11-08 — Build 1.0 (8) caricata

Con l'ok di Lorenzo («Sì, prepara la 8»). Caricata alle 17:39, va in TestFlight dopo l'elaborazione di Apple. Dentro c'è la correzione del passante sullo sfondo (`7120012`); numero di build in `678a7c9`.
- IPA controllata: 1.0 (8), "Style Vault", Apple Distribution, WeatherKit, CloudKit e push in Production, PrivacyInfo, nessuna copia " 2",
  nessun argomento `-SV`, niente Open-Meteo, nessuna eccezione ATS.
- Prove: quelle della correzione qui sotto (suite iPhone, quattro giri da zero). Suite iPad non rifatta.
- Non provato: la foto del corpo con un passante sul telefono vero. Prossimo passo per Lorenzo e Mary: aggiornare da TestFlight e riprovare
  scontorno e foto del corpo.

## Novità 2026-11-08 — Scontorno provato con sfondi complessi

Richiesta di Lorenzo mentre Mary non risponde. 12 foto di capi e 10 di persone da Unsplash (letti, strade, tavolini, appendiabiti),
passate alle stesse funzioni dell'app (`GarmentImage.prepared` + `cutout`, `BodyPhotoAnalyzer.analyze`, `AvatarRenderer.render`) con Vision
vero sul Mac, tramite un piccolo programma che usa `StyleVaultCore`. Fogli, esiti e programma: `docs/verifiche/2026-11-08-scontorno-sfondi/`.
- Capi: un capo da solo si scontorna bene anche su sfondo pieno (giacca su porta, borsa al bar con strada dietro, scarpe sul parquet, bomber
  tenuto in mano: la mano sparisce). Restano gruccia, gancio o sedia quando toccano il capo. Più capi vicini (flat lay, appendiabiti, stender)
  escono come un blocco unico. Letto disordinato con tanti oggetti: nessun soggetto, l'app mostra la foto originale.
- Persone: scontorno pulito in tutte, anche in controluce e su muro dipinto. Foto di spalle riconosciuta. Bastava un passante piccolo sullo
  sfondo per "più persone" (`people > 1` in `BodyPhotosModel.validate`): corretto con l'ok di Lorenzo («Sì, correggi qui»), vedi sotto.
- Correzione del passante: `PersonCutout.peopleCount` conta solo chi è alto almeno metà della persona principale (`backgroundPersonRatio` 0,5).
  Altezze misurate: passante 0,30 accanto a 0,93; coppia 0,53 accanto a 0,61, che resta "più persone". Test: `countedPeople` con i numeri
  misurati e due foto vere ridotte a 1024 (`Fixtures/persona-passante.jpg`, `persona-coppia.jpg`, Unsplash). Pacchetto 182 su 182.
  - Sul banco del Mac la foto col passante ora non dà più "più persone" ma "non a figura intera": la posa non trova le caviglie (gambe tagliate
    dal fotogramma). È la regola della posa già esistente, lasciata com'è.
  - Suite iPhone passata. Giri da installazione pulita: scuro, inglese e iPhone Duo passati, 33 schermate ciascuno, tutte viste. Il chiaro si è
    fermato al primo capo, foglio ancora aperto dopo Salva, con il Mac a carico 100: è la seconda volta (anche nella build 7). `save()` chiude
    solo con nome e categoria validi, quindi è perso il tocco su Salva o quello sulla categoria; l'app si comporta bene. Rifatto da zero, passato, 33 schermate viste.
  - Entra nella build 1.0 (8); la 7 conta ancora i passanti. Suite iPad non rifatta (la correzione è nel pacchetto, non nelle viste).
- Avatar: buono con un capo fotografato bene (bomber); con un capo scontornato male (camicia con gruccia e camicie vicine) l'avatar incolla il
  blocco intero.
- Non provato: lo stesso sull'iPhone (Vision del Mac, non del telefono) e la build 7 nelle mani di Mary.

## Novità 2026-11-08 — Build 1.0 (7) caricata

Con l'ok di Lorenzo («Fai tutto insieme»). Caricata su App Store Connect alle 13:41: va in TestFlight al gruppo interno dopo l'elaborazione di Apple.
- Dentro: nome "Style Vault", icona nuova (gruccia e "SV", varianti scura e tinta, generatore in `tools/icona/icon.swift`), scontorno nelle
  schede e negli outfit, meteo e ricerca delle città solo da Apple. Commit `073a127`.
- IPA controllata: 1.0 (7), Apple Distribution, WeatherKit, CloudKit in Production, PrivacyInfo, nessuna copia " 2", nessun `-SV`, niente Open-Meteo.
- Prove sul codice della build:
  - Suite iPhone 279 su 279. Suite iPad 278 su 279: `testIlBloccoCopreIlFoglioAggiungi` falliva anche a Mac scarico.
  - Il video del test mostra il tocco sintetico dentro l'interruttore, che non si muove: tocco perso dal simulatore iPad, è la causa di
    `testBloccoConAutenticatoreFinto` annotata il 05/11. Il test ora ritocca dopo 10 secondi: i due test del blocco 10 su 10, con un tocco perso
    e ripreso. Commit `ad3c0e8`.
  - Giri da utente da installazione pulita, 33 schermate ciascuno, tutte viste: chiaro, scuro, inglese, iPhone Duo. Il chiaro era scaduto al
    terzo capo (foglio non chiuso dopo Salva) con il Mac a carico 300; rifatto da zero, passato.
- Non provato: lo scontorno vero con Vision su questa versione (serve il telefono), l'icona tinta sulla Home.
- Prossimi passi per Lorenzo: provarla e farla provare a Mary, scontorno compreso; controllare il nome della scheda in App Store Connect.

## Novità 2026-11-08 — Scontorno visibile nelle schede

Mary: «ancora non scontorna». Causa probabile, letta dal codice e non vista sul suo telefono: l'app scontornava, ma griglia, outfit,
calendario e statistiche mostravano sempre la foto originale. Lo scontorno compariva solo come terza pagina del dettaglio, come nel
sito, dove serviva solo all'avatar. In più i capi senza scontorno, perché l'app era stata chiusa prima della fine o perché importati,
non venivano mai ripresi. Vision sul telefono funziona: il 03/11 l'avatar aveva scontornato i capi sull'iPhone di Lorenzo.
- Correzione:
  - `Item.shownPhoto` (scontorno, se no foto) nelle schede e negli outfit; il dettaglio apre ancora sulla foto originale.
  - `CutoutWorker.enqueueMissing()` all'avvio e dopo un'importazione; un capo in cui Vision non trova nulla non si riprova nella stessa sessione.
  - Fondo `Palette.studio`, chiaro anche in modalità scura, dietro le immagini con trasparenza.
  - Seme di prova `-SVSeedCutout`, solo DEBUG.
- Verifica:
  - Suite iPhone 279 su 279, compresi i 4 test nuovi del worker. iPad non rifatto.
  - Griglia in modalità scura vista sul simulatore: `docs/verifiche/2026-11-08-scontorno/griglia-scuro.png`.
  - Non visto con Vision vero sul telefono: i test del pacchetto non girano su un iPhone vero senza un'app che li ospiti.
- Entrato nella build 1.0 (7).

## Novità 2026-11-08 — Nome "Style Vault"

Richiesta di Lorenzo. Sul ramo locale, **non ancora in una build**: sulla Home e in tutti i testi dell'app ora c'è "Style Vault" (era "SV Nativa" sulla Home e "StyleVault" nei testi): `project.yml`, `Info.plist`, `InfoPlist.xcstrings`, 16 testi di `Localizable.xcstrings`, login, oggetto della mail, testi legali rigenerati da `testi-legali.md`. Identificativi, container iCloud e nomi dei file di esportazione restano "StyleVault".
Prove: suite iPhone 275 su 275, test del guardaroba su iPad 19 su 19, nome visto sulla Home del simulatore. Il primo lancio dopo il riavvio del Mac era 273 su 275: un'app che non partiva, con il Mac carico, e un tocco a vuoto del test. Lo scorrimento di `WardrobeFlowTests` continuava per inerzia e il chip della categoria finiva sotto l'intestazione del foglio; ora scorre lento, aspetta che si fermi e controlla l'intestazione. È probabilmente anche la causa di `testNuovaCategoria` del 07/11, che non è stata verificata.
Entrato nella build 1.0 (7).

## Novità 2026-11-07 (sera) — Open-Meteo tolto

Richiesta di Lorenzo dopo la conferma del meteo di Apple sul telefono. Sul ramo locale, **non ancora in una build**: la 1.0 (6) su TestFlight usa ancora Open-Meteo come ripiego.
- Meteo: Apple, poi ultima previsione salvata da Apple, poi errore e impostazione a mano. L'outfit non si blocca. Una previsione salvata da un altro servizio non si mostra più.
- Città: `Profile/AppleCitySearch.swift`, con `MKLocalSearchCompleter` e risoluzione dei primi 6 suggerimenti: il solo `MKLocalSearch` dava un risultato e rendeva irraggiungibili gli omonimi. Apple limita le richieste: oltre 50 in pochi secondi dà liste vuote per un po'.
- Testi: privacy, supporto, schermate legali e crediti non nominano più Open-Meteo. Nei documenti storici il nome resta.
- Prove sul codice definitivo: Core 179 verdi, iPad 275 su 275. iPhone 265 su 275 al primo lancio, 275 su 275 al secondo: nel primo, Arrivo, l'app di un'altra sessione, è entrata sullo stesso simulatore e compare in 8 dei 10 test rossi. `testSalvaIndossaEVedeTuttoNelCalendarioENelleStatistiche` e `testNuovaCategoria` non la mostrano nel log e non sono spiegati: sono passati al secondo lancio.
- Non fatto: giri da utente da rifare da zero, schermata di ricerca usata a mano, telefono, iOS 17, testi legali da far rileggere a Lorenzo, voce `CoarseLocation` del manifest da rivedere.

## Novità 2026-11-07 — RC 1.0 (6) caricata

Caricata il 07/11 alle 16:07 dal commit `99048c5`; alle 16:20 App Store Connect la dà pronta nel gruppo "Lorenzo e Marianna", nessuna installazione. Prove: iPhone e iPad 272 su 272, giri in chiaro, scuro, inglese e iPhone Duo passati, 33 schermate
ciascuno, tutte viste. Un difetto corretto: contrasto di titoli, note e segnaposto nei moduli di sistema. Verbale: `docs/verifiche/2026-11-07-bozza-completa/giro.md`.
Il gruppo interno ha la distribuzione automatica: la build 6 è "Test in corso", già disponibile a Mary, che al controllo aveva ancora la 1.0 (5). Lorenzo risulta "Invitato", invito non ancora accettato.
Prova di Lorenzo sul telefono: il credito dice ancora Open-Meteo. Sul portale Apple WeatherKit era attivo in Capabilities ma spento in App Services dell'App ID `it.faraoni.stylevault.nativa`: acceso il 07/11 alle 16:29, con l'ok di Lorenzo. Provato alle 18:24 sulla build 6 da TestFlight: risponde Apple, confermato anche da Lorenzo. Non è servita una nuova build, ma l'app va riaperta: restava in memoria la previsione delle 16:26, e tornando dallo sfondo sulla stessa scheda il meteo probabilmente non si ricarica (letto dal codice, non provato). L'app nasconde l'errore di WeatherKit (`try?` in `WeatherLoader`). Sul telefono di Mary non è verificato. I profili di firma dell'App ID vanno rigenerati: li rifà Xcode alla prossima build.
Da rivedere: nome sulla Home solo "Style Vault" (oggi "SV Nativa") e icona.
IPA controllata: 1.0 (6), Apple Distribution, WeatherKit, PrivacyInfo, nessuna copia numerata, argomenti `-SV` solo in `#if DEBUG`.
Da chiedere a Lorenzo: Mail di ripiego e storico dei capi cancellati, testi legali da leggere. `Web (Apps)` dentro `Apps Mobile 📱` è voluto: confermato il 07/11.
Copie numerate: `~/Documents` è su iCloud Drive, e con i file rigenerati nascono doppioni (`Info 3.plist`, `TempGiroTests 2.swift`, 21 copie di `StyleVault.xcodeproj`).
Il primo `xcodebuild archive` è uscito senza errori nel log, dopo 2 righe; il secondo è passato. Causa non trovata.

## Novità 2026-11-07 — RC 1.0 (6), prove da finire (superata dalla sezione sopra)

Il progetto ora sta in `/Users/lorenzofaraoni/Documents/Apps Mobile 📱/StyleVault`. Ramo `feat/app-nativa`, solo commit locali.
Fatto sul ramo: correzioni della revisione, `stamp` e `DuplicateStore`, storico dei capi cancellati con `snapshot`, import più robusto, date gregoriane,
Mail per chi segnala senza account, privacy e supporto dentro l'app (`scripts/testi-legali.py` genera schermate e `docs/pubblicazione/pagine/` da `testi-legali.md`),
Meteo di Apple con ripiego su Open-Meteo (tolto la sera del 07/11, vedi sopra), build 6 in `project.yml`. Report pre-invio: `docs/pubblicazione/2026-11-07-report-rc.md`.
**Non fatto:** build 6 non caricata; suite complete e giri fermati prima di dare un esito sul codice finale. Su Mary c'è ancora la 1.0 (5).
Strumenti: `.superpowers/sdd/rc/` (ignorata da git): `round-rc.sh` fa suite iPhone e iPad e giri chiaro, scuro, inglese e iPhone Duo; `build6.sh` archivia ed esporta.
`TempGiroTests.swift` viene copiato e tolto da `giro6.sh`, mai nel commit.

## Novità 2026-11-07 — Revisione esterna del ramo

Sul ramo locale, non ancora in una build: correzioni dalla revisione (crash doppioni, crash viso a bordo foto, meteo vecchio, cache
scontorni, esporta e importa a blocchi, testo "Elimina account", manifest privacy). Esito in `docs/verifiche/2026-11-07-bozza-completa/giro.md`.
Decisioni e minori rimandati sono solo in `.superpowers/sdd/2026-11-05-app-nativa-fase-2/progress.md`, cartella ignorata da git: non cancellarla prima di averli riportati.
Prima di portare lo schema CloudKit in Production: campo per scegliere la stessa copia sui doppioni, poi pulizia per id; fissare `VersionedSchema`; revoca token Apple.
Da decidere con Lorenzo: Mail come ripiego per chi segnala senza account, comportamento dello storico dei capi cancellati.

## Novità 2026-11-07 — Build 1.0 (5) caricata per Mary

Caricata il 07/11 alle 02:04 dal commit `e5003bb`; App Store Connect la dà pronta nel gruppo "Lorenzo e Marianna", 2 inviti, nessuna installazione alle 02:10. Verbale, screenshot e cosa non è provato: `docs/verifiche/2026-11-07-bozza-completa/giro.md`.
Giro pulito in italiano chiaro, italiano scuro e inglese; un difetto trovato e corretto (spazio prima dei due punti in Armocromia).
Per Mary: i capi del sito non ci sono finché Lorenzo non lancia lo script e lei importa lo zip (`docs/pubblicazione/portare-i-dati-di-mary.md`).
Il giro temporaneo sta nello scratchpad della sessione: se serve di nuovo, va riscritto (`TempGiroTests` + `giro5.sh`), senza metterlo nel commit.

## Novità 2026-11-06 — Ibrida e sito fuori dal repository

Sul ramo `claude/togli-ibrida-e-sito-5d8100`, non fuso: nel repository restano `StyleVaultNative`, `StyleVaultCore`,
`supabase/` e `keepalive.yml`. Il resto è nel tag locale `archivio-ibrida-e-sito`; cosa recuperare per le fasi 5, 6 e 7 è
elencato nel design (decisione 9). Testi legali in `docs/pubblicazione/testi-legali.md`. `Localizable.xcstrings` ora si
modifica direttamente. Il sito resta online finché Lorenzo non pubblica; prima dell'App Store privacy e supporto hanno
bisogno di una nuova sede.

## Novità 2026-11-05 (notte) — Login nella nativa, percorso minimo

Decisione di Lorenzo: la nativa ha Accedi con Apple, Google, email e password, password dimenticata. I dati
restano su iCloud e l'account non li sposta. Rovescia la decisione 7 del design (vedi decisione 8).
- Codice in `ios/StyleVaultNative/Auth/`; `AuthService` è condiviso con l'ibrida. Schema `svnativa://`.
- "Continua senza account" sotto il login: Apple 5.1.1(v) vieta il login obbligatorio se le funzioni non
  dipendono dall'account. Da confermare con Lorenzo.
- Supabase: `svnativa://**` nei Redirect URLs e `it.faraoni.stylevault.nativa` nei Client IDs di Apple, verificati.
- Il tasto Google compare solo col provider attivo: manca che Lorenzo incolli ID e segreto in Supabase, poi utenti
  di prova o pubblicazione della schermata OAuth.
- Non provato: accessi veri (Apple, Google, email), reset vero, cancellazione account, Release su dispositivo.
- Test: iPhone 151, iPad 151 e ibrida 143 verdi. Su iPad 9 test del guardaroba fallivano sempre, anche a carico 40: sul
  simulatore lento il test toccava mentre la tastiera spostava il foglio. Corretto il test con `waitForKeyboard`
  (15 su 15), l'app non cambia: a mano il capo si salva. Il carico intanto era sceso, quindi il merito può essere
  in parte suo. Swap pieno (23 GB) e 4 simulatori accesi rallentano tutto.
- Build 1.0 (2) caricata il 2026-11-06 alle 08:33 con l'ok di Lorenzo ("Upload succeeded", commit `5d79ad5`). La
  distribuzione automatica del gruppo "Lorenzo e Marianna" la manda anche a Marianna. Verificato su App Store
  Connect: elaborata entro le 08:35, stato "Pronta per l'invio", gruppo con 2 tester e 2 build. Alle 08:35 Lorenzo
  e Marianna risultavano ancora "Invitato", senza sessioni né dispositivi: invito non ancora accettato o dato non
  aggiornato. IPA controllata: diritti di produzione, Apple attivo, nessun avanzo di prova.
- Build 1.0 (3) caricata il 2026-11-06 alle 12:41 con l'ok di Lorenzo ("Upload succeeded", commit `2a965f5`), con le
  correzioni del giro da utente sul simulatore: griglia, categoria doppia, pallini, riquadro dei campi (`FieldBox`), tema
  nel login, invio nel login, colori (`Palette.link`), errore Apple col codice, "Registrati" in evidenza, "Esci e vai
  all'accesso" nel Profilo per chi è senza account ("Esci" per chi ha l'account c'era già). Verificato su App Store
  Connect alle 12:46: elaborata, "Pronta per l'invio", nel gruppo con 2 inviti, ancora nessuna installazione.
- Test prima dell'upload: iPhone verdi (29 UI), ibrida 144. iPad: 28 su 29 UI nella suite completa; il test del
  login cercava la tastiera a schermo e falliva sempre: corretto con `waitForFocus`, poi 5 su 5, ma la suite iPad
  intera non è stata rifatta dopo. A mano su iPad il tocco sul bordo apre la tastiera. `testGiroCompleto` è fallito una
  volta a load 136 (app occupata 21 secondi dopo il tocco, poi niente fuoco) e poi 6 su 6: causa non determinata.
- Marianna (06/11): dice che Accedi con Apple non va e che non vede Registrati. Non visto a schermo. Su App Store Connect
  la build 2 non risulta installata da nessuno (dato forse in ritardo). La build 1.0 (1) non ha login. Ipotesi aperte:
  build vecchia, password dell'Account Apple rifiutata da iOS o dal download, "Continua senza account" già toccato
  (dopo il login non ricompare). Servono il numero di versione in TestFlight e una foto della schermata.
- Marianna, esito (06/11, ore 14:47, da App Store Connect e log di Supabase): ha installato la 1.0 (3) su iPhone 15 Pro
  con iOS 27.2 ed è entrata con Apple dall'app nativa, creando un account nuovo con email nascosta da Apple
  (`user_signedup`, id `6fffc5aa`). Resta separato dal suo account precedente "Marianna" (`3c113b1f`). Non si è visto cosa ha
  fatto dopo. Giro sul simulatore da installazione pulita: Registrati, campi vuoti, tastiera aperta, senza account ed
  "Esci e vai all'accesso" funzionano; registrazione vera e tasto Apple non provati lì. Su Supabase "Confirm email" è
  spento: chi si registra entra subito, quindi non serve un messaggio "controlla la posta".
- Sito: consiglio della foto in costume nella prova virtuale (commit `0da8b7f`), non pubblicato né visto a schermo.
- Outfit e Calendario nativi (06/11, fasi 3 e 4 del design): tolto "In arrivo" dalle due schede, statistiche nel Profilo,
  logica portata in `StyleVaultCore` con i casi del sito e il confronto `harmony-parity.json`. Build 1.0 (4) per Marianna caricata
  il 06/11 alle 17:26 dal commit `07425e7`, dopo un giro da utente pulito da installazione nuova (tre passate, le prime due con
  correzioni). Suite iPhone verde; suite iPad 37 su 39 al primo lancio con il Mac a carico 300, i due test rossi
  (`testBloccoConAutenticatoreFinto`, `testGiroCompleto`) poi verdi 3 su 3 da soli. Lasciati come il sito: stesso outfit assegnabile
  due volte allo stesso giorno, giorno futuro segnabile come indossato. Niente "Prova": arriva con la fase 6. Meteo da Open-Meteo con coordinate a 2 decimali; la
  posizione si chiede solo dal tasto, dopo la spiegazione; senza si usa la città del Profilo.
- Foto del corpo e "Vedilo addosso" (06/11 sera): Mary segnalava "non crea l'outfit" perché nella nativa mancava la foto di sé. Ora
  "Le tue foto" è in cima al Profilo (3 viste, sostituibili e cancellabili, foglio `BodyPhotoEditorView`), e ogni scheda outfit
  ha "Vedilo addosso" (`AvatarView`). Logica in `StyleVaultCore/Avatar`, portata dal tag senza il realistico: i test girano sul Mac con
  Vision vera, nel simulatore analisi e composizione sono finte con `-SVFakeBody`. Abito con posto proprio (`dress`). Fuori per ora:
  Prompt AI, prova da Calendario e dal dettaglio. Il collage non è un'immagine generata: niente etichetta IA, resta la dichiarazione
  sulle foto. Motore: outfit anche con soli capispalla o categorie create a mano; meteo si arrende dopo 10 secondi.
- Ramo `claude/togli-ibrida-e-sito-5d8100` fuso in `feat/app-nativa` il 06/11 su richiesta di Lorenzo (`98d5989`), nessun push.
- Decisione di Lorenzo (06/11): il meteo passerà a quello di iPhone (WeatherKit). Non in questa build: per Marianna resta
  Open-Meteo. Il passaggio tocca `Outfit/ForecastLoader.swift` dietro `ForecastLoading`, e poi tolgono Open-Meteo da citazione,
  Privacy Labels, privacy policy e `PrivacyInfo.xcprivacy` (la `Coarse Location` va rivista).
- Da fare nei prossimi passi, prima dell'App Store (Lorenzo, 06/11): provare l'app su iPhone Duo, il pieghevole. Oggi non è mai
  stata aperta lì. Simulatore già presente: `iPhone Duo` `854E881E-D9B4-46B7-94AE-B670F95DBE1C`, runtime iOS 27.2 `24B91016s`.
  Da guardare: schermo esterno e interno, passaggio da chiuso ad aperto con i dati ancora a posto, Split View. Su iPhone l'app è
  bloccata in verticale, ma Apple dice che lo schermo interno non rispetta gli orientamenti dichiarati, quindi lì può ruotare.
  A favore: il codice usa le size class e non `UIScreen.main` né `userInterfaceIdiom`; Xcode 27.2 copre già l'SDK 27.1 richiesto.
- Decisione di Lorenzo (06/11): si segue sempre la skill `mobile-app-publishing`, giro da utente compreso, e si tolgono dal
  repository ibrida e sito. Lo fa una sessione a parte sul suo ramo, con tag `archivio-ibrida-e-sito`; la fusione la decide
  Lorenzo e il sito resta online finché non pubblica lui. Supabase e `keepalive.yml` per ora restano: account della nativa e dati
  di Lorenzo e Marianna. Se pulire anche Supabase lo si decide più avanti con Lorenzo. Per Android si esportano i dati
  direttamente, senza complicazioni, con un pulsante nel Profilo non ancora costruito.
- `Info 2.plist` e `StyleVaultNative 2.entitlements` sono vecchie copie non tracciate: escluse in `project.yml`, non
  cancellate.
- Prima dell'App Store: `/privacy` e `/supporto` rispondono 404 (si vedono solo grazie a 404.html), mittente delle
  email di reset, revoca del token Apple, account demo, Privacy Labels.

## Novità 2026-11-05 (sera) — Nativa, fase 2 Guardaroba (ramo `feat/app-nativa`, solo locale)

Piano: `docs/superpowers/plans/2026-11-05-app-nativa-fase-2.md`, eseguito in sessione, senza subagent.
- Fatti Task 1-9: filtri, prezzo, testi dei link, foto e scontorno in `StyleVaultCore`; `WardrobeStore`,
  `CustomCategoryStore`, `CutoutWorker`; modulo con foto e link; lista, dettaglio, wishlist, categorie
  personalizzate. Viste in `ios/StyleVaultNative/Wardrobe/`.
- **Manca il Task 10, la prova con Lorenzo su iPhone e iPad.** Lo scontorno gira solo su dispositivo
  (Vision non va nel simulatore), e fotocamera, link veri e foto su iCloud non sono mai stati provati.
- Spostati: doppioni di `BodyPhoto` e tasto "Prova outfit" alla fase 6, `setArmocromia` alla fase 5,
  scheda di uso del capo alla fase 4. Il piano spiega perché.
- Attenzione: `LocalizedStringKey("testo.\(x)")` cerca la chiave con `%lld`, non quella col valore.
  La chiave va costruita prima in una `String` (vedi `Text.warmth`).
- Giro da utente sul simulatore fatto (skill `mobile-app-publishing`): 4 giri, ultimo pulito su iPhone e
  iPad, 8 difetti corretti, commit `0793051`. Verbale e schermate in
  `docs/verifiche/2026-11-05-nativa-fase-2/`. Test: Core 27, iPhone 140, iPad 140. Release controllata con
  `strings`: nessun avanzo di prova, nessun segreto. App reinstallata su iPhone e iPad di Lorenzo.
- Prima di pubblicare (fase 8) manca `PrivacyInfo.xcprivacy` nel nativo: `UserDefaults` richiede la
  motivazione. Il nome sulla schermata è ancora "SV Nativa".
- `testBloccoConAutenticatoreFinto` è fallito 3 volte su iPad col Mac saturo, poi 20 su 20: causa non
  provata. Guardare se l'interruttore del blocco perde un tocco.
- TestFlight per Mary: app `StyleVault` in App Store Connect (id 6831314204, SKU `stylevault-nativa`, Bundle ID
  `it.faraoni.stylevault.nativa`, non più modificabile). Build 1.0 (1) caricata, scade fra 90 giorni. Gruppo
  interno "Lorenzo e Marianna" con distribuzione automatica; dentro c'è solo Lorenzo. Marianna è invitata
  come utente, ruolo Marketing, solo StyleVault: si aggiunge al gruppo dopo che accetta. Schema iCloud distribuito
  in produzione il 05/11 con il sì di Lorenzo: 7 tipi di record, da ora solo aggiunte. I dati di sviluppo non compaiono nelle build TestFlight. Lo schema si crea con
  `-SVInitCloudSchema` su dispositivo; con `devicectl` gli argomenti vanno dopo `--`. Ogni nuova build vuole
  `CFBundleVersion` più alto in `ios/StyleVaultNative/Info.plist`.
- Login dell'ibrida (05/11, richiesta di Lorenzo): Accedi con Apple scritto e attivo, nativo, Supabase con
  Client ID `it.faraoni.stylevault` e nessun segreto; installato sull'iPhone, mai provato col login vero.
  Google: codice pronto, progetto Google Cloud `stylevault-513821`, schermata di accesso in modalità test e
  client web creato. Manca il provider su Supabase con ID e segreto, che inserisce Lorenzo. In pausa: il
  05/11 Lorenzo ha dato la precedenza alla nativa.
- Login della nativa: Lorenzo l'ha chiesto il 05/11, rovescia la decisione 7 del design; da progettare,
  niente codice finché non approva il design.
- Nota per i test UI: `isHittable` è vero anche oltre il bordo dello schermo o sotto la tastiera; con la
  tastiera aperta il fine corsa dello scorrimento non la conta, e al primo ridisegno il contenuto torna
  indietro (lo spazio in `ItemFormView` è legato al `FocusState`).

## Novità 2026-11-05 — Apple Developer Program ATTIVO

Lorenzo è stato accettato: programma Individuale, Team ID `599MS2BZ63` (lo stesso
di prima, già in `ios/project.yml`), dati in `~/.claude/CLAUDE.md`. Sullo store il
venditore è il suo nome e cognome. Dispositivi registrati: 2, iPhone e iPad di
Lorenzo; il telefono di Mary non c'è.
- Verificato sul Mac: la sessione Vocali ha già ottenuto un profilo App Store che
  scade il 05/11/2027.
- **Il profilo attuale di StyleVault è ancora quello gratuito: scade l'11/11/2026.**
  Dopo quella data l'app non si apre, finché non la si reinstalla da Xcode.
- Sbloccati: fase 1 della nativa (CloudKit), TestFlight, WeatherKit.
- Da fare: app in App Store Connect, dichiarazione DSA.
- Il design ora contiene le correzioni dell'audit: l'import passa da Esporta e
  importa, l'app deve funzionare senza iCloud.
- Piano della fase 1 scritto: `docs/superpowers/plans/2026-11-05-app-nativa-fase-1.md`
  (9 task, ramo `feat/app-nativa`, solo locale). Esecuzione con subagent in corso:
  Task 1-8 chiusi: catalogo e ricerca città nel pacchetto `ios/StyleVaultCore`, target
  `StyleVaultNative`, modelli SwiftData, apertura dello store, Profilo unico, stato
  iCloud, tab, testi it/en, schermata Profilo. Suite verde su simulatore iPhone e iPad,
  mai provata su dispositivo vero. Il Task 9 si fa con Lorenzo: il primo build su
  dispositivo crea il container iCloud, che non si cancella.
- **Login valutato e scartato (2026-11-05):** Lorenzo ha chiesto Apple, Google e password nella
  nativa, poi ha deciso di no: i dati restano su iCloud, personali, e su App Store ognuno ha
  già i suoi. Al loro posto un blocco facoltativo con Face ID nel Profilo: Task 10 del piano
  fatto, provato solo su simulatore con un autenticatore finto (design, decisione 7).
- **Fase 1 chiusa il 2026-11-05.** Revisione finale fatta, due difetti corretti: un Profilo nuovo
  azzerava città e tema, l'avviso di iCloud pieno lampeggiava. Prova su iPhone e iPad veri passata:
  sincronizzazione, blocco con Face ID, rete, reinstallazione, avviso con iCloud spento. Esito, decisioni e rimandi: `docs/verifiche/2026-11-05-nativa-fase-1/prova-iphone-ipad.md`.
  Container `iCloud.it.faraoni.stylevault` creato. Ramo `feat/app-nativa` solo locale. Prossima: fase 2.
- App ibrida reinstallata sull'iPhone il 05/11 col team a pagamento: build Debug, profilo fino al
  05/11/2027. Debug carica il sito dal Mac (`vite --host` :5181, IP in `Secrets.xcconfig`). Xcode
  riusava il vecchio profilo gratuito finché non è stato tolto da `Provisioning Profiles`: il profilo
  della bench `it.faraoni.stylevault.bench` scade ancora l'11/11, ma non è usata.

## Novità 2026-11-05 (notte) — Prova tecnica FASHN VTON (branch `feat/app-ios`)

Lorenzo ha chiesto un modello locale open source al posto di Mobile-VTON, i cui
dati di addestramento sono solo ricerca. Candidato: **FASHN VTON v1.5**, Apache
2.0, 972 milioni di parametri, origine dei dati di addestramento NON dichiarata.
Parser escluso (licenza solo ricerca), non serve senza maschere.
- **Sul Mac M1 Pro funziona**: Core ML GPU, 30 passi (59 passaggi), fp16 1,8 GB
  in 3 min 40 s; 6 bit 704 MB in 4 min 26 s con Mac occupato, 38,3 dB dal fp16.
  Capo giusto; trecce irregolari, logo perso, trama leggera nel fondo a 6 bit.
- **NON provato su iPhone e iPad**: tempi e memoria ignoti. DWPose non convertito:
  le pose della prova vengono dal Mac. Manca il PSNR contro PyTorch (`guard.sh` lo
  ha fermato per lo swap).
- Tutto in `tools/avatar-fashn/` (README con numeri e confronto). Pesi e modelli
  fuori da git, nello scratchpad e in `out/`: un riavvio cancella lo scratchpad.
- **Sempre con `guard.sh`**: una generazione senza limiti ha fatto riavviare il Mac.
- **Deciso da Lorenzo (05/11): la prima versione nativa esce SENZA avatar
  realistico.** Scritto nel design (decisione 6): codice fuori dalla build, non
  nascosto; via download da 1,3 GB, entitlement di memoria ed E174.1. Può tornare
  in un aggiornamento col permesso di AImageLab o con FASHN. L'app ibrida non cambia.

## Novità 2026-11-03 (sera tardi) — FEEDBACK per email (branch `feat/app-ios`)

Richiesta di Lorenzo: sezione dove gli utenti segnalano difetti o idee, che
arrivano per email a lui; avviso chiaro di NON mettere contenuti sensibili.
Pensata già per un'eventuale pubblicazione («se un domani deciderò di
pubblicarla»). Scelte (Lorenzo: «fai tu»):
- **Dove**: pagina `/feedback` del SITO (`src/pages/FeedbackPage/`), dal
  Profilo → sezione "Aiutaci a migliorare" → "Segnala un problema o
  un'idea". Vale nel browser e nell'app (WebView). Testi IT + EN.
- **Invio**: Edge Function `supabase/functions/send-feedback/` → Resend
  (`onboarding@resend.dev`, piano gratuito = scrive solo all'email
  dell'account Resend). Solo utenti con sessione (la funzione verifica il
  token con `/auth/v1/user`; deploy `--no-verify-jwt` perché la chiave
  `sb_publishable_` non è un JWT). Max 5 invii/10 min per utente (per
  istanza). Secret: `RESEND_API_KEY`, `FEEDBACK_TO` (l'indirizzo NON è nel
  repo), facoltativo `FEEDBACK_FROM`.
- **Dati sensibili**: il sito blocca l'invio se trova email, numeri di 9+
  cifre (telefono/carta/documento) o IBAN e dice cosa togliere; la funzione
  li sostituisce comunque con `[rimosso]`. Email in solo testo.
- **Info allegate** (visibili all'utente in "Cosa alleghiamo in
  automatico"): origine (app iOS / sito web), lingua; nell'app versione
  app, iOS e modello (`DeviceInfo.swift` → `window.svDeviceInfo`), nel
  browser lo user agent. Né nome né email dell'utente.
- Test: Deno 5/5 (`deno test --no-lock supabase/functions/send-feedback/`),
  vitest 224/224, iOS 50/50. Pagina provata nel browser in modalità locale
  (avviso, blocco email, errore "solo con il cloud").
- 2026-11-03: secret `FEEDBACK_TO` SALVATO e funzione `send-feedback`
  PUBBLICATA dalla dashboard (editor, 2 file: index.ts + feedback.ts),
  dal browser dell'app dove Lorenzo era già entrato. CLI Supabase 3.0.0
  installata (brew) ma non loggata. "Verify JWT with legacy secret" è
  rimasto ACCESO (il classificatore di Claude Code blocca lo spegnimento):
  se l'invio dà "Invalid JWT", Lorenzo lo spegne in Functions →
  send-feedback → Settings.
- Lorenzo ha creato l'account Resend e salvato `RESEND_API_KEY`. INVIO DI
  PROVA RIUSCITO (2026-11-03) dal sito cloud :5181 nel browser dell'app,
  con Lorenzo loggato: la funzione ha risposto ok ("Grazie!"), anche con
  "Verify JWT" acceso (il token utente passa). Email ARRIVATA nella
  casella di Lorenzo (Importanti, 19:14) con tipo, testo e info tecniche:
  verificato da lui. Nota: l'ora "Inviata" è in UTC. Committato su feat/app-ios.
- Seconda prova (stessa sera, "Prova della sezione Feedback…"): "Delivered"
  su resend.com/emails e arrivata a Lorenzo. **FEEDBACK CHIUSO.** Restano
  solo, col suo ok: push di `feat/app-ios` (commit `e2a9211`) e una nuova
  build sull'iPhone per allegare versione app, iOS e modello (DeviceInfo).
  Attenzione: più sessioni lavorano qui in parallelo; prima di commit,
  deploy o prove controllare `git log`, `git status` e questo file.

## Novità 2026-11-03 (sera) — APP iOS su branch `feat/app-ios` (non ancora su main)

Richiesta di Lorenzo: app vera con Swift, «il telefono scontorna la persona
e i capi, vanno sull'avatar… e si può girare», primo accesso con 3 foto
(davanti/lato/spalle) che restano per account, Accedi con Apple/Google,
selettore Chiaro·Scuro·Sistema (resta nell'app: Profilo, e le schermate
native lo seguono). Account Apple a pagamento RIMANDATO («proviamolo in
locale»). Spec `docs/superpowers/specs/2026-11-03-app-ios-design.md`,
piano `docs/superpowers/plans/2026-11-03-app-ios.md`, registro decisioni
(rulings, correzioni della revisione, minori rimandati) in
`docs/superpowers/plans/2026-11-03-app-ios-registro.md`.

- **Sito**: tema chiaro/scuro/sistema, campo "Foto del retro" nei capi,
  ponte `nativeBridge.js` (nel browser non cambia nulla), migrazione 003.
- **App** in `ios/` (XcodeGen: `cd ios && xcodegen generate`): WebView del
  sito (DEBUG → dev server :5181, Release → sito pubblicato) + login nativo
  (supabase-swift, Google solo se attivo, Apple dietro flag) + primo accesso
  3 foto (Vision) + avatar in 3 viste (Vision + CoreGraphics, cache su
  disco) + tema. Guida: `docs/ios-installazione.md`.
- **Vision NON gira nel simulatore iOS 27** (mancano i pesi dei modelli): i
  test Vision e il render dell'avatar girano nel target macOS
  `StyleVaultVisionTests`. Render vero su Mac:
  `docs/verifiche/2026-11-03-app-ios/avatar-davanti-mac.png`.
- **Simulatore condiviso** con altre sessioni (Fitness Hub, "Vocali"): non
  toccare le loro app.
- **Migrazione 003 APPLICATA** il 2026-11-03 (SQL Editor dal Chrome di
  Lorenzo; verificato: theme/body_photos/photo_back_* → 200 via API). Il
  branch ora si può pubblicare senza rompere la sync di lingua e città.
- Xcode: Lorenzo è entrato col suo Apple ID; team "Lorenzo Faraoni
  (Personal Team)" = `599MS2BZ63`, ora fisso in `ios/project.yml` (firma
  automatica). iPhone di Lorenzo = iPhone 18 Pro Max
  (`00008160-000661061A200036`). Per la prova la build DEBUG carica il dev
  server del Mac in rete (`SITE_URL` in Secrets.xcconfig = IP del Mac,
  vite con `--host`), perché il sito pubblicato non ha ancora il ponte.
  Modalità sviluppatore ATTIVA (verificata 2026-11-03 con `devicectl device
  info details`). Se `devicectl` dice "connected (no DDI)" / errore 12040,
  l'iPhone è bloccato: sbloccarlo e rilanciare `devicectl device info
  ddiServices`. Build DEBUG per iPhone RIUSCITA e app INSTALLATA
  (`it.faraoni.stylevault`); il primo avvio è stato negato finché Lorenzo
  non autorizza lo sviluppatore (Impostazioni → Generali → VPN e gestione
  dispositivi → Apple Development lorefara97@gmail.com → Autorizza).
  Autorizzato: l'app ora parte sull'iPhone.
- **Password dimenticata? nel login nativo** (richiesta di Lorenzo, la sua
  email aveva già un account): link sotto la password → email di Supabase
  con `redirect_to=stylevault://reset-password` → l'app si riapre
  (`onOpenURL`, codice PKCE scambiato con `session(from:)`) → schermata
  "Scegli una nuova password" (`NewPasswordView`) → si entra. Se si prova a
  registrarsi con un'email già usata, il login passa da solo ad "Accedi".
  Richiede `stylevault://**` tra le Redirect URLs di Supabase: AGGIUNTO il
  2026-11-03 dal Chrome di Lorenzo (ora 3: localhost:5173/**,
  fara2106.github.io/stylevault/**, stylevault://**). Vale anche per Google. 35 test iOS verdi.
  PROVATO sull'iPhone il 2026-11-03: Lorenzo ha rifatto la password dal link
  dell'email ed è entrato (checklist §8 punto 1 ok). Commit `f4f712f`.
- **Foto del corpo di prova** (Lorenzo non sapeva come farsele): 3 foto
  Unsplash guardate una per una (davanti 1763750581767, lato 1559734257-47e…,
  spalle 1559907252 — lato e spalle stessa persona) in
  `ios/build/foto-corpo-test/` (ignorata da git), passate all'iPhone via
  AirDrop. Pre-verifica sul Mac compilando con `swiftc` gli stessi sorgenti
  Vision + `BodyPhotosModel.validate`: tutte "ok". Il simulatore NON serve
  per questo passo (Vision assente, niente login). Lorenzo le ha caricate
  sull'iPhone ed è entrato nel sito: checklist §8 punto 2 OK (2026-11-03).
- **Avatar sull'iPhone, primo giro** (screenshot di Lorenzo): una sola
  scarpa enorme su tutti e due i piedi, maglione più stretto della maglia
  sotto, jeans assenti. Cause e correzioni (non ancora committate):
  - le foto prodotto hanno UNA scarpa di lato → `GarmentLayout.shoeFrames`
    la mette su ogni piede (lunga 15% dell'altezza, punta verso fuori o
    dove guarda la persona, `Silhouette.toeOnLeft` + specchiatura); un
    paio (2 soggetti) resta un'immagine sola. `CutoutCache` ora salva il
    numero di soggetti (`<chiave>.count`), prima lo perdeva (sempre 1);
  - larghezze dal riquadro della persona (braccia, passo) → `Silhouette`
    misura la sagoma alla riga del petto (top) e, di lato, dei fianchi;
  - vita dei pantaloni a `hipY - 0.1·torso` (striscia di maglia scoperta)
    e larghi almeno quanto le caviglie divaricate + 8% dell'altezza;
  - jeans assenti al primo giro: l'outfit aperto non li conteneva (cache
    dell'iPhone con 2 soli capi; al secondo giro, con log temporaneo del
    ponte, arrivano Maglione/tops, Jeans/bottoms, Scarpe/shoes e si vedono).
  - secondo giro: viste scambiate (foto di spalle salvata come "lato",
    profilo come "spalle") → `BodyPhotosModel.seenView` rifiuta la foto
    della vista sbagliata (`PhotoCheck.wrongView`): di lato spalle < 35%
    del busto; davanti Vision mette la spalla sinistra a destra
    nell'immagine, di spalle a sinistra. Verificato sulle 3 foto vere in
    tutte le 9 combinazioni (3 ok, 6 rifiutate) + alternative + fixture.
  - pantaloni mai più larghi del 35% dell'altezza (col profilo in falcata
    salvato come "spalle" erano giganti). I capi caricati dal sito sono
    data URL piccole (~415×600): ingranditi si vedono sgranati.
  Render di verifica `docs/verifiche/2026-11-03-app-ios/avatar-3-viste-mac.jpg`;
  script Mac che rifà i passi di AvatarView: scratchpad `arender`. Test iOS
  46/46, Vision Mac 8/8. Limite noto: di lato col passo e col cappotto in
  mano restano visibili gamba dietro e cappotto (foto di prova "in cammino").
- **Lorenzo vuole i capi "esattamente lungo le linee del corpo"** (deformati).
  Brainstorming in corso. Opzioni: collage preciso on-device (warp riga per
  riga come `src/utils/modelWarp.js` del sito), servizio esterno (FASHN
  ~0,075 $/img, un capo per volta, 10–20 s, foto fuori dal telefono),
  modello on-device. Prova usa-e-getta di **Mobile-VTON** (CVPR 2026, 415M
  param., licenza CC BY-NC-SA = solo non commerciale, solo parte di sopra,
  addestrato su foto frontali testa→metà coscia, pesi 3,5 GiB) sul Mac M1
  Pro: maglione sulla foto davanti ritagliata → risultato quasi
  fotografico (maniche ai polsi, pieghe; trecce del maglione meno nitide),
  102 s con 28 passi fp16 (2,64 s/passo). Codice esterno: il classificatore
  di Claude Code blocca l'esecuzione, la lancia Lorenzo dal Terminale. Tutto
  in scratchpad (`spike-mvton*`), nulla nel repo. Nessuna versione iPhone:
  andrebbe convertita in Core ML. Seconde prove: figura intera OK (maglione giusto,
  pantaloncini invariati: tocca solo la parte di sopra); di spalle
  sorprendentemente OK (sostituisce il cappotto, trama un po' confusa);
  10 passi ≈ qualità di 28 (denoise 9 s, 32 s con codifica testo/avvio).
- **Design "avatar realistico"** scritto:
  `docs/superpowers/specs/2026-11-03-avatar-realistico-design.md` (bozza, da
  approvare). Decisioni di Lorenzo: parte da sola la vista davanti con barra
  e percentuale, poi pulsanti "Genera di profilo"/"Genera di spalle";
  download ~1 GB al primo uso con barra; modelli su Release GitHub; deve
  girare sul suo 18 Pro Max e sul 15 Pro di Mary (8 GB RAM). Primo passo:
  prova tecnica Core ML sull'iPhone (soglie ≤60 s / ≤90 s). Licenza NC:
  niente uso commerciale, motore dietro `RealisticTryOn` per poterlo
  cambiare. Design APPROVATO da Lorenzo (2026-11-03). Piano della sola
  prova tecnica: `docs/superpowers/plans/2026-11-03-avatar-realistico-prova-tecnica.md`
  (6 task: riferimento PyTorch, conversione Core ML fp16 + verifica, pipeline
  Core ML sul Mac, 6 bit, app di misura `RealisticBench` su 18 Pro Max e
  15 Pro, cancello). Il piano d'integrazione si scrive dopo il cancello.
  Test iOS: serve `CODE_SIGNING_ALLOWED=NO` (comando nel registro).
- **Prova tecnica, avanzamento** (registro in
  `.superpowers/sdd/2026-11-03-avatar-realistico-prova-tecnica/progress.md`,
  script in `tools/avatar-realistico/`, uscite in `out/` ignorata da git):
  Task 1 fatto: riferimento PyTorch in **fp16** (in fp32 il Mac da 16 GB va in
  swap). Task 2 fatto: tutti e 7 i modelli convertiti in fp16 (~3,1 GB;
  TextEncoder2 da solo 1,3 GB → candidato a restare fuori dall'iPhone) e
  verificati contro il riferimento, coseno ≥ 0,99998. Correzioni:
  ImageEncoder (bicubica di DINOv2 non supportata → posizioni precalcolate),
  DenoiserGarment (feature 8–11 = stessi tensori delle 12–15: ne esce 24,
  l'app ricopia le 12–15 nelle 8–11). Task 3 fatto: generazione intera
  coi soli modelli Core ML (`coreml_pipeline.py`, non importa Mobile-VTON:
  la lancia Claude) → PSNR 33 dB contro PyTorch, uguale a occhio. Sul Mac
  usare `--units CPU_AND_GPU`: col Neural Engine il Mac da 16 GB va in swap.
  Task 5 in corso: app `RealisticBench` (target XcodeGen, iOS 18, modelli
  fp16 in `ios/RealisticBench/Models/`, ignorata) installata sul 18 Pro Max.
  Limite Apple ID gratuito: max 3 app firmate sul telefono → Lorenzo ha
  tolto un'app per far posto. Modelli copiati una volta in Documents/Models
  (`devicectl device copy to … --domain-type appDataContainer`), app 336 KB;
  entitlement `increased-memory-limit` (va anche con Apple ID gratuito) →
  6,1 GB liberi. Avvio da Mac: `devicectl … launch it.faraoni.stylevault.bench
  --units gpu|ane [--phases 2]`. **Risultati fp16 sul 18 Pro Max**:
  Neural Engine = il Denoiser non si prepara (>50 min, interrotto); GPU =
  10 passi VERI 109 s (UNet capo 2,3 s/passo, UNet prova 7,4 s/passo,
  preparazione feature Swift 1,2 s/passo), picco 2,8 GB, primo avvio +70 s
  di preparazione GPU → vista davanti ≈ 112 s: NON PASSA (soglia 60 s).
  Attenzione: i tempi "a regime" con ingressi identici sono falsati
  (Core ML ricicla): ora la stima usa 10 passi VERI.
  Poi (stessa sera): ingressi riusati invece che ricreati → GPU fp16 30 s;
  **modalità mista** (tutto su Neural Engine, Denoiser su GPU, `--units mix`)
  → fp16 23 s, **6 bit 25 s, picco 2,4 GB: PASSA** (soglia 60 s). Primo
  avvio dopo l'installazione: ~4 min di preparazione Neural Engine, una volta.
  Task 4 fatto: 6 bit (palette k-means, gruppi di 16 canali) = 1,2 GB, tutti i
  pezzi coseno ≥ 0,9976, immagine 31,8 dB. Notte 3→4/11 (Lorenzo dorme, "fai
  tutto su Mac, domani iPhone e iPad"): generazione vera in RealisticBench
  (`BenchGenerator`, `BenchMath` + 7 test; `--generate`, ingressi da
  `export_bench_inputs.py`); verificata sul Mac col test macOS
  `RealisticBenchMacTests` → immagine IDENTICA a quella Python (fp16 e 6 bit);
  copia veloce delle uscite (vImage) → feature da 21 s a 0,75 s. Simulatori
  inadatti su questo Mac (6 bit scompattato sulla CPU; swap finito → jetsam;
  sul sim 18 Pro girano i test UI di Fitness Hub di un'altra sessione).
  Seconda parte della notte ("prova tutto sul simulatore, hai tutta la
  notte"): generazione con UNA rete grande alla volta (feature del capo dei
  10 passi calcolate prima, fp16 su file mappati) → memoria dopo i passi da
  2,5 a 1,17 GB, UNet capo sul Mac 0,25 s/passo invece di 3,8; immagine
  identica. Simulatori: servono fp16 + `--units cpu` (il modo GPU del
  simulatore manda in swap il Mac) → **generazione completa riuscita sul
  simulatore iPhone 18 Pro Max (553 s) e su un iPad Pro 13" M5 creato
  apposta e cancellato (603 s)**, immagini identiche tra loro, 33,0 dB da
  PyTorch. Il sim iPad acceso è usato dalla sessione Vocali (test UI), il
  sim 18 Pro da Fitness Hub: non usarli quando girano. Preparata la UNet di
  prova a batch 1 (`Denoiser1`, `--split`): la conversione la lancia Lorenzo.
  Resoconto: `docs/verifiche/2026-11-03-avatar-realistico/prova-tecnica.md`;
  comandi per iPhone/iPad in `tools/avatar-realistico/README.md`. Domani:
  18 Pro Max con `--generate`, iPad di Lorenzo, 15 Pro di Mary.
  Commit c9e5430 + 14438dd (ok di Lorenzo, non pushati). 04/11 dispositivi
  veri, 6 bit mista, `--generate`: **18 Pro Max 21,4 s** a modelli pronti,
  **iPad Pro 13" M4 36,3 s** (primo avvio 86,6 s); immagini a 52,7 dB da
  quella del Mac e 61 dB tra loro (`iphone-vero-6bit.png`, `ipad-vero-6bit.png`).
  Resta il 15 Pro di Mary. **Cancello Task 6 (04/11, Lorenzo): si va avanti
  con Mobile-VTON e l'app si pubblica GRATIS** (CC BY-NC-SA: niente
  pubblicità, acquisti in-app o abbonamenti; crediti nell'app). Piano:
  `docs/superpowers/plans/2026-11-04-avatar-realistico-integrazione.md`
  (9 task: Release GitHub con i modelli, tokenizzatore/DINOv2/scheduler in
  Swift, download con ripresa, motore, maschera, UI, descriptor dal sito,
  prova su 18 Pro Max e 15 Pro). Per l'App Store serve l'Apple Developer
  Program (oggi Personal Team gratuito).
  Idea di Lorenzo: per ora Mobile-VTON coi crediti per farsi conoscere; in
  futuro un'IA nostra al suo posto (il motore sta dietro `RealisticTryOn`).
  04/11 piano eseguito coi subagent, Task 1–8 fatti e revisionati, commit
  locali e58a5ff..f187ad2 (NON pushati): pacchetto modelli (out/release, 8
  .aar 1,27 GB), tokenizzatore CLIP, ingressi, store con download/ripresa/
  SHA-256/consenso su rete cellulare, motore MobileVTONTryOn (45,9 dB dal
  riferimento Mac), composizione col collage + maschera, schermata con barre,
  crediti, elimina modelli, protezione da crash per memoria; il sito manda
  `descriptor`. Test: app 123/123, Mac motore 3/3. Manca Task 9 (telefoni):
  i telefoni. Licenze (281ecaa): la VAE deriva da Stable Diffusion 3.5 Large
  → licenza Stability AI Community + NOTICE.txt + "Powered by Stability AI"
  nei Crediti; anche CLIP/OpenCLIP (MIT) e DINOv2 (Apache 2.0). **Release
  `avatar-models-v1` PUBBLICATA (04/11)** su Fara2106/stylevault: 8 .aar +
  manifest + licenze; controllati dimensioni di tutti, SHA di VAEDecoder e
  Tokenizer scaricati dall'URL pubblico, ripresa con Range (206) attraverso
  il redirect. Ogni cambio di modelli = nuovo tag (il manifest non è fissato).
- **Outfit anche con guardaroba incompleto** (04/11, richiesta di Lorenzo:
  «generi lo stesso, basta un avviso»): `generateOutfits` riempie ogni pezzo
  coi capi adatti a stagione/occasione, se non ce ne sono con quelli della
  categoria (fuori stagione), e lascia vuoto solo il pezzo che non c'è;
  `missingPieces()` → riquadro "Outfit incompleto, manca: …" nella card.
  Serve almeno un capo da indossare (soli accessori = niente). Test 231/231.
- **Meteo della posizione (04/11)**, design `docs/superpowers/specs/2026-11-04-meteo-posizione-design.md`,
  piano `docs/superpowers/plans/2026-11-04-meteo-posizione.md`: pagina Outfit
  con "La mia posizione" (app: CoreLocation via `requestLocation` →
  `svNative.setLocation`; browser: solo dopo il tocco) o città scelta a mano
  (ricordata in localStorage `sv_outfit_place`, mai coordinate); Open-Meteo
  orario → fasce mattina 8–12 / pomeriggio 12–17 / sera 17–20, temperatura
  media 8–20 (oggi da adesso), consigli "a strati" (≥ 8°) e "pioggia dalle
  HH"; striscia `DayStrip`. **Meteo di Apple PRONTO MA SPENTO**
  (`ios/StyleVault/Weather/AppleWeather.swift`, `isEnabled = false`): l'app
  converte WeatherKit nel formato Open-Meteo e lo manda con
  `svNative.setForecast`. **Per accenderlo, quando Apple approva l'account
  Developer**: (1) developer.apple.com → Identifiers → App ID
  `it.faraoni.stylevault` → spunta WeatherKit (e in "Services" WeatherKit);
  (2) in `ios/project.yml` entitlements aggiungi
  `com.apple.developer.weatherkit: true`, poi `cd ios && xcodegen generate`;
  (3) `AppleWeather.isEnabled = true`; (4) prova sul telefono: scheda meteo
  con marchio "Meteo di Apple" e link "Fonti dei dati" (obbligatori per Apple).
  Revisione finale (opus): 0 critici, 3 importanti CORRETTI (15525c3,
  3298fb3): cache della posizione in chiave fissa `sv_weather_<fonte>_position`
  (niente coordinate né storico); posizione nuova entro ~5 km ignorata
  (`keepSamePlace`) così gli outfit non si rifanno; WeatherKit chiede le ore
  da mezzanotte per 7 giorni (`hourlyRange`). 9 minori rimandati (elenco nel
  messaggio finale a Lorenzo). Test: sito 268/268, iOS 130/130 (il target
  test ora ha `GENERATE_INFOPLIST_FILE`). Build Debug installata sull'iPhone
  il 04/11: **da provare da Lorenzo** (permesso posizione, posto vero,
  striscia, consigli). Push e deploy del sito: solo col suo ok.
- **Barra di download dei modelli di analisi (04/11)**: `src/utils/modelDownload.js`
  scarica i file MediaPipe (motore WASM 11,2 MB decompresso, segmentatore
  16,4 MB, viso 3,8 MB, posa 5,8 MB) leggendo i byte → `downloadFraction()`;
  MediaPipe li riceve già pronti (`modelAssetBuffer`, WASM da blob URL).
  Restano sul dispositivo in Cache Storage `sv-models-v1` (sito e app; serve
  https o localhost: nella build Debug via http dal Mac resta solo la cache
  HTTP). Barra nell'Armocromia durante la "prima volta". Verificato nel
  browser: 3 file salvati, al ricaricamento zero richieste di rete.
- **"Le tue foto" nel Profilo (04/11)**: Lorenzo non vedeva le foto del corpo
  nel sito e il pulsante "Rifai le foto del corpo" (solo app) andava e veniva.
  Ora `src/components/BodyPhotos/` mostra sempre le 3 miniature (davanti =
  reference_photo_path, lato/spalle = body_photos). Nell'app un tocco apre la
  fotocamera nativa per QUELLA foto (`openBodyPhotos` con `{view}` →
  `BridgeMessage.openBodyPhotos(BodyView?)`); alla chiusura l'app chiama
  `svNative.bodyPhotosChanged()` e il sito rilegge il profilo. Nel browser un
  tocco sceglie un file (1600 px) → `setBodyPhoto` in ProfileContext. Causa del
  pulsante intermittente NON trovata: nei dati dell'app sull'iPhone la WebView
  carica 192.168.1.148:5181 e il ponte svNative c'è (test
  `testIlSitoVedeIlPonteSvNative`); ipotesi: a volte guardava il sito in Safari.
  Verificato nel browser (locale); il salvataggio su Supabase dal browser e il
  giro nell'app li deve provare Lorenzo. Test sito 281/281, iOS 133/133.
- **Controllo dati su Supabase (04/11, dashboard, sola lettura)**: account di
  Lorenzo a posto: 3 capi (3 foto nello storage), 1 voce di calendario, foto
  davanti/lato/spalle salvate e presenti nello storage, it / Roma / light.
  **MANCA la colonna `profiles.armocromia`**: la migrazione 002 NON è applicata
  su questo progetto (frukvktbmxndyzgivwxq), anche se le note di luglio la
  danno per fatta (forse era un progetto precedente). Effetto: salvare
  l'Armocromia dal sito fallisce (l'upsert del profilo va in errore) e il
  risultato si perde al ricaricamento. **APPLICATA il 04/11** con l'ok di
  Lorenzo (SQL Editor della dashboard nel browser pane); verificato: colonna
  `armocromia jsonb` presente e `select=armocromia` via API → 200.
  Prova di salvataggio "come Lorenzo" con le regole d'accesso (annullata da
  sola) riuscita; poi Lorenzo ha rifatto l'Armocromia e il 04/11 alle 15:08
  UTC il suo profilo ha `armocromia` = deep-winter (axes, season, detected,
  updatedAt, confidence). **Salvataggio confermato end-to-end.**
- **DECISIONE 04/11 (Lorenzo e Mary): StyleVault diventa NATIVA con iCloud**.
  Design: `docs/superpowers/specs/2026-11-04-app-nativa-icloud-design.md`
  (scritto da un'altra sessione; NON committato, si committa con l'ok di Lorenzo).
  - Prima la versione Apple (iPhone e iPad): SwiftUI + SwiftData/CloudKit,
    niente login; sito e Supabase spenti alla fine.
  - Android eventualmente dopo, app a sé con dati su Google Drive; le due non
    si scambiano dati.
  - Costruzione in parallelo su un ramo nuovo, 8 fasi; si pubblica una volta
    sola, a lavoro completo. Fino ad allora resta l'app ibrida di oggi. Non si
    migra una schermata alla volta (dati divisi tra Supabase e iCloud).
  - Esporta/Importa (zip con JSON e foto) nel Profilo: per il cambio di
    piattaforma e la portabilità GDPR.
  - Armocromia: menu a tendina nel Profilo per scegliere la stagione a mano;
    l'analisi Vision solo se affidabile.
  - Lingue IT e EN da subito (String Catalog), poi FR, ES, PT, EN UK/USA;
    °C/°F nelle Impostazioni, valore iniziale dalla regione del telefono.
  - Fase 1 solo quando Lorenzo è accettato nell'Apple Developer Program
    (avvisa lui). Import dei dati da Supabase: si decide all'inizio della fase 7.
  - **Stop al lavoro su account e server** del sito. Quello già fatto resta:
    e944db0 (Elimina account, pagine /privacy /supporto /elimina-account,
    accountCleanup, guard di fetch-link-metadata) è committato.
    **Supabase riportato a prima (04/11, su richiesta di Lorenzo)**:
    `delete-account` cancellata dalla dashboard (ora risponde 404);
    `fetch-link-metadata` ripubblicata nella versione di prima (e944db0^, senza
    controllo dell'utente né guard.ts; con la chiave pubblica funziona).
    ATTENZIONE: nel repo restano il codice di e944db0 (cartella delete-account,
    guard.ts, pulsante "Elimina account" che chiama una funzione che non c'è
    più). Non pubblicare il sito con quel codice senza decidere prima.
    Le correzioni iOS restano utili anche nella versione nativa:
    Privacy Manifest, Debug/Release, etichetta IA, Segnala, dichiarazione
    foto, consenso al download.
- **Audit Apple ripetuto 04/11 sera** → sezione 00 del report
  `docs/pubblicazione/2026-11-04-report-app-store.md`. App ibrida: non si
  invia (blocchi 2 e 3 riaperti). Nativa: **rischio licenze grave** — Mobile-VTON
  è addestrato su DressCode (licenza solo ricerca/didattica, non commerciale)
  → proposta: prima versione senza avatar realistico e richiesta di permesso
  ad AImageLab. Import dei dati: niente login Supabase né import nascosto
  (regola 2.5.19), usare Esporta/Importa con uno script lanciato da Lorenzo.
  L'app deve funzionare senza iCloud. Pagine privacy/supporto ancora 404.
- **Test completi 04/11 sera** (dopo il push di feat/app-ios, 1f1a28a):
  StyleVault 138/138 su iPhone 18 Pro e su iPad Pro 11" (M5)
  (B04B93AB-…, libero; l'iPad Pro 13" M5 acceso è della sessione Vocali);
  RealisticBench 9/9 su entrambi dopo aver aggiunto GENERATE_INFOPLIST_FILE a
  RealisticBenchTests in project.yml (senza, xcodebuild non firmava il
  bundle); sito vitest 294/294 e build ok; funzioni Deno 7/7. Nei simulatori:
  login nativo ok su iPhone e iPad (su iPad gira in modalità iPhone,
  TARGETED_DEVICE_FAMILY "1"). I link Privacy/Supporto aprono
  fara2106.github.io/stylevault/privacy|supporto che danno **404** (pagine non
  ancora pubblicate). Giro da loggati non fatto: serve un account vero.
- **Correzioni dell'audit (04/11, pomeriggio)**, stato nella sezione 0 del report.
  Fatto:
  - "Elimina account" nel Profilo → Edge Function `delete-account`, pubblicata
    dalla dashboard come file unico con account.ts incollato (poi cancellata da
    Supabase il 04/11, vedi sopra). Cancella i file dei
    2 bucket e poi l'utente; le tabelle si svuotano in cascata.
  - Pagine pubbliche `/privacy`, `/supporto`, `/elimina-account`
    (`src/pages/LegalPage/legalContent.js`, CONTACT_EMAIL da confermare con
    Lorenzo); il deploy le copia come pagine vere.
  - `PrivacyInfo.xcprivacy`.
  - Rete locale/ATS solo in Debug (script postBuild in project.yml); SITE_URL
    vuoto in Release.
  - `fetch-link-metadata` solo per loggati e senza SSRF (guard.ts), ripubblicata
    (poi tolta il 04/11: su Supabase c'è di nuovo la versione di prima).
  - "Generato con IA" + "Segnala risultato" (app → /feedback?topic=avatar);
    "Scarica (1,3 GB)" la prima volta.
  - Open-Meteo citato; segnaposto senza picsum.

  Test: sito 294, iOS 138, Deno 12. La cancellazione con un account vero la
  prova Lorenzo. Dashboard: l'editor non rinomina il 2° file con il pane
  nascosto → incollare un file solo.
- **Audit di pubblicazione App Store (04/11)**, skill mobile-app-publishing:
  report in `docs/pubblicazione/2026-11-04-report-app-store.md`. 6 blocchi:
  Apple Developer Program a pagamento, cancellazione account (manca),
  privacy policy + supporto (mancano), PrivacyInfo.xcprivacy (CA92.1,
  C617.1, E174.1), sito pubblicato indietro (61 commit), rete locale/ATS
  "In sviluppo" nella Release. 15 avvisi (etichetta "Generato con IA" +
  segnala, download 1,3 GB senza chiedere sul Wi-Fi, @imgly AGPL, Open-Meteo
  senza attribuzione, fetch-link-metadata senza JWT, ecc.). Google Play
  escluso: niente app Android.
- **"Cambia password" nel Profilo (04/11)**: pulsante sotto Impostazioni
  (`components/ChangePassword`), apre nuova + ripeti → `changePassword` in
  AuthContext → `supabase.auth.updateUser({ password })` (sito e app, stessa
  sessione). Controllo in `utils/passwordChange.js` (min 6, coincidono);
  errori nuovi tradotti: passwords-mismatch, same-password,
  reauthentication-needed. Provato nel browser in modalità locale (errore se
  diverse, poi "Password cambiata"); con Supabase vero lo prova Lorenzo
  (deve cambiare la password che aveva scritto in chat). Test 285/285.
- **Prova sull'iPhone (04/11)**: la build Release apre il sito PUBBLICATO,
  che non ha il ponte iOS (niente "Rifai le foto del corpo" né "Vedilo
  addosso") → si prova con la build Debug + `vite --host` :5181
  (`stylevault-cloud`); IP del Mac oggi 192.168.1.148 in Secrets.xcconfig.
  Bench tolta dal telefono (limite 3 app). Release di sicuro solo dopo il
  deploy del sito di feat/app-ios (decide Lorenzo).
- Revisione finale (revisore separato): 2 critici + 8 importanti CORRETTI
  (refresh token doppio, sessione al sito solo dopo 'ready', link esterni,
  avvio offline, 'Più tardi', conteggio persone, foto 48 MP, retro dei capi);
  10 minori rimandati, elencati nel registro.
- Da fare con Lorenzo: Apple ID in Xcode, installazione sull'iPhone,
  login reale, Google OAuth; inglese delle schermate native (oggi solo IT).

## Novità 2026-11-03 (pomeriggio) — "Su di te" TORNA (persona scontornata vestita)

Richiesta di Lorenzo: «vesti anche l'avatar, deve essere la persona
scontornata». Ripristinata la scheda "Su di te" tolta il 18/07 (revert di
`586ba7e`: ModelTryOn + modelImage/modelComposer/modelWarp + 25 test). La
Prova ha di nuovo 2 schede: **Su di te** (predefinita) | **Prompt AI**; il
pannello "1 = la tua foto" nella fila del prompt è RIMASTO (il revert lo
toglieva). Testi del 18/07 tenuti, ripristinate solo le 8 chiavi model*.
- Prova con foto stock (ragazza a figura intera) + 3 capi Zalando: persona
  scontornata su fondo studio, jeans ottimi, sneakers ok (un filo grandi),
  maglione il punto debole (troppo largo, collo fino al mento, filo nero del
  maglione originale lungo le braccia). Desktop, primo uso: ~2 minuti
  (download modelli + ONNX single-thread), poi cache.
- iPhone NON verificato: nel simulatore l'incolla nei campi non funziona,
  impossibile fare login. Da provare su un iPhone vero (24MB @imgly).
- Test di quel giro: foto Unsplash in scratchpad, MAI usare foto scelte dal
  solo testo alternativo (una era di spalle e senza maglia: scartata).
- **GPU del telefono** (richiesta di Lorenzo: «sfrutta il processore
  dell'iPhone»): scontorno @imgly con `device: 'gpu'` (WebGPU, Safari iOS 26)
  in `cutoutDevice.js` (+2 test), ripiego CPU se la GPU fallisce; MediaPipe
  (segmenter, pose, face) con `delegate: 'GPU'` via `createVisionTask`,
  ripiego CPU. Misure su Mac (Chromium): scontorno foto successive 8,5 s →
  0,6 s; segmentazione 231 → 62 ms; colori armocromia invariati. Il primo
  uso resta ~1 min (download modelli). Multithread WASM NON possibile:
  GitHub Pages non manda gli header COOP/COEP. iPhone vero da provare.
- **Spiegazione "prima volta"** (richiesta di Lorenzo): in "Su di te" e
  nell'armocromia, solo al primo uso sul dispositivo, sotto il messaggio di
  attesa compare "Prima volta: sto scaricando i modelli (~25/~20 MB), può
  volerci un minuto… le prossime volte sarà molto più veloce". Flag
  `sv_models_ready_tryon` / `_armocromia` in localStorage (`firstUse.js`, 2
  test), messo dopo il primo giro riuscito.
- Banco di prova in console: con il pannello browser NASCOSTO `img.decode()`
  non si risolve mai → usare `onload` e lanciare le misure in background
  (`window.__bench`), leggendole a parte.

## Novità 2026-11-03 — giro di miglioramenti per iPhone + BACKEND CLOUD SPARITO

**Backend RIATTIVATO lo stesso giorno.** Il progetto Supabase
`frukvktbmxndyzgivwxq` (org "lorefara97@gmail.com's Org") era IN PAUSA, non
cancellato: da agosto l'host rispondeva NXDOMAIN (un progetto in pausa sparisce
dal DNS) e il sito live non faceva entrare nessuno. Causa: il keep-alive aveva
smesso di girare e GitHub l'ha messo in `disabled_inactivity` (repo fermo da 60
giorni). Lorenzo ha fatto login nella dashboard, "Resume project" (online in
~4 minuti, dati e foto intatti, stesse chiavi → niente secrets da cambiare),
keep-alive riabilitato e lanciato a mano: verde. Verificato dal Chrome di
Lorenzo: guardaroba caricato dal cloud con foto, nessun avviso.
- Se ricapita: dashboard → progetto → "Resume project" (possibile entro la
  data indicata lì; dopo si può solo scaricare il backup).
- Nell'org "StyleVault" c'è un SECONDO progetto in pausa (`dqquxjahcl…`,
  eu-north-1, vuoto): non è usato dall'app.
- Google login: provider ancora spento. Ora il bottone "Continua con
  Google" compare SOLO se il provider risulta attivo (`/auth/v1/settings`):
  basta attivarlo su Supabase e appare da solo. Il redirect dopo Google ora
  torna a `/stylevault/` (prima puntava all'origin → 404 su GitHub Pages).
- Edge Function `fetch-link-metadata` DEPLOYATA dalla dashboard (2026-11-03,
  codice da `supabase/functions/`). Legge da sola gli shop senza anti-bot
  (OVS, Zara, Calzedonia…) senza consumare la quota microlink; gli shop
  protetti (Zalando, H&M, Uniqlo) rispondono 403 al server → l'app ripiega
  su microlink (Zalando lì funziona, H&M no). La chiave del progetto è
  `sb_publishable_…` (non JWT): la funzione accetta comunque le chiamate.
- Errori di login/registrazione tradotti (codici `auth.errors.*`, anche
  quelli inglesi di Supabase tipo "Invalid login credentials").

Migliorie fatte (testate nel browser in viewport mobile e sul simulatore
iPhone 18 Pro; commit `83be27a`, pubblicato):

- **iPhone**: campi a 16px sui touch screen (prima Safari zoomava la pagina a
  ogni tocco su un campo e restava zoomata — verificato nel simulatore);
  safe-area per notch/barra Home (BottomNav che prima si schiacciava, bottom
  sheet, pagine); `autoComplete` su login/registrazione (Portachiavi/Face ID),
  `inputMode` email/decimale; etichette dei campi collegate (`useId`).
- **Aggiungi a Home**: manifest + apple-touch-icon + icone 192/512/maskable
  (generate con sharp dal monogramma "SV"). L'avviso demo suggerisce
  "Aggiungi alla schermata Home" (le web app installate non subiscono la
  cancellazione dei 7 giorni di Safari).
- **Condivisione "Invia foto e prompt"**: i file si preparano PRIMA del tocco
  (come il provino): Safari rifiuta `navigator.share` se il gesto scade
  durante i download, e l'errore veniva ingoiato.
- **Memoria piena (modalità locale)**: avviso persistente quando localStorage
  rifiuta il salvataggio (prima i capi sparivano al riavvio in silenzio).
- **Link degli shop**: microlink risponde "success" anche sul muro anti-bot
  (H&M → titolo "Access Denied" + logo come foto): ora `statusCode >= 400` =
  errore, niente logo come foto, titolo senza " - Zalando.it" in coda, e il
  429 del piano gratuito (~50 letture/giorno, esaurito durante i test) ha il
  suo messaggio "finita per oggi". Zalando funziona; H&M no.
- **Griglie**: `minmax(0, 1fr)` ovunque — un nome lungo (tipico da link)
  allargava una colonna e poteva far uscire la griglia dallo schermo.
- **Bug prezzo**: modificando un capo con prezzo numerico l'etichetta restava
  sopra il valore (`49.length` non esiste).
- Pagine secondarie caricate al primo uso (React.lazy) con ricarica
  automatica una tantum se un deploy ha tolto i vecchi file.
- 172 test verdi. `.claude/launch.json` (locale, non tracciato) avvia il dev
  server in modalità locale sulla porta 5180 anche con `.env.local` presente.

## Novità 2026-07-18 (notte) — "Su di te" RIMOSSA: la Prova è solo Prompt AI

Richiesta di Lorenzo: «togli la parte su di me che tanto non serve più» — il
try-on ormai lo fa ChatGPT/Gemini col prompt. Fatto e LIVE (`586ba7e`):

- La pagina Prova non ha più schede: slot outfit + Salva + flusso Prompt AI.
- La foto della persona è il PANNELLO 1 della fila "Foto da caricare in chat"
  (tap per caricarla/cambiarla): resta la Image 1 di prompt/provino/share e
  la base dell'armocromia. Onboarding invariato (copy aggiornata).
- Cancellati ModelTryOn, Avatar.css, modelImage/modelComposer/modelWarp
  (+ test). RESTANO personSilhouette (scontorno capi), bodyAnalysis
  (armocromia), tryonComposer (slot). i18n 469/469.
- Prima, nella stessa serata (`cd2951a`): armocromia col RITAGLIO SUL VISO
  (il modello selfie riceveva la figura intera) + correzioni manuali
  RICORDATE; e bottone "Copia le foto (immagine unica)" — provino numerato
  negli appunti, niente più caccia in galleria.
- 162 test verdi, verifiche headless in scratchpad, deploy verdi.
- Sezione shop dell'armocromia rivista due volte (vince l'ultima, `4a63f4d`
  poi il commit successivo): **link solo sui colori** (palette e neutri
  tappabili → ricerca colore su Zalando) e **"Outfit ispirati alla tua
  stagione"** — ogni capo UN negozio a rotazione Zara/Bershka/Zalando
  ("maglietta pesca — Zara"). La riga "coordinato" è stata rimossa su
  indicazione di Lorenzo. 165 test verdi.
- **2026-07-19: shop VERIFICATI aprendo ogni URL in Chrome vero** («testa tu
  in primis»): funzionano Zalando/Zara/ASOS/Amazon/H&M/Notino; Bershka,
  Sephora e Douglas hanno la ricerca solo in overlay (deep-link impossibile)
  → sostituiti: outfit = Zara/H&M/Zalando, make-up = Notino+Amazon. Regola:
  mai aggiungere uno shop senza aprire l'URL generato in un browser vero.
  Poi, su richiesta di Lorenzo, i 3 sono TORNATI come "Anche su (lì cerca tu
  i tuoi colori)" → link alla HOME verificata: Bershka sotto gli outfit,
  Sephora+Douglas sotto il make-up. 168 test verdi.

## Novità 2026-07-18 (sera) — freeze sistemato, condivisione, ARMOCROMIA pronta

Tre avanzamenti dopo la prova online di Lorenzo:

1. **FIX del freeze su "Cambia foto" (LIVE, `756f740`)**: l'inferenza @imgly
   girava nel main thread (il suo proxyToWorker vale solo con WebGPU) e dal
   merge "Su di te" è la scheda d'ingresso → pagina congelata. Ora lo scontorno
   gira in `cutoutWorker.js` (Web Worker) con ripiego al main thread. Misurato
   in Chrome headless: lag max 460ms col worker vs 16.6s senza.
2. **Condivisione foto+prompt (LIVE, `b0f319d`)**: su telefono la scheda
   Prompt AI ha "Invia foto e prompt all'app AI" (Web Share API): 1-persona.jpg
   per prima (= Image 1), capi numerati come nel prompt. Un gesto, niente
   ricerca manuale delle foto.
3. **ARMOCROMIA LIVE** (merge ff `b0f319d..5b9a665` la notte del 18, deploy
   verde; Lorenzo ha applicato la migrazione 002 su Supabase e approvato sugli
   screenshot): pagina /armocromia dal Profilo — foto → pelle/capelli/occhi
   on-device → 12 sotto-stagioni (centroidi su 3 assi Lab, tarati in prototipo)
   → palette + combo outfit con link shop + guardaroba in palette + make-up.
   9/9 task revisionati, revisione finale opus "pronto al merge", 186 test
   verdi, verifica a schermo in docs/verifiche/2026-07-18-armocromia/.
   Fix-after rimandati: retry singleton MediaPipe, drop colonna avatar_config.

## Novità 2026-07-18 — "Prompt AI" LIVE, avatar RIMOSSO del tutto

**RIPARTIRE DA QUI.** La feature `feat/tryon-prompt` è FINITA e ONLINE:
merge fast-forward `a3e664c..164786f` su main, Action verde,
https://fara2106.github.io/stylevault/ . Lorenzo la sta provando online —
il suo feedback è l'unico punto aperto.

- **Com'è andata**: 6/6 task subagent-driven, ognuno con revisione dedicata,
  più revisione finale dell'intero branch (opus): «pronto al merge», nessun
  rilievo Critical/Important. Fix wave finale `164786f` (CSS morto, fallback
  `'garment'`, 5 sotto-categorie EN mancanti, commenti stale).
  Dettaglio completo nel ledger `.superpowers/sdd/progress.md`.
- **Cosa c'è ora in /tryon**: 2 schede — "Su di te" (default, invariata) e
  "Prompt AI": textarea col prompt inglese generato da `tryOnPrompt.js`
  (puro, 7 test; 45/45 sotto-categorie coperte), bottone Copia, istruzioni
  numerate, link ChatGPT/Gemini, immagini dei capi scaricabili numerate da
  "Image 2". Zero chiave, zero rete, zero costi.
- **Rimozioni**: `geminiTryon.js` + chiave nel Profilo; 13 file avatar
  (Avatar3D/AvatarSvg/AvatarEditor/OutfitOnAvatar/mesh/webgl) e `three`
  disinstallato. `avatar_config` resta come colonna Supabase ma il codice
  la ignora (retrocompatibile). i18n it/en identici a 356 chiavi.
- **Spostamento chiave (Task 5)**: slot-picker outfit + "Salva outfit"
  stavano SOLO dentro la scheda avatar → ora sezione sempre visibile sopra
  le schede (senza, il flusso dettaglio-capo → /tryon si rompeva).
- **Test**: 146 verdi in 14 file (via i test di avatar/gemini, +7 di
  tryOnPrompt). Onboarding ridotto a 2 step (foto → città).
- **PROSSIMO**: raccogliere il feedback di Lorenzo dalla prova online;
  poi cancellare il branch remoto `feat/tryon-prompt` e pianificare
  l'**armocromia** (spec da ripulire dai riferimenti all'avatar, v. sotto).

## Novità 2026-07-17 — DUE feature decise e speccate; esecuzione appena iniziata

Giornata di brainstorming: due feature approvate da Lorenzo,
spec committati, esecuzione della prima appena partita (interrotta per cambio chat).

### 1. Prova AI via prompt + RIMOZIONE TOTALE AVATAR — branch `feat/tryon-prompt`, COMPLETATO (v. sezione 2026-07-18)

- Spec: `docs/superpowers/specs/2026-07-17-tryon-prompt-design.md` (714616a).
- Piano: `docs/superpowers/plans/2026-07-17-prova-prompt-avatar.md` (444b524), 6 task.
- Cosa fa: la scheda AI di /tryon NON chiama più Gemini con la chiave utente.
  Diventa "Prompt AI": **l'app genera il prompt** (modulo puro `tryOnPrompt.js`,
  in inglese, modificabile) + istruzioni passo-passo + link ChatGPT/Gemini +
  accesso alle immagini dei capi; Mary incolla tutto in ChatGPT/Gemini (che ha
  gratis) e l'immagine la generano loro. Niente chiave, niente costi.
  Deciso dopo il dubbio di Lorenzo «non so se l'app da sola sia capace»:
  convinto da un esempio concreto (il prompt è una formula, la fedeltà la danno
  le immagini caricate). NO ad AI esterne per il prompt (Grok è a pagamento;
  una chiave su sito statico è pubblica → servirebbe un proxy).
- **AVATAR: Lorenzo ha scelto "Tutto l'avatar"** — si rimuove TUTTO (scheda in
  /tryon, editor nel Profilo, onboarding, Avatar3D/AvatarSvg/mesh, three.js dal
  bundle). Resta SOLO "Su di te" (che non condivide codice con l'avatar:
  dipendenze verificate, liste keep/remove in §4 dello spec). Prova = 2 schede.
- **Stato esecuzione**: COMPLETATA il 2026-07-18 (tutti e 6 i task + revisione
  finale + deploy) — vedere la sezione 2026-07-18 in cima al file.
  Ledger: `.superpowers/sdd/progress.md`.

### 2. Armocromia — branch `feat/armocromia`, spec pronto, piano DA SCRIVERE

- Spec: `docs/superpowers/specs/2026-07-17-armocromia-design.md` (6151530), approvato.
- Cosa fa: foto → colori pelle/capelli/OCCHI on-device (riuso MediaPipe di
  `bodyAnalysis.js` + FaceLandmarker per l'iride) → **12 sotto-stagioni**
  (3 assi Lab: caldo/freddo, chiaro/scuro, brillante/soffuso, classificatore
  puro TDD) → palette + outfit con **link di ricerca agli shop** (Zalando/Asos/
  Amazon; make-up Sephora/Douglas) + **match coi capi del guardaroba** (deltaE).
  Colori rilevati correggibili a mano prima del calcolo. Pagina `/armocromia`
  da card nel Profilo. Persistenza: profilo + colonna `armocromia jsonb`.
- **ORDINE DECISO: prima finire feat/tryon-prompt (merge), POI l'armocromia**
  off main aggiornato (entrambe toccano Profilo/Onboarding). Prima di
  pianificarla: **aggiornare lo spec** togliendo il bonus "usa i colori per
  l'avatar" e ogni riferimento ad `avatarOptions` (l'avatar non esiste più).

### Valutazioni AI immagini (per non ripetersi)

- **Raphael.app**: gratis solo via sito col watermark; API solo Enterprise a
  pagamento. Non integra.
- **free-image-generation-api (GitHub)**: Cloudflare Workers AI self-hosted,
  gratis MA solo text-to-image → inventa la persona, inutile per il try-on.
  Al più, in futuro, figurini decorativi per l'armocromia.
- Il muro resta quello del 2026-07-16: gratis = inventa; try-on vero = a
  pagamento. Lorenzo sulle immagini: «ora ci penso» — non riproporre.

## Novità 2026-07-16 (bis) — "Su di te" col WARPING: il capo segue il corpo

Richiesta di Lorenzo: «E non si può fare meglio?» → «procedi con i primi 2»
(1: coprire i vestiti originali; 2: posa vera). FATTO, MERGED e LIVE.
Sempre gratis e on-device; il 3° gradino (fotorealismo generativo) resta
fuori dai vincoli (serve GPU server, gratis affidabile non esiste).

- **MediaPipe Tasks Vision** (`bodyAnalysis.js`, lazy): ImageSegmenter
  multiclass (classe "vestiti") + PoseLandmarker lite. WASM da jsdelivr
  pinnato, modelli dal CDN MediaPipe (~20MB al primo uso, poi cache HTTP):
  è SOLO download di file, l'elaborazione è locale, la foto non esce.
- **`modelWarp.js` puro (16 test)**: piani di warping riga per riga.
  Top: ogni riga copre lo span dei vestiti indossati (via maniche/orlo del
  capo vecchio che spuntavano); righe strette (scollo) proporzionali e
  centrate; nella zona colletto lookahead verso il basso (le spalle nuove
  coprono le vecchie). Bottom: mappa verticale LINEARE vita→caviglia
  (ancorare il cavallo del capo al cavallo della persona distorce quando
  in foto le cosce si toccano), orizzontale riga per riga: una corsa→
  tronco/unione gambe, due corse→una per gamba lungo anca→ginocchio→
  caviglia, riga fusa→metà per gamba. Orlo proporzionale (gli shorts non
  arrivano alle caviglie). Scarpe alle caviglie vere.
- **Ripiego totale**: se segmentazione E posa falliscono si torna ai
  rettangoli del giro precedente (ModelTryOn tiene entrambe le strade).
- **Lezioni**: la mano davanti alla coscia è "pelle" e va ESCLUSA dalle
  corse delle gambe (creava un gradino); i moduli ES ricaricati in console
  vanno importati con cache-buster `?t=` sennò si testa il codice vecchio;
  il ciclo stretto di taratura = pipeline in console + POST a un sink HTTP
  locale, senza cliccare la UI ogni volta.
- Prove a schermo (stessa persona; capo da foto con gruccia, jeans da
  screenshot in DIAGONALE e jeans dritti da foto):
  `docs/verifiche/2026-07-16-su-di-te/risultato-warping-*.jpg`. 178 test.
- **Residui**: la mano davanti alla coscia può scoprire una scheggia del
  pantalone originale; braccia molto piegate/pose dinamiche non seguite
  (le maniche restano row-based); mobile da verificare (24MB @imgly +
  ~20MB MediaPipe al primo uso).
- **DECISIONE FINALE (2026-07-16): la strada fotorealistica è CHIUSA.**
  Lorenzo ha valutato e rifiutato sia Gemini a pagamento sia il generativo
  locale (in browser non esiste per il try-on; sul Mac servirebbe un server
  personale sempre acceso). Il warping è il punto d'arrivo della prova
  gratis: da qui in poi si aspetta il feedback di Mary da mobile.

## Novità 2026-07-16 — scheda "Su di te": la persona vera vestita, gratis on-device

Richiesta di Lorenzo: «il risultato possibilmente senza avatar e con una foto di
persona vera, e questa persona deve essere vestita con i capi caricati sia da
link, che da screenshot che da foto, queste ultime due ovviamente scontornate»,
«le proporzioni devono essere per la persona caricata nella foto, anche quella
scontornata», «si può evitare l'AI di Google? facciamo girare tutto in locale».

**FATTO e verificato a schermo** (branch `feat/scontorno-imgly` → `main`).
Niente Google, niente costi: tutto on-device.

- **Terza scheda in /tryon**: "Sull'avatar" | **"Su di te"** | "Sulla tua foto (AI)".
  Arrivando con outfit pronto + foto di riferimento caricata si apre direttamente
  "Su di te" (richiesta esplicita: vedere la persona, non l'avatar).
- **Pipeline**: foto persona → scontorno @imgly (stessa cache IndexedDB dei capi,
  id riservato `__person__`) → `personSilhouette.js` (puro: riquadro, spalle,
  fianchi, cavallo, caviglie dall'alpha) → `modelComposer.js` (puro: rettangoli
  di posa scalati sulle proporzioni REALI del corpo) → `ModelTryOn.jsx` (SVG:
  sfondo studio, ombra a terra, persona, capi sopra).
- **Scontorno esteso agli screenshot**: `loadGarmentTexture` non li blocca più a
  tinta unita — @imgly isola il capo anche da uno screenshot intero di shop
  (verificato: pagina prodotto finta 1280px → solo i jeans addosso). Il
  geometrico resta escluso (piastrella/stampa pescherebbero UI): piatta = tinta
  unita per gli screenshot, 3D e "Su di te" = capo scontornato.
- **textureUrl ora ritagliato al contenuto** (`garmentContentBounds`): senza i
  margini trasparenti del frame intero (sennò sui pannelli 3D il capo da
  screenshot arrivava minuscolo) e **senza il gancio della gruccia** (righe
  strette in cima scartate — le foto di capi appesi sono comunissime).
- **Lezioni dai dati veri** (diagnosi in console sulle funzioni pure, non dai test):
  1. le spalle NON sono "la riga più larga in alto": le braccia scostate vincono
     già a metà torace → riga fissa al 18% dell'altezza (antropometria);
  2. la mano scontornata può staccarsi dal corpo → i fianchi misurano solo la
     corsa che contiene l'asse, e il cavallo dev'essere un vuoto A CAVALLO
     dell'asse (sennò la fessura braccio-fianco sembra il cavallo);
  3. scarpe: foto con aspect ≥ 1.4 = già un paio → disegnata una volta sola,
     sotto i piedi; foto strette = una copia per piede.
- **Tarature a schermo**: top 1.3× spalle (colletto a -4% altezza), pantaloni
  vita = cavallo - 13%, orlo alla caviglia, cap larghezza 1.25× fianchi.
- **Prova end-to-end (2026-07-16)**: persona vera da foto stock a figura intera;
  t-shirt nera DA FOTO (appesa a gruccia), jeans DA SCREENSHOT (pagina shop
  finta con UI), sneakers DA LINK (og:image Wikipedia, CORS ok). Risultato:
  `docs/verifiche/2026-07-16-su-di-te/`. 162 test verdi.
- **Residui**: capi da link con CDN senza CORS restano foto intera (non
  scontornabile in browser — per spec va bene); le maniche/orlo del vestito
  originale della persona possono spuntare (collage 2D, niente warping);
  @imgly su mobile ancora da verificare (24MB WASM).
- In questo giro è entrato anche il **genere dell'avatar** (M/F, sagome busto
  SVG + profili mesh 3D, chip nell'editor) e la **piatta a piastrella di
  tessuto** (capo con tessuto reale = piastrella clippata nella sagoma + stampa
  riappoggiata, come nel 3D).

## Situazione attuale (2026-07-10)

**L'app è ONLINE in MODALITÀ CLOUD: account veri, dati e foto su Supabase.**

**Avatar 3D ONLINE dal 2026-07-10** (branch `avatar-3d` unito a `main`, approvato
da Lorenzo: «per ora va bene»). **Ora si aspetta il feedback di Mary**: nessun
altro sviluppo dell'avatar finché non l'ha provato. Vedi la sezione "Avatar 3D".

**Prossimo lavoro già deciso, non ancora iniziato:** il proxy Gemini (§9 della
spec) — oggi la scheda AI pretende che sia l'utente a crearsi chiave e
fatturazione su Google, e Mary non lo farà mai.

- **Feedback di Mary (2026-07-09): positivo** — "va bene", continuerà a provarla.
  Il nome resta "StyleVault" finché non se ne sceglie uno definitivo.
- **App live:** https://fara2106.github.io/stylevault/ — dal 2026-07-09 il sito
  pubblico è la versione cloud (registrazione vera; niente più capi demo).
  Chi aveva dati nella vecchia demo locale li ha ancora nel proprio browser,
  ma nel cloud si riparte da zero: Mary deve registrarsi.

## Avatar 3D (branch `avatar-3d`, 2026-07-10) — da approvare

Segnalazione di Lorenzo: «l'avatar non è 3D ma è piatto» e «i vestiti non si
inseriscono correttamente».

- **Il "piatto" non era un bug**: la spec del 2026-07-07 prescriveva "Figura 2D
  stilizzata SVG". Non è mai stato 3D.
- **I vestiti sì, ed è stato riprodotto.** In `AvatarSvg.jsx` la foto del capo
  entrava con `preserveAspectRatio="xMidYMid slice"` dentro una `clipPath` a
  forma di indumento, in riquadri 68×238 (rapporto 1:3,5). Da una foto quadrata
  sopravviveva solo la **striscia centrale, il 28% della larghezza**: le gambe si
  riempivano di sfondo. Nessuno scontornava il capo. Screenshot del prima/dopo in
  `docs/verifiche/2026-07-09-avatar-3d/`.

**Cosa c'è ora**, a scelta dell'utente (richiesta di Lorenzo: "metti tutto a
scelta, con le spunte, poi sta a lei decidere", "esponendo anche quanto costa"):

| Modalità | Cosa fa | Costo |
|---|---|---|
| 3D | corpo e capi three.js generati da codice, si ruota col dito | gratis |
| Piatto | il capo scontornato, intero, appoggiato sul corpo | gratis |
| Sulla tua foto (AI) | Gemini: il capo esatto addosso, immagine ferma | ~$0,04/foto |

- Pipeline: `garmentTexture.js` (puro, testato: maschera dello sfondo dai quattro
  angoli, rettangolo del capo, colore dominante) → `garmentImage.js` (canvas,
  sottile) → `AvatarSvg` / `Avatar3D`.
- **La `clipPath` è sparita dal percorso principale**: il capo scontornato ha lo
  sfondo trasparente, non serve infilarlo in una sagoma. Le sagome restano solo
  per il caso degradato (tinta unita).
- `Avatar3D.jsx` è l'unico file che importa three.js, caricato con `React.lazy`:
  chunk separato da 492 kB (124 kB gzip), scaricato **solo** aprendo `/tryon`.
- Corpo e capi sono mesh generate da codice (nessun GLB, nessuna licenza): la
  corporatura di `avatar_config` resta un parametro, lo slider continua a valere.
- Rete di sicurezza: se il renderer WebGL non si crea (memoria satura su Android)
  o il context si perde a metà sessione, si passa da soli alla modalità piatta.
  C'è un ErrorBoundary. **Verificato rompendo il renderer di proposito**: niente
  schermo bianco.
- 96 test Vitest verdi. Verifica a schermo con Chrome: 3D vestito, rotazione,
  piatto, fallback senza WebGL, 0 errori in console.

### Secondo giro (2026-07-10): smettere di incollare la foto

Feedback di Lorenzo sul 3D: «non è proprio bellissima l'immagine sull'avatar» e
«il logo sarebbe carino vedere dove è posizionato nel capo, e mantenere quella
coerenza». Era lo stesso errore del bug originale, in tre dimensioni: la foto
veniva incollata su una superficie curva davanti al corpo, si vedeva il *disegno*
della maglietta schiacciato su un torso che ha già la sua forma, e i pantaloni
incollati su un'unica superficie che abbracciava le due gambe sembravano una gonna.

Ora **la forma la fa la mesh, il tessuto la foto**:
- i capi sono parti vere (`garmentParts`): busto **con le maniche**, due gambe
  separate, due scarpe;
- il materiale è una **piastrella di tessuto** ritagliata *dentro* il capo
  (`fabricSwatch`, lontana dai bordi e dalla stampa) e ripetuta: righe e quadri
  si vedono, il contorno disegnato del capo no;
- la **stampa** viene riappoggiata nel punto in cui stava sul capo fotografato
  (`printRegion` + `printPlacement` + `printAt`): un logo sul taschino resta sul
  taschino. Sui capi sdoppiati va su una gamba sola, quella giusta;
- ombra a terra, luci più contrastate, e via il decal cilindrico che sporgeva.

**Quattro difetti che nessun test poteva vedere**, trovati a schermo e
diagnosticati interrogando le funzioni pure nel browser sulle foto vere:
1. la piastrella pescava il logo → ripetuto a pois su tutto il capo;
2. le righe chiare sparivano: distavano dallo sfondo **esattamente** quanto
   `BG_TOLERANCE` (32) e, toccando il bordo del capo, il riempimento se le
   mangiava dai lati. Tolleranza portata a **24**;
3. `printRegion` non trovava **mai** una stampa su una foto reale: l'anello di
   pixel sfumati fra capo e sfondo (antialiasing) sembrava stampa e faceva
   rinunciare. Ora si erode il bordo di 3 px (erosione separabile);
4. sui jeans i pixel diversi dal tessuto erano **due macchie staccate** (la toppa
   e una cucitura all'inguine): il rettangolo unione era vuoto all'81% e veniva
   scartato. Ora si prende la **macchia connessa più grande**, e una stampa deve
   riempire almeno il 25% del proprio rettangolo (un orlo è un anello vuoto).

Modalità piatta: i pantaloni si fermavano a metà polpaccio perché a strozzarli
era la **larghezza** del riquadro, non l'altezza (`meet` scala sul lato più
stretto). Riquadro `bottom` da 76 a 96.

Prove a schermo: `docs/verifiche/2026-07-10-avatar-bellezza/` — due magliette
identiche col logo in punti diversi, e il logo si sposta di conseguenza.

**Difetti cosmetici che restano**: la testa non ha volto; la forma del capo è
generica (una maglietta è "una maglietta"). Il capo esatto addosso lo dà solo la
scheda "Sulla tua foto (AI)".

Piano del secondo giro: `docs/superpowers/plans/2026-07-10-avatar-3d-bellezza.md`
Spec: `docs/superpowers/specs/2026-07-09-avatar-3d-design.md`
Piano: `docs/superpowers/plans/2026-07-09-avatar-3d.md`

**Prossimo progetto, già deciso (§9 della spec): proxy Gemini.** Oggi la scheda AI
pretende che sia l'utente a crearsi chiave e fatturazione su Google: Mary non lo
farà mai. Serve una Edge Function Supabase che tenga la chiave di Lorenzo lato
server. **Vincoli non negoziabili**: solo utenti autenticati (JWT) e quota per
utente contata su Postgres (~20/mese) — la chiave è di Lorenzo e il sito è
pubblico, senza difese chiunque si registri spende i suoi soldi.

---

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
