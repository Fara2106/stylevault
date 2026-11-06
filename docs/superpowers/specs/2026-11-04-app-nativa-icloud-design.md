# StyleVault nativa con iCloud: design

Data: 2026-11-04 · Stato: **decisioni di Lorenzo del 2026-11-04 incluse**; si parte dopo l'iscrizione all'Apple Developer Program · Ramo di partenza: `feat/app-ios`

Aggiornato il 2026-11-06 con la decisione 9: ibrida e sito escono dal repository, restano nel tag locale `archivio-ibrida-e-sito`. Elenco dei percorsi in "Da recuperare dal tag".

## Perché

Lorenzo e Mary hanno deciso di spegnere la versione web. StyleVault diventa un'app solo per iPhone e iPad, con i dati sui dispositivi e nell'iCloud dell'utente. Le ragioni:

- **Pubblicazione più semplice.** Senza account spariscono due blocchi dell'audit del 2026-11-04 (`docs/pubblicazione/2026-11-04-report-app-store.md`): la cancellazione dell'account e l'account demo per il revisore. Lo stesso vale per il rischio 4.2 ("sito impacchettato") e per il backend che si addormenta durante la revisione.
- **Privacy.** Le foto del corpo e il guardaroba non passano mai da un server nostro.
- **Meno da mantenere.** Spariscono Supabase, le Edge Functions, GitHub Pages come app, la libreria AGPL @imgly e il caricamento dei modelli MediaPipe dal CDN.

Il risparmio economico è marginale (oggi Supabase è gratuito): non è il motivo.

## Obiettivi

- Tutte le funzioni di oggi in SwiftUI nativo:
  - guardaroba (aggiunta da foto o da link, dettaglio, preferiti, categorie personalizzate);
  - outfit del giorno con meteo e posizione, outfit salvati;
  - calendario con lo storico di cosa si è indossato, e statistiche;
  - Armocromia;
  - prova dei vestiti e avatar stilizzato (già nativi in gran parte), senza avatar realistico;
  - foto del corpo, tema chiaro e scuro, lingua.
