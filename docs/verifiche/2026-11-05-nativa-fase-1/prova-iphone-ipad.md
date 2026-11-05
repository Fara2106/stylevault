# Prova della fase 1 su iPhone e iPad

Data: 2026-11-05. Ramo `feat/app-nativa`. Stesso Apple ID su entrambi i dispositivi.

## Dispositivi

- iPhone di Lorenzo iPhone 18 Pro Max iOS 27.2
- iPad di Lorenzo iPad Pro 13-inch (M4) iOS 27.2

L'app è stata firmata col team 599MS2BZ63, profilo di sviluppo valido fino al 05/11/2027. Il primo
build ha associato il container `iCloud.it.faraoni.stylevault`.

## Esito

Lorenzo ha fatto le prove a mano. Ha riferito "sul profilo funziona tutto" dopo le prove di
sincronizzazione e blocco, e "sì, tutto ok" dopo la reinstallazione.

| Prova | Esito |
|---|---|
| Installazione su iPhone e iPad, ibrida ancora presente | ok |
| Città e tema da un dispositivo all'altro | ok, secondo Lorenzo; tempi non annotati |
| Blocco con Face ID, vero, sull'iPhone | ok, secondo Lorenzo; passi non confermati uno per uno |
| Reinstallazione sull'iPad: tornano Napoli e tema scuro, non Milano | ok |
| Modifica senza rete | non confermata a parte; Napoli è stata scelta in quella prova ed è tornata da iCloud |
| iCloud spento per l'app: compare l'avviso | **non confermata a parte: da ripetere** |

## Test automatici, ripetuti una suite alla volta

- `StyleVaultCore`: 8 test, nessun fallimento.
- `StyleVaultNative` su simulatore iPhone 18 Pro: suite unitaria e 5 test UI verdi.
- `StyleVaultNative` su simulatore iPad Pro 11": verde prima di questa prova.
- `StyleVault`, app ibrida: 138/138.

## Decisioni prese durante l'esecuzione

- Ruling: niente worktree, si lavora nella cartella principale sul ramo feat/app-nativa — Secrets.xcconfig non è in git e la compilazione dell'ibrida ne ha bisogno, inoltre il ramo contiene tutto feat/app-ios — se un'altra sessione lavora qui, vede il ramo cambiato.
- Ruling: Task 9 viene eseguito dopo la revisione finale, con Lorenzo — crea il container iCloud, che non si cancella, e serve la sua presenza — costo se sbagliato: nessuno, solo ordine.
- Task 5: Ruling: test del brief cambiato tenendo il ModelContainer in una proprietà — mainContext non trattiene il container, senza si va in crash; asserzioni invariate — costo se sbagliato: nessuno
- Task 6: Ruling: SyncMonitor si registra solo con .cloud, non anche con .localOnly come dice il brief — con .localOnly lo stato è sempre .unavailable, ascoltare non cambia nulla — costo se sbagliato: una riga
- Task 6: Ruling: promosso a fix anche il lampo dell'avviso all'avvio (Minor per il revisore) — l'utente lo vedrebbe a ogni apertura — costo se sbagliato: nessuno
- Task 7: Ruling: plutil -lint rifiuta il JSON degli xcstrings, validato con plutil -convert xml1 — il brief chiedeva lint, ma l'obiettivo è JSON valido — costo se sbagliato: nessuno
- Ruling: il 2026-11-05 Lorenzo ha chiesto Apple, Google e password nell'app nativa, contro "niente login" del design — Task 8 prosegue perché modelli e interfaccia non dipendono dal login; Task 9 e revisione finale restano fermi finché il design non è riscritto, perché il Task 9 crea il container iCloud non cancellabile — costo se sbagliato: il Task 8 va ritoccato
- Ruling: login scartato da Lorenzo il 2026-11-05, sostituito dal blocco Face ID (design, decisione 7) — annulla il ruling precedente sul fermo; Task 10 aggiunto al piano, si esegue prima della revisione finale e del Task 9 — costo se sbagliato: un task
- Task 10: Ruling: NSFaceIDUsageDescription in project.yml e non in Info.plist — xcodegen rigenera il plist; verificato nell'app costruita — costo se sbagliato: nessuno
- Task 10: Ruling: file in più App/SystemAuthenticator.swift — tiene isolato l'import di LocalAuthentication — costo se sbagliato: nessuno
- Task 10: Ruling: copertura in una UIWindow propria invece di chiudere il foglio Aggiungi — chiuderlo farebbe perdere le bozze dalla fase 2, la finestra copre anche le presentazioni future — costo se sbagliato: un file
- Task 10: Ruling: promosso a fix isObscured che può restare vero senza tasto, Minor per il revisore — l'effetto è restare chiusi fuori, vietato dal brief — costo se sbagliato: due righe
- Final: Ruling: "iCloud disattivato per l'app" mai provato — passo aggiunto allo Step 3 del Task 9 — costo se sbagliato: una riga nella regola
- Final: Ruling: telefono in francese mostra l'italiano — segue la lingua di origine del design, nessuna chiave grezza — costo se sbagliato: cambiare una impostazione
- Final: Ruling: flag del blocco in UserDefaults e archivio senza cifratura propria — il blocco è uno schermo di privacy, non una cifratura, resta la protezione dati di iOS — costo se sbagliato: nessuno per chi ha il codice sul telefono
- Final: Ruling: ricerca città verso Open-Meteo senza privacy policy — design la rimanda a fase 3 e 8, nulla è pubblicato — costo se sbagliato: da scrivere prima di pubblicare
- Final: Ruling: città predefinita Milano col paese in italiano anche in inglese — la decide la fase 3 col meteo — costo se sbagliato: una stringa
- Final: Ruling: aps-environment development — Xcode lo cambia all'archiviazione, fase 8 — costo se sbagliato: nessuno
- Final: Ruling: .inactive copre anche col Centro di Controllo — richiesto dal brief — costo se sbagliato: un lampo di copertura
- Final: Ruling: una modifica offline su un record già cancellato dall'unione si perde, e una modifica sull'iPad appena reinstallato prima dell'arrivo del Profilo vero vince per intero — azione esplicita su una finestra breve, l'armocromia si salva comunque — costo se sbagliato: il Profilo va fuso campo per campo
- Final: Ruling: suite iPad e ibrida eseguite in parallelo per errore sullo stesso derivedData — entrambe verdi, il Task 9 Step 5 le ripete una alla volta — costo se sbagliato: nessuno

