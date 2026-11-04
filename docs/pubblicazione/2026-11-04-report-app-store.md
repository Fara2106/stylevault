# Report di pubblicazione: StyleVault

Data: 2026-11-04 · Store: App Store; Google Play escluso perché non esiste ancora un'app Android (il sito resta su GitHub Pages) · Versione: 0.1.0 (build 1), ramo `feat/app-ios` @ f184997

Audit fatto con la skill `mobile-app-publishing` (valori verificati il 2026-11-04) leggendo il codice, `ios/project.yml`, l'Info.plist, le migrazioni e le funzioni Supabase, e le impostazioni di login di Supabase. Non ho ancora fatto un archivio Release né una prova su TestFlight: senza Apple Developer Program a pagamento non si possono fare.

## 00. Stato alla sera del 2026-11-04, dopo la decisione dell'app nativa

Lorenzo e Mary hanno deciso: si pubblica solo l'app nativa con iCloud (`docs/superpowers/specs/2026-11-04-app-nativa-icloud-design.md`). L'app ibrida resta in uso solo a loro due e **non va inviata ad Apple**.

### App ibrida: cosa è cambiato rispetto al pomeriggio

La tabella della sezione 0 non vale più per questi punti:

- **Blocco 2 riaperto.** `delete-account` è stata cancellata da Supabase e risponde 404. Il pulsante "Elimina account" nel codice chiama quindi una funzione che non c'è.
- **Blocco 3 riaperto.** Le pagine `/privacy`, `/supporto` e `/elimina-account` non sono online: GitHub Pages risponde 404, perché il sito non è mai stato ripubblicato. I link Privacy e Supporto del login nativo aprono quindi una pagina 404 (provato sul simulatore).
- **Avviso 8 riaperto.** `fetch-link-metadata` è tornata alla versione di prima: chiunque abbia la chiave pubblica può usarla.
- **Test.** Il resto è verificato: iOS 138/138 e RealisticBench 9/9 su iPhone 18 Pro e iPad Pro 11" (M5), sito 294/294, funzioni 7/7.

### App nativa: il design contro le regole Apple

**Risolti dal design:**
- 5.1.1(v), cancellazione account, e account demo: non c'è login;
- 4.2, "sito impacchettato";
- backend in pausa durante la revisione;
- rete locale e ATS;
- AGPL di @imgly;
- picsum, microlink e Resend.

Restano validi il Privacy Manifest, la crittografia e le versioni.

**Da sistemare nel design prima di partire**, in ordine di gravità:

1. **[Licenze, grave] I dati di addestramento dell'avatar realistico sono "solo ricerca"**
   - Mobile-VTON è addestrato su DressCode e VITON-HD (fonti: paper CVPR 2026, arXiv 2603.00947).
   - La licenza di DressCode (github.com/aimagelab/dress-code, file LICENCE) ammette l'uso "only for the purposes of research, teaching and publication", "academic and non-commercial". Aggiunge che "any other works you make using the Dress Code Dataset" restano sotto gli stessi termini. Il dataset non viene dato alle aziende.
   - VITON-HD è CC BY-NC 4.0, che per un'app gratuita va bene.
   - Una pubblicazione sull'App Store non è ricerca né didattica, anche se l'app è gratuita. Apple non lo controlla in revisione, ma basta una segnalazione per far togliere l'app (5.2.1), e la responsabilità legale resta di Lorenzo.
   - L'audit del mattino aveva controllato solo pesi e componenti, non i dati di addestramento.
   - Scelte possibili:
     - (a) prima versione senza avatar realistico, con l'avatar stilizzato e la prova dei vestiti attuali;
     - (b) chiedere un permesso scritto ad AImageLab (Università di Modena e Reggio Emilia) e agli autori di Mobile-VTON;
     - (c) un modello addestrato su dati con licenza commerciale.
   - Consiglio (a) subito e (b) in parallelo. Con (a) spariscono dalla prima versione anche il download da 1,3 GB, l'entitlement di memoria e buona parte delle protezioni IA della fase 6.
