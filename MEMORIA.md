# MEMORIA.md — Stato del progetto StyleVault

> File di ripartenza: se apri una nuova chat, leggi questo file per riprendere il lavoro
> esattamente da dove eravamo. Va aggiornato a ogni avanzamento significativo.

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