## Dettagli rimandati

- Task 1: CatalogTests non controlla i labelKey nei String Catalog (lo fa LocalizationTests nel Task 7)
- Task 1: tipi Decodable privati nei test duplicano la forma dei pubblici
- Task 1: ios/StyleVaultCore/.gitignore aggiunto fuori brief, serve a non committare .build
- Task 2: ramo HTTP non-2xx di CitySearch.search senza test
- Task 2: risposta non HTTP accettata in silenzio da search
- Task 2: queryItems impostati e poi riscritti in url
- Task 2: minimumLength non applicato in search; lo deve applicare CitySearchModel (Task 8)
- Task 3: Info.plist con versioni scritte a mano invece di MARKETING_VERSION e CURRENT_PROJECT_VERSION
- Task 4: try? in open butta via l'errore del cloud; manca un Logger
- Task 4: testNormaleUsaIlCloud usa .memory, verifica solo la mappatura
- Task 4: RED non eseguito prima dell'implementazione, dichiarato nel report
- Task 5: la scelta fra più armocromie (la più recente) è un'aggiunta dell'implementatore senza test
- Task 5: la fusione conserva solo l'armocromia; gli altri campi dei profili scartati si perdono (cityName); riconsiderare se Profile cresce
- Task 6: refreshAccount concorrente, una risposta vecchia può sovrascrivere una nuova; improbabile
- Task 6: deinit legge una proprietà @MainActor, da rivedere se si passa a Swift 6 stretto
- Task 6: testMonitorTemporaneoNonContattaCloudKit non prova davvero il mancato contatto; il percorso cloud con notifiche non ha test
- Task 6: nessun test sul percorso account .available senza errore a partire da account non noto
- Task 6: se accountStatus() non risponde mai, l'avviso resta spento
- Task 7: tasto + da provare a mano su iPhone e iPad (Color.clear sotto il foglio)
- Task 7: try? in .task(id:) nasconde gli errori di ProfileStore.current
- Task 7: var preferred mai mutata in Release, warning
- Task 7: profiles.first senza ordine, tema incerto finché i doppioni non si uniscono
- Task 7: la comparsa dell'avviso sposta le tab, senza animazione
- Task 8: il foglio Aggiungi su iPad non ha un tasto Chiudi; lo deve aggiungere la fase 2
- Task 8: il selettore a segmenti non mostra l'etichetta Tema
- Task 8: con query troppo corta la fase torna idle solo dopo i 350 ms di attesa
- Task 8: ricerca città mai digitata a mano nel simulatore, coperta solo dai test del modello
- Task 8: schermate inglesi del Profilo non guardate
- Task 8: UIDevice nel test UI legge il runner; regge perché coincide col simulatore
- Task 8: ProfileView passa a update i profiles del render, non riletti dal context
- Task 8: nessun RED eseguito per il test della ricerca vecchia annullata, il RED del round era di compilazione
- Task 8: try? su ProfileStore.current in ProfileView e RootTabView
- Task 10: autenticazione che non risponde lascerebbe isAuthenticating vero; iOS annulla il foglio in background
- Task 10: FakeAuthenticator con lo stesso nome nei test e nell'app
- Task 10: canEnable non osservabile, crea un LAContext a ogni body
- Task 10: ciclo while senza limite in testDueUnlockInsiemeChiedonoUnaVolta
- Task 10: da vedere su dispositivo la richiesta automatica al ritorno da background (flag wasInBackground e task in background)
- Task 10: con più scene reali su iPad la copertura segue solo la prima; oggi l'app ha una scena sola
- Task 10: finestra ricreata a scena già attiva non chiede Face ID da sola, resta il tasto Sblocca
- Task 10: scene.windows.first può prendere una finestra che non è la principale
- Task 10: un solo LockWindowController per tutte le scene, da rivedere se si abilitano più finestre su iPad
- Task 10: tema sulla finestra del blocco senza test automatico
- Task 10: spostamento su scena vera scollegata da iOS mai provato, coperto solo con scene finte
- Final: senza rete la ricerca dice Nessuna città trovata; il piano lo prescrive
- Final: nessun test con una terza lingua
- Final: accountStatus che fallisce una volta tiene l'avviso acceso fino a CKAccountChanged
- Final: quota su .import resta finché un import non riesce, anche dopo aver liberato spazio
- Final: chi scriverà armocromia nella fase 2 dovrà aggiornare updatedAt, serve un setArmocromia
- Final: Profile() fuori da current nasce con updatedAt adesso