2. **[2.5.19 e 2.1] Import dei dati di oggi**
   - Le due strade del design non vanno nella versione inviata:
     - "Accedi per portare qui i tuoi dati": un login Supabase che il revisore non può usare, e che riporta i problemi dell'account demo e della cancellazione;
     - un import nascosto "solo per voi due": è una funzione nascosta, vietata dalla regola 2.5.19 del 16/10/2026.
   - Soluzione: usare **Esporta e importa**, già approvato. Uno script una tantum, lanciato da Lorenzo con le sue credenziali, scarica i dati da Supabase in uno zip nel formato dell'import. Poi Profilo → Importa sul telefono. Nell'app non arriva una riga di Supabase.
   - Vale lo stesso per l'Armocromia, se la si rimanda: va tolta dalla build, non spenta con un interruttore da accendere dopo la revisione.
3. **[2.1] L'app deve funzionare senza iCloud**
   - Il dispositivo del revisore può non avere iCloud attivo.
   - Con iCloud assente o pieno, SwiftData salva in locale e l'app mostra solo un avviso "sincronizzazione non attiva". Non deve mai bloccarsi o chiedere di accedere a iCloud.
   - Prima dell'invio, lo schema CloudKit va promosso in Production (già scritto nel design).
4. **[5.1.1(i), 1.5] Privacy policy e supporto online prima dell'invio**
   - Oggi i due indirizzi danno 404.
   - Il design prevede una pagina statica su GitHub Pages. Va tenuto lo stesso indirizzo `fara2106.github.io/stylevault/privacy` e `/supporto`, già scritto in `AppConfig`, oppure va aggiornato.
   - Contatto: email da confermare.
5. **[Privacy Labels] Cosa dichiarare nella nativa**
   - **Dati in iCloud (database privato):** lo sviluppatore non può leggerli, quindi per la definizione di Apple non sono "raccolti". Va riconfermato rispondendo alle domande di App Store Connect.
   - **Posizione a Open-Meteo:** è un terzo. Due strade:
     - dichiarare "Posizione approssimativa", per la funzionalità dell'app e non collegata all'utente, e arrotondare le coordinate a 2 decimali (circa 1 km) prima di mandarle;
     - usare solo WeatherKit.

     In entrambi i casi, nominare Open-Meteo nella privacy policy.
   - **Feedback via Mail:** l'utente scrive dalla sua app Mail, ma Lorenzo riceve email e testo. Dichiarare "Email" e "Assistenza clienti", non collegati al tracciamento, oppure valutare se rientra nella dichiarazione facoltativa di Apple (raccolta rara e facoltativa).
   - **Privacy Manifest:** togliere email e nome; restano CA92.1, C617.1 ed E174.1, quest'ultimo solo se resta il download dei modelli.
6. **[Storefront] Cina continentale**
   - Se nella prova dei vestiti restano i link a ChatGPT e Gemini, o la dicitura "Powered by Stability AI", le regole cinesi sull'IA impongono di toglierli.
   - Più semplice: escludere la Cina continentale in App Store Connect.
7. **[2.4.1, screenshot] iPad**
   - Il design è per iPhone e iPad, quindi `TARGETED_DEVICE_FAMILY "1,2"`, con un layout vero per iPad e screenshot iPad 13".
   - Se l'invio slitta ad aprile 2027 o dopo, servono anche gli screenshot per iPhone Duo.
8. **[App Store Connect]**
   - questionario dell'età, con le domande sulle funzioni social (non ce ne sono);
   - Accessibility Nutrition Labels, solo per ciò che è provato;
   - stato DSA: con un'app gratuita e senza monetizzazione, probabilmente "non trader", ma decide Lorenzo;
   - nome "StyleVault": non ho trovato app omonime sull'App Store; lo conferma App Store Connect alla creazione;
   - categoria affollata (4.3(b)): nelle note per il revisore, spiegare cosa la distingue: outfit con meteo e fasce della giornata, Armocromia, analisi sul dispositivo.

