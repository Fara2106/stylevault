# SDD ledger — plan: docs/superpowers/plans/2026-11-03-app-ios.md

Spec: docs/superpowers/specs/2026-11-03-app-ios-design.md
Setup: Ruling: branch `feat/app-ios` nella cartella esistente invece di un worktree — dev server, .env.local e node_modules vivono qui — costo se sbagliato: nessuno (stesso isolamento via branch)
Setup: Ruling: in DEBUG la WebView carica il dev server locale in modalità cloud (http://localhost:5181/), in Release il sito pubblicato — i task web 1–3 non vanno pubblicati a metà piano senza ok di Lorenzo — costo: per l'iPhone vero serve pubblicare (task 9, con ok)

## Pre-flight
| Produce | Consuma | Esito |
|---|---|---|
| T3 avatarPayload {id, category, slot, photo, photoBack, name} | T4 AvatarItem | coerente |
| T3 messaggi openAvatar/signOut/themeChanged{setting} | T4 BridgeMessage | coerente (themeChanged → String dal campo setting) |
| T4 BridgeMessage | T7 aggiunge openBodyPhotos | previsto dal piano |
| T2 profiles.body_photos {side,back} + reference_photo_path | T7 ProfileService.loadBodyPhotos | coerente |
| T6 Cutout/Pose/Joint | T7 validate, T8 GarmentLayout | coerente |
| T1 settings.theme 'light'/'dark'/'system' | T9 ThemeStore | coerente |
Task 1: Ruling: il 'light' salvato prima del selettore (mai scelto) vale come Sistema; flag themeChosen alla prima scelta — costo: chi voleva chiaro con telefono scuro deve sceglierlo una volta
Task 1: Ruling: ThemeSwitch riusa lo stile segmentato di LanguageSwitch invece di un CSS nuovo — righe del Profilo coerenti — costo: nessuno
Task 1: Ruling: lo sfondo 'studio' dell'avatar web resta chiaro anche in tema scuro — è parte dell'immagine — costo: contrasto col resto della pagina scura
Task 1: complete (commits 3be205c..8c0cb4b, tests: npm test →    Duration  609ms (transform 1.09s, setup 0ms, import 1.65s, tests 295ms, environment 2ms))
Task 2: Ruling: mantenuto il nome esistente rowToItem (il piano diceva itemFromRow) — nessun rename inutile — costo: nessuno
Task 2: Ruling: foto del corpo con percorsi univoci <uid>/<uuid>.jpg salvati in body_photos, NON body-side.jpg fissi — lo storage ha policy insert/select/delete ma non update, rifare una foto fallirebbe; la vecchia viene cancellata — costo: il nativo (task 7) deve leggere i percorsi da body_photos, non indovinarli
Task 2: Ruling: migrazione 003 NON ancora applicata al database di produzione — è un effetto esterno, la chiedo a Lorenzo insieme alle altre sue azioni — costo: finché manca, NON pubblicare questo branch (la sync impostazioni manderebbe la colonna theme inesistente e fallirebbe anche lingua/città)
Task 2: complete (commits 8c0cb4b..93b7544, tests: npm test →    Duration  611ms (transform 893ms, setup 0ms, import 1.44s, tests 331ms, environment 2ms))
Task 3: Ruling: nessuna pubblicazione del sito a fine task 3 (il piano la prevedeva) — in DEBUG la WebView usa il dev server locale; la pubblicazione richiede l'ok di Lorenzo e la migrazione 003 — costo: per l'iPhone vero si pubblica nel task 9
Task 3: Ruling: nell'app il bottone "Prova" degli outfit diventa "Vedilo addosso" (prop tryOnLabel) e apre l'avatar nativo, invece di un bottone in più — una sola azione chiara sulla card — costo: nell'app non si arriva alla pagina Prova dagli outfit (resta raggiungibile dal dettaglio capo)
Task 3: complete (commits 93b7544..3105bb4, tests: npm test →    Duration  673ms (transform 1.00s, setup 0ms, import 1.68s, tests 304ms, environment 2ms))
Task 4: Ruling: WebViewStore (ObservableObject) tiene WKWebView, onMessage e injectSession; WebContainerView(store:) la mostra — il piano metteva injectSession sulla View, che in SwiftUI non si può chiamare da fuori — costo: nessuno, i task 5–9 usano store.injectSession
Task 4: Ruling: SWIFT_VERSION 5.0 (toolchain Swift 6.4) — evita attriti di concorrenza stretta con WKScriptMessageHandler — costo: passare a 6 più avanti richiede qualche annotazione
Task 4: Ruling: WKWebView a tutto schermo con contentInsetAdjustmentBehavior .never; le zone sicure le gestisce il CSS; fix del selettore lingua del login — costo: altre parti posizionate in assoluto in alto andrebbero controllate (nessuna trovata)
Task 4: Ruling: Localizable.xcstrings rinviato al task 9 (testi nativi per ora in italiano nel codice) — prima si stabilizzano le schermate — costo: l'inglese nativo arriva a fine piano
Task 4: complete (commits 3105bb4..dbe98f4, tests: bash -c 'cd ios && xcodebuild test -project StyleVault.xcodeproj -scheme StyleVault -destination 'id=18361580-2FC8-4A18-AED3-7461008C6569' -derivedDataPath build/dd CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E 'Executed .* tests|TEST (SUCCEEDED|FAILED)' | tail -2' → ** TEST SUCCEEDED **)
Task 5: Ruling: bottone Google nativo visibile solo con provider attivo (AuthService.googleEnabled, +1 test) — coerente col sito, spento darebbe errore — costo: nessuno
Task 5: Ruling: AuthErrorKind ha anche .weakPassword (il piano elencava 5 casi) — Supabase lo restituisce in registrazione — costo: nessuno
Task 5: PENDENTE (Lorenzo): passo 5 — client OAuth Google, provider Google su Supabase, stylevault://auth-callback nelle Redirect URLs; verifica login reale (non posso inserire credenziali su Supabase di produzione)
Task 5: complete (commits dbe98f4..f487e6e, tests: bash -c 'cd ios && xcodebuild test -project StyleVault.xcodeproj -scheme StyleVault -destination 'id=18361580-2FC8-4A18-AED3-7461008C6569' -derivedDataPath build/dd CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E 'TEST (SUCCEEDED|FAILED)'' → ** TEST SUCCEEDED **)
Task 6: Ruling: il simulatore iOS 27 non contiene i pesi dei modelli Vision ("Missing weights path cnn_human_pose", "Could not create inference context"; forzare la CPU non aiuta) → test Vision in un target macOS (StyleVaultVisionTests) che compila StyleVault/Vision — costo: nel simulatore l'avatar e il primo accesso NON possono scontornare; la verifica visiva vera è su iPhone (task 9) o via render su Mac
Task 6: Ruling: PersonCutout.cutout(_:allInstances:) — false per la persona (soggetto più grande), true per i capi (paio di scarpe = 2 soggetti) — il piano aveva un solo parametro — costo: nessuno
Task 6: Ruling: soglia trasparenza della persona di prova 40–97% invece di 40–90% — nella foto la ragazza è ~9% del fotogramma, scontorno controllato a occhio (pulito) — costo: nessuno
Task 6: complete (commits f487e6e..637d5ba, tests: bash -c 'cd ios && xcodebuild test -project StyleVault.xcodeproj -scheme StyleVaultVisionTests -destination 'platform=macOS' -derivedDataPath build/dd 2>&1 | grep -E 'TEST (SUCCEEDED|FAILED)'' → ** TEST SUCCEEDED **)
Task 7: Ruling: anteprima DEBUG `-SVPreviewBodyPhotos` per vedere il primo accesso nel simulatore senza account — nel simulatore non c'è login di prova — costo: codice solo DEBUG nel punto d'ingresso
Task 7: Ruling: se il profilo non si legge (rete, migrazione 003 non applicata) si entra senza chiedere le foto — non bloccare l'app — costo: le foto mancanti si fanno dal Profilo
Task 7: Verifica: schermata resa nel simulatore (tema scuro ok); il selettore Foto di sistema resta su "Loading..." nel simulatore e Vision non ha i modelli lì → flusso foto→scontorno→salvataggio da provare su iPhone (task 9)
Task 7: complete (commits 637d5ba..4443351, tests: bash -c 'cd ios && xcodebuild test -project StyleVault.xcodeproj -scheme StyleVault -destination 'id=18361580-2FC8-4A18-AED3-7461008C6569' -derivedDataPath build/dd CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E 'TEST (SUCCEEDED|FAILED)'' → ** TEST SUCCEEDED **)
Task 8: Ruling: composizione in AvatarComposer (CoreGraphics puro, compilato anche nel target macOS) invece che solo in SwiftUI — permette di vedere l'avatar vero sul Mac visto che il simulatore non ha Vision — costo: nessuno
Task 8: Ruling: taratura a schermo diversa dai valori di partenza del piano — top largo max(1.3×spalle, 0.9×sagoma), colletto a −12% del busto, jeans fino a metà tra caviglia e pianta, scarpe sulla pianta larghe ≥ 0.6×sagoma — le spalle di Vision sono i giunti (più strette della persona) — costo: altre pose (braccia lungo i fianchi) possono dare top un po' larghi; i test sintetici restano verdi
Task 8: Verifica: render Mac persona+maglione+jeans+sneakers (docs/verifiche/2026-11-03-app-ios/avatar-davanti-mac.png); AvatarView sul simulatore non apribile (login + Vision) → da provare su iPhone
Task 8: complete (commits 4443351..1a59352, tests: bash -c 'cd ios && xcodebuild test -project StyleVault.xcodeproj -scheme StyleVault -destination 'id=18361580-2FC8-4A18-AED3-7461008C6569' -derivedDataPath build/dd CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E 'TEST (SUCCEEDED|FAILED)'; xcodebuild test -project StyleVault.xcodeproj -scheme StyleVaultVisionTests -destination 'platform=macOS' -derivedDataPath build/dd 2>&1 | grep -E 'TEST (SUCCEEDED|FAILED)'' → ** TEST SUCCEEDED **)
Task 9: Ruling: inglese delle schermate native (Localizable.xcstrings) NON fatto — rinviato dal task 4; app usata da Lorenzo e Mary in italiano — costo: con iPhone in inglese le schermate native restano in italiano (il sito invece è IT/EN)
Task 9: Verifica: il simulatore è stato preso da un'altra sessione (app "Vocali") durante la prova del tema → smesso di usarlo; ThemeStore coperto da test, login nativo già visto a schermo
Task 9: PENDENTE (Lorenzo): passo 4 — installazione sull'iPhone e checklist §8
Task 9: complete (commits 1a59352..2f0fa71, tests: bash -c 'npm test 2>&1 | grep -E 'Tests '; cd ios && xcodebuild test -project StyleVault.xcodeproj -scheme StyleVault -destination 'id=18361580-2FC8-4A18-AED3-7461008C6569' -derivedDataPath build/dd CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E 'TEST (SUCCEEDED|FAILED)'' → ** TEST SUCCEEDED **)
Final review: reviewer fresco (fable) — 2 Critical, 8 Important, 10 Minor; tutti C/I tenuti dopo rivalutazione per effetto
Final: fixed C1 sync tema che rompe lingua/città senza 003 — profileSync.test 'il tema non trascina lingua e città nel fallimento' RED→GREEN, suite 219/219 (resta condizione: applicare 003 prima del merge)
Final: fixed C2 doppio refresh del token — supabaseClient.test authOptions RED→GREEN; nativo passa al sito solo sessioni non scadute
Final: fixed I1 iniezione sessione (corsa + origine) — nativeBridge.test 'ready', WebBridgeTests ready, WebViewStoreTests isSiteURL RED→GREEN
Final: fixed I2 link _blank muti — WebViewStoreTests opensExternally RED→GREEN
Final: fixed I3 offline all'avvio → login — AuthServiceTests emitLocalSessionAsInitialSession RED→GREEN
Final: fixed I4 primo accesso senza uscita — UI ("Più tardi", "Salta questa", "Chiudi"); nessun test automatico (vista SwiftUI), compila
Final: fixed I5 falso "più persone" — BodyPhotosModelTests oggetto in più + VisionTests peopleCount RED→GREEN
Final: fixed I6 bitmap 48 MP in memoria — VisionTests decodedForAnalysis RED→GREEN (mac), suite mac 8/8
Final: fixed I7 retro non rimosso / file orfani — db.test stalePhotoPaths RED→GREEN
Final: fixed I8 capo sparito senza spalle/fianchi — GarmentLayoutTests sagoma RED→GREEN, suite iOS 32/32
Final: minor (deferred): M1 .weakPassword case dedicato di supabase-swift non riconosciuto
Final: minor (deferred): M2 token iniettati con escape del solo apice invece di JSONEncoder
Final: minor (deferred): M3 cache scontorni senza limite e non svuotata al logout
Final: minor (deferred): M4 lampo del sito tra login e controllo foto
Final: minor (deferred): M5 dopo "Rifai" la WebView tiene la URL firmata vecchia; file nuovo orfano se l'update fallisce
Final: minor (deferred): M6 guida: xcodegen prima di creare Secrets.xcconfig fallisce
Final: minor (deferred): M7 LoginPage web nell'app mostra Google (bloccato nelle WebView)
Final: minor (deferred): M8 il vecchio 'light' diventa Sistema: dirlo a Mary
Final: minor (deferred): M9 OfflineView fuori palette in tema scuro
Final: minor (deferred): M10 errori .other mostrano il testo grezzo in inglese
Device: Modalità sviluppatore attiva, app installata e avviata sull'iPhone di Lorenzo (dopo "Autorizza" in VPN e gestione dispositivi)
Device: added "Password dimenticata?" nel login nativo — reset via email con redirect stylevault://reset-password (PKCE, onOpenURL → NewPasswordView); registrazione con email già usata → passa ad "Accedi"; AuthServiceTests samePassword/tooManyEmails/isRecoveryLink RED→GREEN, suite iOS 35/35 (CODE_SIGNING_ALLOWED=NO). Richiede stylevault://** tra le Redirect URLs di Supabase
Device: fixed avatar sull'iPhone — scarpa singola su ogni piede (shoeFrames, punta/specchio, conteggio soggetti nella cache), larghezze top/pantaloni dalla sagoma (Silhouette), vita pantaloni più alta, gambe divaricate coperte; GarmentLayoutTests/SilhouetteTests RED→GREEN, suite iOS 44/44, Vision Mac 8/8; jeans mancanti non riprodotti sul Mac (outfit senza jeans?)
Device: fixed foto della vista sbagliata accettate in silenzio (seenView/wrongView da spalle e busto) + tetto 35% dell'altezza ai pantaloni; BodyPhotosModelTests/GarmentLayoutTests RED→GREEN, suite iOS 46/46, Vision Mac 8/8; log temporanei del ponte tolti