- Dati in **SwiftData con sincronizzazione CloudKit** (database privato dell'utente): stessi dati su iPhone e iPad dello stesso Apple ID, funziona offline.
- **Nessun login.** Ognuno vede i dati del proprio Apple ID. Blocco facoltativo con Face ID, Touch ID o codice del dispositivo.
- Stessi risultati del sito per gli algoritmi: outfit, armonia dei colori, meteo e fasce della giornata, statistiche. I test del sito vengono tradotti in test Swift con gli stessi casi.

## Non obiettivi

- Versione web: non c'è più (decisione 9). Android: si passa con un file esportato dal Profilo, vedi la decisione 9. Chi non ha un dispositivo Apple per ora resta fuori.
- Condivisione di guardaroba o outfit tra persone diverse: CloudKit condiviso si può aggiungere dopo.
- Un nuovo design: si porta lo stile attuale (Palette, font, schermate) in SwiftUI.
- Avatar realistico nella prima versione: vedi la decisione 6.

## Anti-obiettivi (cose che renderebbero il lavoro un fallimento)

- Perdere i dati di Lorenzo e Mary già su Supabase.
- Pubblicare una versione a metà, con una parte su Supabase e una su iCloud: due fonti di dati da tenere allineate.
- Outfit diversi da quelli di oggi a parità di guardaroba e meteo, senza che sia una scelta.

## Decisione chiave: niente migrazione "una schermata alla volta" nell'app pubblicata

Nella chat avevo proposto di sostituire le schermate una alla volta dentro l'app che c'è. Guardando i dati, conviene un'altra strada:

- schermate miste vorrebbero dire guardaroba su Supabase per il sito e su iCloud per le parti native, quindi una sincronizzazione tra i due, lavoro buttato;
- l'app non è ancora pubblicata e gli unici utenti sono Lorenzo e Mary: non c'è nessuno da tenere in servizio durante il cambio.

Quindi l'app nativa si costruisce una fase alla volta su un ramo nuovo. Ogni fase si prova sul simulatore e sui telefoni, e si **pubblica una volta sola**, quando è completa. Il sito già pubblicato resta online finché Lorenzo non decide di pubblicare il ramo, ma nel repository non c'è più (decisione 9).

## Architettura

- **Interfaccia:** SwiftUI, iOS 17 come oggi (SwiftData richiede 17). Tab: Guardaroba, Outfit, + (aggiungi), Calendario, Profilo.
- **Dati:** SwiftData, `ModelContainer` con `cloudKitDatabase: .private("iCloud.it.faraoni.stylevault")`. Modelli (con CloudKit tutte le proprietà devono essere facoltative o avere un valore di default, e niente vincoli `unique`):
  - `Item`: capo con categoria, sottocategoria, colori, stagioni, occasioni, prezzo, preferito, link al negozio, foto davanti e dietro, scontorno;
  - `Outfit`: outfit salvato, cioè i riferimenti ai capi;
  - `CalendarEntry`: data, outfit, indossato sì o no;
  - `WishlistItem`;
  - `Profile`: un solo record, con città predefinita, tema e Armocromia;
  - `BodyPhoto`: davanti, lato, spalle.

  Le foto sono `Data` con `@Attribute(.externalStorage)`: diventano CKAsset in iCloud.
- **Logica:** un pacchetto Swift locale `StyleVaultCore`, senza UI, con i porting di:
  - `outfitAlgorithm`, `outfitAdvice`, `colorHarmony`;
  - `weatherMapper`, `dayParts`, `place`;
  - `statistics`, `categories`, `shopLinks`;
  - `armocromiaSeasons`, `armocromiaClassifier`, `armocromiaWardrobe`, `colorSampling`.

  Test XCTest con i casi presi dai `*.test.js`, così i risultati restano uguali.
- **Visione sul dispositivo, tutta Apple:**
  - scontorno capi e persona: `VNGenerateForegroundInstanceMaskRequest`, già usata nell'app, al posto di @imgly;
  - viso per l'Armocromia: `VNDetectFaceLandmarksRequest` al posto del Face Landmarker di MediaPipe;
  - corpo: `VNDetectHumanBodyPoseRequest` e `VNGeneratePersonSegmentationRequest` al posto del segmenter multiclasse di MediaPipe.
- **Meteo:** WeatherKit se attivo, altrimenti Open-Meteo chiamato direttamente dall'app. Posizione con CoreLocation (già nativa).
- **Link dei negozi:** `LPMetadataProvider` (LinkPresentation) sul telefono al posto di microlink.io e della Edge Function.
- **Feedback:** `MFMailComposeViewController` verso l'indirizzo di Lorenzo, con il ripiego "copia testo" se Mail non è configurata. Nessun server.
- **Avatar realistico e Mobile-VTON:** fuori dalla prima versione (decisione 6). La cartella `Realistic`, il consenso al download, i crediti e la scritta "Powered by Stability AI" di `AvatarView` non entrano nella build. Il codice sta nel tag `archivio-ibrida-e-sito`.

## Cosa sparisce

- Il sito React come app, `WebViewStore`, il ponte `svNative`, `nativeBridge.js`: tolti dal repository il 2026-11-06 (decisione 9).
- Da Supabase, per i dati: tabelle e storage smettono di ricevere dati nuovi dopo la migrazione. Il progetto **non si spegne**: regge gli account della nativa (decisione 8) e tiene i dati di Lorenzo e Mary finché non sono importati. Le migrazioni in `supabase/` e `.github/workflows/keepalive.yml` restano.
- @imgly (AGPL), MediaPipe, onnxruntime-web.
- Dal report dell'audit: blocchi 2 (cancellazione account) e 6 (rete locale in Release: senza WebView non serve neanche in Debug), avvisi 6, 7, 8, 9 (microlink e Resend), 3 (AGPL) e 14 (picsum).

## Cosa resta del web

Nel repository, niente. Il sito pubblicato resta online finché Lorenzo non decide, con le pagine `/privacy` e `/supporto` a cui puntano `AppConfig.privacyURL` e `AppConfig.supportURL`.

Prima dell'App Store serve una **nuova sede** per privacy policy e supporto, perché App Store Connect vuole un URL anche per un'app senza raccolta dati. Dopo si aggiorna `AppConfig`. I testi da cui ripartire sono in `docs/pubblicazione/testi-legali.md` e descrivono ancora ibrida e sito: vanno riscritti per la nativa.

## Migrazione dei dati di oggi

Lorenzo ha 3 capi con foto, 1 voce di calendario, le foto del corpo e l'Armocromia; Mary ha i suoi dati.

Si passa da **Esporta e importa**, nient'altro:

- uno script una tantum, lanciato da Lorenzo con le sue credenziali, scarica capi, outfit, calendario, profilo e foto da Supabase in uno zip nel formato dell'import;
- sul telefono: Profilo → Importa;
- nell'app non arriva una riga di Supabase.

Le due strade pensate prima sono escluse dall'audit: un login Supabase nell'app riporta l'account demo e la cancellazione dell'account, e un import nascosto è vietato dalla regola 2.5.19. Dopo l'import di Lorenzo e Mary Supabase resta acceso per gli account (decisione 8), e i loro dati vecchi non si cancellano finché Lorenzo non lo dice.

## Fasi (ognuna con i suoi test e una prova sul telefono)

1. **Fondamenta:**
   - ramo nuovo e container SwiftData con CloudKit;
   - modelli e `StyleVaultCore` con `categories`;
   - tab e Palette;
   - Profilo con tema, lingua e città.

   Prova: dati che compaiono sull'iPad dopo averli creati sull'iPhone.
2. **Guardaroba:**
   - lista con filtri e preferiti, dettaglio, modifica;
   - aggiunta da fotocamera o libreria, con scontorno Vision e retro del capo;
   - aggiunta da link con LinkPresentation;
   - wishlist.
3. **Outfit:** porting di algoritmo, consigli, armonia, meteo e fasce della giornata, posizione o città, outfit incompleto con avviso, outfit salvati.
4. **Calendario e statistiche:** storico degli outfit indossati e statistiche del Profilo.
5. **Armocromia:** analisi del viso con Vision, stagioni, consigli sul guardaroba. Va verificato che i risultati siano vicini a quelli di MediaPipe, perché i punti del viso sono diversi. La logica si recupera dal tag, vedi "Da recuperare dal tag".
6. **Prova vestiti e avatar stilizzato:** riportare dal tag gli schermi nativi già scritti ("Da recuperare dal tag") e collegarli ai dati SwiftData invece che al ponte con il sito. Etichetta "Generato con IA" e "Segnala" solo se nell'app resta un'immagine generata.
   Decisione di Lorenzo del 2026-11-06: se fra i capi scelti c'è un costume, l'app consiglia una foto della persona in costume, non vestita, altrimenti non rende. Nel tag c'è già: `hasSwimwear` in `src/utils/tryOnPrompt.js`, testo `tryon.swimwearPhoto`.
7. **Esporta e importa:** pulsante di esportazione nel Profilo (serve anche per passare ad Android, decisione 9), importazione, script di esportazione da Supabase, import dei dati di oggi. WebView e sito sono già fuori; Supabase e login restano (decisioni 8 e 9).
8. **Pubblicazione:**
   - privacy e supporto nella nuova sede, online prima dell'invio, e `AppConfig` aggiornato;
   - schema CloudKit promosso in Production;
   - Privacy Manifest (già fatto) aggiornato: niente email e nome, foto solo in iCloud, niente E174.1 se non resta nessun download;
   - audit `mobile-app-publishing` ripetuto, TestFlight, invio.

Stima indicativa: le fasi 2, 3 e 5 sono le più pesanti, perché hanno più logica da portare. In tutto alcune settimane di lavoro a sessioni.

## Prerequisiti

- **Apple Developer Program a pagamento: attivo dal 2026-11-05**, Team ID `599MS2BZ63`, come Individuale. Il container iCloud si crea sull'App ID.
- In Debug CloudKit usa l'ambiente "Development". Prima dell'invio lo schema va promosso a "Production" dalla CloudKit Console.

## Rischi

- **Armocromia con Vision:** Vision dà meno punti del viso di MediaPipe (76 contro 478). Il campionamento di pelle, occhi e capelli va ritarato. Se la qualità cala troppo, si tiene MediaPipe in versione iOS (Apache 2.0).
- **Analisi del corpo:** la segmentazione persona di Apple non distingue capelli, vestiti e pelle come il modello multiclasse. Va verificato a cosa serve oggi (`bodyAnalysis.js`) e se la posa basta.
- **Spazio iCloud:** le foto pesano sull'iCloud dell'utente. Si comprimono come oggi, a 1600 px JPEG 0,85.
- **CloudKit:** la sincronizzazione non è immediata e non c'è modo di vedere i dati dell'utente per aiutarlo. Il supporto passa solo dal feedback.

## Decisioni di Lorenzo (2026-11-04)

1. **Prima Apple (iPhone e iPad), Android si decide dopo.** Se arriverà, sarà un'app a sé, con i dati su Google Drive (cartella privata dell'app). Le due versioni non si scambiano dati: ciascuna resta nel suo ecosistema, e la privacy è gestita da Apple e Google. La logica in `StyleVaultCore` e i suoi test di parità fanno da specifica per il futuro porting Android.
2. **Armocromia facoltativa.** Va nella fase 5. Se Vision non basta per un risultato affidabile, la funzione si nasconde e si rimanda, senza bloccare la pubblicazione. Niente Armocromia "a metà". In ogni caso l'utente può **scegliere la sua stagione a mano** da un menu a tendina nel Profilo: vale anche se l'analisi non c'è o non lo convince, e i consigli sul guardaroba usano la stagione scelta.
3. **Lingue:** italiano e inglese da subito, con String Catalog (`Localizable.xcstrings`, `InfoPlist.xcstrings`). In futuro francese, spagnolo, portoghese, inglese UK e inglese USA. Per l'inglese USA servono anche i gradi Fahrenheit e le unità locali (`Measurement` e `formatted()` di sistema), non solo le parole. Le unità si **regolano nelle Impostazioni dell'app** (temperatura °C/°F, ed eventuali misure), con il valore iniziale preso dalla regione del telefono.
4. **Si parte dopo l'iscrizione all'Apple Developer Program.** Lorenzo avvisa quando è accettato.
5. **Import dei dati di oggi:** con Esporta e importa, vedi "Migrazione dei dati di oggi". Era da decidere all'avvio della fase 7, ma l'audit ha escluso le altre due strade.
6. **Prima versione senza avatar realistico (2026-11-05).** Mobile-VTON è addestrato su DressCode, che ha una licenza solo ricerca. Il codice va tolto dalla build, non nascosto con un interruttore (regola 2.5.19). Spariscono anche il download da 1,3 GB e l'entitlement `increased-memory-limit`. Il codice resta nella storia di git e il motore sta dietro `RealisticTryOn`, quindi può tornare in un aggiornamento, se arriva il permesso di AImageLab o se FASHN VTON regge sul telefono e l'origine dei suoi dati è chiarita (`tools/avatar-fashn/README.md`).
7. **Niente login, blocco facoltativo con Face ID (2026-11-05).** Lorenzo ha valutato l'accesso con Apple, Google e password e l'ha scartato: i dati restano su iCloud, personali e legati all'Apple ID, quindi su App Store ognuno ha già i suoi. Un login avrebbe richiesto un servizio di account sempre acceso, con guardaroba e foto del corpo degli utenti a carico suo, più account demo e cancellazione dell'account. Il Profilo offre invece un blocco facoltativo: vale per il singolo dispositivo, non si sincronizza e non può mai chiudere fuori la persona, perché dopo Face ID resta il codice del dispositivo.