**Costi della nativa:** 99 USD l'anno per l'Apple Developer Program. Supabase si spegne dopo l'import, GitHub Pages è gratuito.

**Blocco che resta:** l'iscrizione all'Apple Developer Program (blocco 1).

## 0. Stato dopo le correzioni (2026-11-04, pomeriggio)

Ricontrollato dopo le correzioni. Test: sito 294/294, iOS 138/138, funzioni Supabase 12/12. Prove fatte nel browser in modalità locale e sulle funzioni pubblicate.

| Punto | Stato |
|-------|-------|
| Blocco 1, Apple Developer Program | **Aperto**: tocca a Lorenzo |
| Blocco 2, cancellazione account | **Risolto nel codice**: Profilo → "Elimina account" (sito e app) e funzione `delete-account` pubblicata su Supabase (risponde 401 senza utente). Poi pagina pubblica `/elimina-account`. **Da provare con un account vero**: lo fa Lorenzo |
| Blocco 3, privacy policy e supporto | **Risolto nel codice**: pagine pubbliche `/privacy`, `/supporto`, `/elimina-account` (IT/EN, HTTP 200 su Pages); link nel Profilo, nel login del sito e nel login nativo. Contatto `lorefara97@gmail.com` da confermare |
| Blocco 4, Privacy Manifest | **Risolto**: `ios/StyleVault/Resources/PrivacyInfo.xcprivacy` (CA92.1, C617.1, E174.1, 6 tipi di dati, niente tracking), presente nel bundle |
| Blocco 5, sito pubblicato indietro | **Aperto**: serve l'ok di Lorenzo per unire in `main` e pubblicare |
| Blocco 6, rete locale ed ATS nella Release | **Risolto**: aggiunti solo in Debug da uno script; `SITE_URL` vuoto in Release. Verificato sugli Info.plist compilati |
| Avviso 1, protezioni IA | **Risolto**: "Generato con IA" sulla versione realistica e "Immagine elaborata con IA" nella prova del sito; "Segnala risultato", che apre il Feedback già compilato; dichiarazione sulle foto (app, Profilo, primo accesso) |
| Avviso 2, download da 1,3 GB | **Risolto**: "Scarica (1,3 GB)" alla prima volta, anche in Wi-Fi; dopo "Elimina i modelli" si richiede |
| Avviso 3, @imgly AGPL | **Risolto**: crediti in `/supporto` con il link al sorgente; il repo è pubblico. Deve restare pubblico e allineato a ciò che è online |
| Avviso 4, Open-Meteo | **Risolto**: "Dati meteo: Open-Meteo.com (CC BY 4.0)" sotto il meteo |
| Avviso 8, `fetch-link-metadata` | **Risolto e pubblicato**: solo utenti loggati, link pubblici, redirect controllati (401 senza utente) |
| Avviso 10, crittografia | **Risolto**: `ITSAppUsesNonExemptEncryption = NO` |
| Avviso 11, versioni | **Risolto**: `$(MARKETING_VERSION)` e `$(CURRENT_PROJECT_VERSION)` (0.1.0, build 1) |
| Avviso 14, segnaposto picsum | **Risolto**: segnaposto neutro con l'iniziale, salvato come JPEG |
| Avvisi 5, 6, 7, 9, 12, 13, 15 | Aperti. Per il 9 i fornitori sono nella privacy policy; restano da fare le Privacy Labels in App Store Connect |

Nota: un'altra sessione ha scritto `docs/superpowers/specs/2026-11-04-app-nativa-icloud-design.md` (app nativa con iCloud, senza sito e senza login). Se si fa, cancellazione account, funzioni Supabase e pagine del sito cambiano o spariscono; privacy policy, Privacy Manifest, protezioni IA e consenso al download restano.

## 1. Classificazione

