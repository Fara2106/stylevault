# StyleVault nativa con iCloud: design

Data: 2026-11-04 · Stato: **decisioni di Lorenzo del 2026-11-04 incluse**; si parte dopo l'iscrizione all'Apple Developer Program · Ramo di partenza: `feat/app-ios`

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
  - prova dei vestiti e avatar (già nativi in gran parte);
  - foto del corpo, tema chiaro e scuro, lingua.
- Dati in **SwiftData con sincronizzazione CloudKit** (database privato dell'utente): stessi dati su iPhone e iPad dello stesso Apple ID, funziona offline.
- **Nessun login.**
- Stessi risultati del sito per gli algoritmi: outfit, armonia dei colori, meteo e fasce della giornata, statistiche. I test del sito vengono tradotti in test Swift con gli stessi casi.

## Non obiettivi

- Android e versione web: chi non ha un dispositivo Apple resta fuori. Da confermare con Mary, vedi le domande.
- Condivisione di guardaroba o outfit tra persone diverse: CloudKit condiviso si può aggiungere dopo.
- Un nuovo design: si porta lo stile attuale (Palette, font, schermate) in SwiftUI.

## Anti-obiettivi (cose che renderebbero il lavoro un fallimento)

- Perdere i dati di Lorenzo e Mary già su Supabase.
- Pubblicare una versione a metà, con una parte su Supabase e una su iCloud: due fonti di dati da tenere allineate.
- Outfit diversi da quelli di oggi a parità di guardaroba e meteo, senza che sia una scelta.

## Decisione chiave: niente migrazione "una schermata alla volta" nell'app pubblicata

Nella chat avevo proposto di sostituire le schermate una alla volta dentro l'app che c'è. Guardando i dati, conviene un'altra strada:

- schermate miste vorrebbero dire guardaroba su Supabase per il sito e su iCloud per le parti native, quindi una sincronizzazione tra i due, lavoro buttato;
- l'app non è ancora pubblicata e gli unici utenti sono Lorenzo e Mary: non c'è nessuno da tenere in servizio durante il cambio.

Quindi l'app nativa si costruisce **in parallelo**, una fase alla volta, su un ramo nuovo. Ogni fase si prova sul simulatore e sui telefoni, e si **pubblica una volta sola**, quando è completa. Fino ad allora Lorenzo e Mary usano l'app ibrida di oggi.

## Architettura

- **Interfaccia:** SwiftUI, iOS 17 come oggi (SwiftData richiede 17). Tab: Guardaroba, Outfit, + (aggiungi), Calendario, Profilo, come il sito.
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
- **Avatar realistico e Mobile-VTON:** resta com'è (download dalla Release GitHub, crediti, licenze).

## Cosa sparisce

- Il sito React come app, `WebViewStore`, il ponte `svNative`, `nativeBridge.js`.
- Login, `AuthService`, recupero e cambio password, Google e Apple Sign In.
- Supabase: SDK Swift, tabelle, storage, Edge Functions `send-feedback`, `fetch-link-metadata` e `delete-account` (quest'ultima mai pubblicata). Il progetto si spegne dopo la migrazione dei dati.
- @imgly (AGPL), MediaPipe, onnxruntime-web.
- Dal report dell'audit: blocchi 2 (cancellazione account) e 6 (rete locale in Release: senza WebView non serve neanche in Debug), avvisi 6, 7, 8, 9 (microlink e Resend), 3 (AGPL) e 14 (picsum).

## Cosa resta del web

Una sola pagina statica su GitHub Pages con la **privacy policy** e il **supporto**: App Store Connect vuole un URL anche per un'app senza raccolta dati. Breve, perché i dati restano sui dispositivi e in iCloud.

## Migrazione dei dati di oggi

Lorenzo ha 3 capi con foto, 1 voce di calendario, le foto del corpo e l'Armocromia; Mary ha i suoi dati. Al primo avvio dell'app nativa, una sola volta: "Hai già usato StyleVault? Accedi per portare qui i tuoi dati". L'app:

- si collega a Supabase con il login di oggi, l'ultima volta;
- scarica capi, outfit, calendario, profilo e foto;
- li scrive in SwiftData.

Dopo un periodo concordato si spegne Supabase e il codice di import va tolto in una versione successiva. Alternativa più semplice, se i dati sono pochi: un'esportazione una tantum fatta da Lorenzo e un import nascosto solo per voi due, da togliere prima dell'invio.

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
5. **Armocromia:** analisi del viso con Vision, stagioni, consigli sul guardaroba. Va verificato che i risultati siano vicini a quelli di MediaPipe, perché i punti del viso sono diversi.
6. **Prova vestiti e avatar:** collegare gli schermi nativi che già esistono ai dati SwiftData invece che al ponte con il sito. Etichetta "Generato con IA" e "Segnala".
7. **Import dei dati di oggi**, poi rimozione di WebView, Supabase e login.
8. **Pubblicazione:**
   - pagina privacy e supporto;
   - Privacy Manifest (già fatto) aggiornato: niente email e nome, foto solo in iCloud;
   - audit `mobile-app-publishing` ripetuto, TestFlight, invio.

Stima indicativa: le fasi 2, 3 e 5 sono le più pesanti, perché hanno più logica da portare. In tutto alcune settimane di lavoro a sessioni.

## Prerequisiti

- **Apple Developer Program a pagamento**: serve per CloudKit, oltre che per pubblicare. Il container iCloud si crea sull'App ID.
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
5. **Import dei dati di oggi:** da decidere all'avvio della fase 7.

## Proposte aggiunte

- **Esporta e importa (approvato da Lorenzo)** un file (JSON più foto, in uno zip) da Profilo: serve per cambiare telefono tra Apple e Android quando ci sarà, e copre il diritto alla portabilità del GDPR.

## Lasciato a chi costruisce

Struttura delle viste, navigazione interna, nomi dei tipi, ordine dei porting dentro una fase, tarature di Vision, purché i test di parità con il sito restino verdi.