8. **Accesso con Apple, Google, email e password, facoltativo (2026-11-05, sera).** Lorenzo ha rovesciato la decisione 7 sul login: la nativa, che è l'app su cui punta, deve avere Accedi con Apple, Accedi con Google, email, password e "Password dimenticata?". Ha scelto il minimo: i dati restano su iCloud e l'account non li sposta. Gli account stanno sul progetto Supabase esistente, che quindi non si spegne alla fine. Scelta di Claude, da confermare: si può entrare con "Continua senza account", perché Apple (5.1.1(v)) respinge il login obbligatorio quando le funzioni non dipendono dall'account. Il blocco con Face ID resta. Servono cancellazione dell'account nell'app, privacy manifest con i dati dell'account e, prima dell'App Store, la revoca del token di Apple quando si cancella l'account.
9. **Niente più ibrida né sito nel repository, Android con un pulsante di esportazione (2026-11-06).** Parole di Lorenzo: «elimina ogni riferimento alla versione ibrida, anche quella del web, almeno non si calpestano i piedi... per passare ad android metteremo un pulsante per esportare i dati». Nel repository restano solo `StyleVaultNative` e `StyleVaultCore`, più `supabase/` e `keepalive.yml`, che servono agli account e ai dati già salvati. Il resto sta nel tag `archivio-ibrida-e-sito`. Il sito pubblicato resta online finché Lorenzo non decide di pubblicare il ramo. L'esportazione è un pulsante nel Profilo, che produce il file descritto in "Esporta e importa" qui sotto: non è ancora costruito, va nella fase 7. Questa decisione aggiorna la 1: le versioni Apple e Android restano separate, ma i dati passano dall'una all'altra con quel file.