| Caratteristica | Presente | Capitolo applicato |
|----------------|----------|--------------------|
| Registrazione e login | sì: email e password; Google c'è nel codice ma è spento su Supabase; Sign in with Apple pronto ma spento | `conditional/login.md` |
| Backend | sì: Supabase (database, storage, 2 Edge Functions) | `cross-store.md` Sicurezza |
| Dati personali | sì: email, nome, foto del corpo (davanti, lato, spalle), foto dei capi, posizione per il meteo, risultato Armocromia, feedback | GDPR, Privacy Labels, Privacy Manifest |
| App ibrida (sito in WKWebView) | sì: la Release carica `https://fara2106.github.io/stylevault/` | `cross-store.md` 7b |
| IA sul dispositivo | sì: scontorno @imgly (ONNX), MediaPipe (corpo e viso), Vision di Apple, avatar realistico Mobile-VTON (1,3 GB scaricati) | `conditional/ai.md` "Modelli sul dispositivo" |
| Immagini di persone generate o modificate | sì: prova dei vestiti sulla foto della persona | `conditional/ai.md` "Contenuti generati" |
| Dati inviati a IA di terzi | no (tutto sul telefono); i link a ChatGPT e Gemini nella prova vestiti li apre l'utente | — |
| Posizione | sì, solo durante l'uso, per il meteo | `conditional/location.md` |
| Servizi esterni | Open-Meteo, microlink.io, Resend, jsDelivr (WASM), Google Storage (modelli MediaPipe), GitHub Releases (modelli dell'avatar); WeatherKit pronto ma spento | `cross-store.md` |
| Pubblicità, acquisti, abbonamenti | no: l'app deve restare gratuita per la licenza CC BY-NC-SA di Mobile-VTON | — |
| Contenuti degli utenti visibili ad altri | no | — |
| Minori, salute, finanza | no | — |

## 2. Blocchi di rifiuto (6)

1. **[Account] Manca l'Apple Developer Program a pagamento**
   - Dove: `ios/project.yml`, `DEVELOPMENT_TEAM: 599MS2BZ63`, che è il Personal Team gratuito.
   - Effetto: senza il programma non si può creare l'app in App Store Connect né caricare build o usare TestFlight. Restano spenti anche WeatherKit, Sign in with Apple e la capability `increased-memory-limit` sull'App ID.
   - Correzione: iscriversi (99 USD l'anno), poi:
     - creare l'App ID `it.faraoni.stylevault` con la capability Increased Memory Limit;
     - dichiararsi trader o non trader per il DSA.

2. **[Apple 5.1.1(v)] Manca la cancellazione dell'account**
   - Dove: Profilo (sito e app). Oggi c'è solo "Esci".
   - Correzione: aggiungere "Elimina account" nel Profilo, con conferma, che chiama una Edge Function `delete-account`. La funzione:
     - legge l'utente dal JWT;
     - cancella i file dell'utente nei bucket `profile-photos` e dei capi;
     - chiama `auth.admin.deleteUser`.

     Le tabelle si svuotano da sole: hanno `on delete cascade` su `auth.users`. Lo storage invece no.
   - In più serve una pagina web che spieghi come cancellare l'account, linkata dalla privacy policy.

3. **[Apple 5.1.1(i)] Manca la privacy policy**
   - Dove: nel sito non c'è nessuna pagina e nell'app nessun link.
   - Correzione:
     - scrivere una pagina `/privacy` nel sito, specifica e in italiano e inglese. Deve elencare:
       - i dati trattati (account, foto del corpo e dei capi, posizione solo durante l'uso, Armocromia, feedback);
       - dove finiscono (Supabase UE o USA, da verificare nella regione del progetto; Resend per il feedback; microlink.io per i link dei negozi; Open-Meteo per il meteo);
       - che le analisi IA girano sul telefono;
       - la conservazione, i diritti e il contatto.
     - aggiungere il link nel Profilo e in App Store Connect;
     - aggiungere anche un URL di supporto (1.5), per esempio una pagina `/supporto` o una email.

4. **[Apple 5.1.1, Privacy Manifest] Manca `PrivacyInfo.xcprivacy`**
   - Dove: `ios/StyleVault/`.
   - Il codice usa API che richiedono un motivo:
     - `UserDefaults` e `@AppStorage` (`StyleVaultApp.swift:36`, `RealisticAvatarModel.swift:73/84/109`) → `CA92.1`;
     - date dei file (`RealisticAvatarModel.swift:357/361`) → `C617.1`;
     - spazio libero (`RealisticModelStore.swift:137`) → `E174.1`.
   - Correzione: creare il file con `NSPrivacyTracking = false`, le tre categorie qui sopra e i tipi di dati raccolti, coerenti con la privacy policy.

5. **[Apple 2.1, app ibrida] La Release carica un sito pubblicato vecchio**
   - Dove: `AppConfig.swift`, ramo `#else`, che punta a GitHub Pages. Il deploy parte da `main`, fermo al 2026-11-03; `feat/app-ios` ha 61 commit non pubblicati.
   - Effetto: il revisore vedrebbe un sito senza ponte nativo, quindi niente "Rifai le foto del corpo", avatar, meteo nativo né salvataggio dell'Armocromia.
   - Correzione: unire `feat/app-ios` in `main` e pubblicare il sito (lo decidi tu). Poi provare una build Release o TestFlight contro il sito pubblicato.

6. **[Apple 5.1.1(ii), avanzi di sviluppo] Permesso di rete locale e eccezione ATS nella Release**
   - Dove: `ios/StyleVault/Info.plist`, generato da `project.yml` (`info.properties`).
     - `NSLocalNetworkUsageDescription` dice "In sviluppo l'app carica StyleVault dal Mac sulla rete di casa": è un testo per lo sviluppatore, senza funzione per l'utente.
     - `NSAllowsLocalNetworking: true` vale per tutte le configurazioni.
   - Correzione: tenerli solo in Debug, per esempio con un Info.plist separato per Debug o con chiavi `INFOPLIST_KEY_` in `settings.configs.Debug`. Poi controllare l'Info.plist dell'archivio con `plutil -p`.
   - Già che ci sei: `Secrets.xcconfig` è lo stesso per Debug e Release e contiene `SITE_URL` con l'IP di casa. Oggi la Release lo ignora (`#if DEBUG`), ma è meglio non metterlo proprio nella Release.

## 3. Avvisi (15)

1. **[AI Act art. 50, Apple 1.1/1.2] Mancano le protezioni sulle immagini di persone**
   - Dove: avatar realistico e prova dei vestiti.
   - Già fatto: l'intimo non arriva all'avatar (passano solo i capi "sopra" e i capispalla).
   - Manca:
     - l'etichetta "Generato con IA" sul risultato;
     - un pulsante "Segnala risultato";
     - una dichiarazione, alla prima foto, che la foto ritrae te o una persona che ha dato il consenso;
     - la spiegazione di queste protezioni nelle note per il revisore.
   - Nell'UE l'etichetta è un obbligo di legge, non solo una regola dello store.
2. **[Apple 4.2.3(ii)] L'avatar realistico scarica 1,3 GB senza chiedere sul Wi-Fi**
   - Già fatto: su rete cellulare o con Risparmio dati chiede "Scarica comunque".
   - Correzione: chiedere anche sul Wi-Fi, mostrando la dimensione, prima di scaricare.
3. **[Licenze] @imgly/background-removal è AGPL-3.0**
   - Dove: `node_modules/@imgly/background-removal/LICENSE.md`. Gira nel sito, quindi anche nell'app.
   - Obblighi:
     - sorgente completo disponibile a chi usa il servizio: il repo `Fara2106/stylevault` deve restare pubblico e aggiornato;
     - licenza indicata nei Crediti.
   - Se in futuro il sorgente non sarà più pubblico, serve la licenza commerciale di IMG.LY oppure un altro scontorno, per esempio Vision di Apple, già usato nell'app.
4. **[Licenze] Open-Meteo chiede l'attribuzione (CC BY 4.0)**
   - Oggi nell'interfaccia non c'è. Correzione: "Dati meteo: Open-Meteo.com" con il link, vicino al meteo.
   - Il piano gratuito è per uso non commerciale: va bene per un'app gratuita senza pubblicità.
5. **[Apple 4.8] Login con Google**
   - Oggi è spento su Supabase, quindi non c'è obbligo.
   - Se lo accendi, nella stessa versione serve "Accedi con Apple": il codice c'è, con `appleSignInEnabled = false`.
6. **[Apple 2.1] Account demo per il revisore**
   - Creare un account dedicato con capi, foto e calendario d'esempio, senza dati veri.
   - Scrivere le credenziali e il percorso di prova nelle note (6 sezioni).
   - La registrazione è aperta e senza conferma email (`mailer_autoconfirm` attivo), ma il revisore deve trovare subito i contenuti.
7. **[Apple 2.1, backend] Supabase gratuito va in pausa dopo giorni senza uso**
   - Durante la revisione il backend spento equivale a un rifiuto. L'app lo prevede già (messaggio "service-unreachable").
   - Correzione: tenere attivo il progetto nei giorni della revisione, oppure passare al piano Pro (25 USD al mese).
8. **[Sicurezza] `fetch-link-metadata` è pubblicata con `--no-verify-jwt`**
   - Chiunque può usarla come proxy verso URL arbitrari.
   - Correzione: accendere Verify JWT oppure aggiungere un limite per IP e un elenco dei domini ammessi.
9. **[Privacy] Servizi terzi da dichiarare**
   - microlink.io riceve i link dei negozi incollati dall'utente.
   - Resend riceve il testo del feedback e l'email.
   - Dichiararli nella privacy policy e nelle Privacy Labels: "Dati usati per la funzionalità, non collegati al tracciamento".
10. **[Export compliance] Manca `ITSAppUsesNonExemptEncryption = NO` nell'Info.plist**
    - L'app usa solo HTTPS di sistema. Senza la chiave, App Store Connect lo chiede a ogni build.
11. **[Versioni] Versione scritta a mano nell'Info.plist**
    - `CFBundleShortVersionString` è "1.0" e `CFBundleVersion` è "1", mentre `MARKETING_VERSION` è 0.1.0.
    - Correzione: usare `$(MARKETING_VERSION)` e `$(CURRENT_PROJECT_VERSION)`.
12. **[Apple 2.4.1] L'app è solo per iPhone (`TARGETED_DEVICE_FAMILY: 1`)**
    - Su iPad gira in compatibilità e il revisore può usarlo.
    - Provare login, foto, avatar e Armocromia sull'iPad Pro di Lorenzo, compreso il messaggio se la memoria non basta.
13. **[Lingue] Schermate native e testi dei permessi solo in italiano, sito in italiano e inglese**
    - Correzione: se in App Store Connect dichiari anche l'inglese, servono `Localizable` e `InfoPlist.strings` in inglese. Altrimenti dichiarare solo l'italiano.
14. **[Apple 2.1, segnaposto] Capo salvato senza foto**
    - Dove: `AddItemPage.jsx:143`. Un capo salvato senza foto riceve un'immagine casuale da picsum.photos.
    - Effetto: sembra un contenuto finto.
    - Correzione: usare un segnaposto neutro con l'icona della categoria.
15. **[Archivio] Il progetto contiene anche il target `RealisticBench`**
    - Ha bundle id `it.faraoni.stylevault.bench` e il suo schema.
    - Archiviare solo lo schema `StyleVault`. Togliere anche i doppioni `StyleVault 2/3/4.xcodeproj` in `ios/`.

## 4. Controlli superati (12)

- [Apple 4.2] Non è solo un sito impacchettato. Ci sono:
  - login nativo;
  - fotocamera con scontorno e posa sul telefono (Vision);
  - avatar realistico sul dispositivo;
  - posizione nativa;
  - recupero password con link nell'app.
- [SDK] Xcode 27.2, iOS SDK 27.2. Il minimo richiesto è iOS 26.
- [Permessi] Fotocamera, foto e posizione con testi chiari, scritti per l'utente. La posizione è chiesta solo durante l'uso.
- [5.1.2] Niente tracking, ATT né SDK pubblicitari. Nessun dato a IA di terzi.
- [Database] RLS su tutte le tabelle ("own rows") e regole sullo storage per cartella dell'utente.
- [Modelli scaricati] Dimensione mostrata, consenso su rete cellulare, controllo dello spazio libero, SHA-256, ripresa del download, "Elimina i modelli" nei Crediti.
- [Licenze avatar] Crediti nell'app con:
  - CC BY-NC-SA 4.0;
  - "Powered by Stability AI" e la Stability AI Community License;
  - CLIP/OpenCLIP (MIT) e DINOv2 (Apache 2.0).

  Nessuna monetizzazione, quindi è compatibile con la licenza NC.
- [Memoria] Entitlement `increased-memory-limit` dichiarato e protezione dai crash per memoria.
- [WeatherKit] Spento. Quando lo accendi, l'attribuzione Apple (logo e link legale) è già nel `WeatherBadge`.
- [Account] Cambio password nel Profilo; recupero password via email anche nell'app.
- [Sito e app] Cookie solo tecnici, niente analytics. Nessun consenso ePrivacy da chiedere.
- [Metadati] Nessun riferimento ad Android o Google Play nei testi mostrati nell'app.

## 5. Costi

| Voce | Una tantum | Annuale | Mensile |
|------|------------|---------|---------|
| Apple Developer Program | — | 99 USD | — |
| Supabase | — | — | 0 (Free, va in pausa) o 25 USD (Pro) |
| Sito (GitHub Pages), modelli (GitHub Releases) | — | 0 | 0 |
| Resend (feedback) | — | — | 0 nel piano gratuito |
| Dominio proprio (facoltativo, per privacy e supporto) | — | circa 10-15 € | — |
| **Totale pubblicazione** | **99 USD** | | |
| **Totale operatività** | | **99 USD** | **0-25 USD** |

## 6. Passi successivi

1. Iscrizione all'Apple Developer Program. È tua (account e pagamento). Poi:
   - App ID con Increased Memory Limit;
   - app in App Store Connect;
   - dichiarazione DSA.
2. Io: "Elimina account" (pulsante, Edge Function e pagina web) e pagine `/privacy` e `/supporto` con i link nel Profilo.
3. Io: `PrivacyInfo.xcprivacy`, rete locale e ATS solo in Debug, `ITSAppUsesNonExemptEncryption`, versioni da `MARKETING_VERSION`.
4. Io: avatar e prova dei vestiti con:
   - etichetta "Generato con IA";
   - "Segnala risultato";
   - dichiarazione della foto;
   - richiesta prima del download da 1,3 GB anche sul Wi-Fi.
5. Io: attribuzione Open-Meteo, licenze nei Crediti (@imgly AGPL, MediaPipe Apache, Open-Meteo), segnaposto neutro al posto di picsum, Verify JWT su `fetch-link-metadata`.
6. Tu: ok a unire `feat/app-ios` in `main` e pubblicare il sito.
7. Io e te: account demo con dati d'esempio, note per il revisore, archivio Release controllato con `plutil` e `strings`, TestFlight su iPhone e iPad.
8. Scheda dello store:
   - icona 1024;
   - screenshot 6.9" con dati finti;
   - Privacy Labels coerenti con la privacy policy;
   - questionario dell'età.

## 7. Fonti verificate

- Skill `mobile-app-publishing`, valori verificati il 2026-11-04: App Review Guidelines, Privacy Manifest, costi Apple Developer Program.
- Licenza @imgly/background-removal 1.7.0: AGPL-3.0, letta da `node_modules`.
- Impostazioni di login di Supabase lette da `/auth/v1/settings` il 2026-11-04: email sì, Google no, Apple no, conferma email automatica sì.
