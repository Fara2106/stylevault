# MEMORIA.md — Stato del progetto StyleVault

> File di ripartenza: se apri una nuova chat, leggi questo file per riprendere il lavoro
> esattamente da dove eravamo. Va aggiornato a ogni avanzamento significativo.

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