## Proposte aggiunte

- **Esporta e importa (approvato da Lorenzo)** un file (JSON più foto, in uno zip) da Profilo: serve per cambiare telefono tra Apple e Android quando ci sarà, e copre il diritto alla portabilità del GDPR.

## Correzioni dall'audit (2026-11-05)

Vengono dalla sezione 00 del report `docs/pubblicazione/2026-11-04-report-app-store.md`, che ha i dettagli.

- **L'app funziona senza iCloud.** Il dispositivo del revisore può non averlo. Con iCloud assente o pieno, SwiftData salva in locale e l'app mostra solo l'avviso "sincronizzazione non attiva": non si blocca e non chiede di accedere a iCloud. Va nella fase 1.
- **Niente funzioni nascoste.** Ciò che non è pronto si toglie dalla build, compresa l'Armocromia se si rimanda: nessun interruttore da accendere dopo la revisione (2.5.19).
- **Privacy e supporto.** Per ora `fara2106.github.io/stylevault/privacy` e `/supporto`, scritti in `AppConfig`. Prima dell'App Store serve una nuova sede, vedi "Cosa resta del web". L'email di contatto è da confermare con Lorenzo.
- **Privacy Labels.** I dati in iCloud sono nel database privato: lo sviluppatore non può leggerli, da riconfermare sulle domande di App Store Connect. Il feedback via Mail dà a Lorenzo email e testo: si dichiara, o si valuta se è raccolta rara e facoltativa.
- **Meteo.** Con Open-Meteo si dichiara "Posizione approssimativa", non collegata all'utente, si arrotondano le coordinate a 2 decimali e lo si nomina nella privacy policy. Con il programma attivo WeatherKit si può accendere: scelta da fare nella fase 3. Se resta solo WeatherKit, Open-Meteo esce dalle dichiarazioni.
- **Cina continentale.** Si esclude in App Store Connect, se restano i link a ChatGPT e Gemini.
- **iPad.** `TARGETED_DEVICE_FAMILY "1,2"`, layout vero per iPad e screenshot iPad 13". Se l'invio slitta ad aprile 2027 o dopo, servono anche gli screenshot per iPhone Duo.
- **App Store Connect.** Questionario dell'età, Accessibility Nutrition Labels solo per ciò che è provato, stato DSA, che decide Lorenzo, e note al revisore su cosa distingue l'app nella categoria (4.3(b)).

## Da recuperare dal tag

Il tag locale `archivio-ibrida-e-sito` (commit `57ab124`) contiene ibrida e sito al momento della rimozione. Per leggere un file: `git show archivio-ibrida-e-sito:src/utils/tryOnPrompt.js`. Per riportarlo nel lavoro: `git checkout archivio-ibrida-e-sito -- ios/StyleVault/Avatar`. Con il primo push del ramo va pubblicato anche il tag.

**Fase 5, Armocromia**
- Logica: `src/utils/armocromiaClassifier.js`, `armocromiaSeasons.js`, `armocromiaWardrobe.js`, `colorSampling.js`, con i rispettivi `*.test.js`, e `shopLinks.js` con il suo test per i link ai negozi.
- Analisi del viso da rifare con Vision: `src/utils/faceColorAnalysis.js`, che usa MediaPipe.
- Schermata: `src/pages/ArmocromiaPage/`.
- Testi: gruppo `armocromia` in `src/i18n/it.json` ed `en.json`.

**Fase 6, prova vestiti, foto del corpo e avatar stilizzato**
- Schermi nativi: `ios/StyleVault/Avatar/` (senza `RealisticComposer.swift`), `ios/StyleVault/Onboarding/`, `ios/StyleVault/Vision/`. `AvatarView.swift` usa ancora il realistico: consenso, crediti e scritta "Powered by Stability AI" vanno tolti, come dice la decisione 6.
- Test nativi: `ios/StyleVaultTests/AvatarRenderTests.swift`, `BodyPhotosModelTests.swift`, `GarmentLayoutTests.swift`, `VisionTests.swift`, e le foto `jeans.jpg`, `maglione.jpg`, `persona.jpg`, `sneakers.jpg` in `ios/StyleVaultTests/Fixtures/`. I test di Vision giravano su macOS, nel target `StyleVaultVisionTests` di `ios/project.yml`.
- Logica del sito: `src/utils/tryOnPrompt.js` (`hasSwimwear`), `bodyPhotos.js`, `bodyAnalysis.js`, `personSilhouette.js`, `modelComposer.js`, `modelWarp.js`, `tryonComposer.js`, `garmentClassifier.js`, `garmentImage.js`, `garmentTexture.js`, `garmentCutoutCache.js`, `tryOnShare.js`, con i rispettivi `*.test.js` dove ci sono. Foto di prova in `src/utils/__fixtures__/`.
- Schermate del sito: `src/pages/TryOnPage/`, `src/pages/OnboardingPage/`, `src/components/Avatar/`, `src/components/BodyPhotos/`.

**Fase 7, esportazione e import**
- Come si leggono i dati da Supabase: `src/services/db.js`, `src/utils/accountCleanup.js`, `ios/StyleVault/Profile/ProfileService.swift` per le foto del corpo. Le tabelle sono in `supabase/migrations/`, che restano nel repository.

**Altre parti che potrebbero tornare**
- Meteo di Apple (WeatherKit): `ios/StyleVault/Weather/AppleWeather.swift`, `AppleWeatherPayload.swift`, `ios/StyleVaultTests/AppleWeatherPayloadTests.swift`.
- Segnalazioni: `src/pages/FeedbackPage/`, `src/services/feedback.js`, `ios/StyleVault/Web/DeviceInfo.swift`. La Edge Function `send-feedback` resta in `supabase/`.
- Avatar realistico (decisione 6): `ios/StyleVault/Realistic/`, `ios/StyleVault/Avatar/RealisticComposer.swift`, `ios/RealisticBench/`, `ios/RealisticBenchTests/`, `ios/RealisticBenchMacTests/`, `ios/StyleVaultTests/Fixtures/realistic/`, `tools/avatar-realistico/` con le licenze dei modelli, `tools/avatar-fashn/`.
- Testi del sito: `src/i18n/it.json` ed `en.json`.
- Script `tools/nativa/`: `export-strings.mjs` generava i cataloghi dei testi, ma il 2026-11-06 era già fermo: rilanciato avrebbe cancellato i testi aggiunti dopo. Da allora `Localizable.xcstrings` si modifica direttamente. `export-core-fixtures.mjs` ha prodotto `catalog.json`, che resta nelle fixture di `StyleVaultCore`.

## Lasciato a chi costruisce

Struttura delle viste, navigazione interna, nomi dei tipi, ordine dei porting dentro una fase, tarature di Vision, purché i test di parità con il sito restino verdi.
