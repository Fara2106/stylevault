# Testi legali di StyleVault

Copia dei testi delle pagine pubbliche del sito: privacy, supporto ed eliminazione dell'account. Vengono da `src/pages/LegalPage/legalContent.js` (tag `archivio-ibrida-e-sito`), senza modifiche. Ultimo aggiornamento dei testi: 2026-11-04. Contatto pubblico: lorefara97@gmail.com, ancora da confermare con Lorenzo.

**Da riscrivere prima dell'App Store.** I testi descrivono l'app ibrida e il sito, non la nativa. Vanno allineati a `ios/StyleVaultNative/Resources/PrivacyInfo.xcprivacy` e alle Privacy Labels. Da controllare almeno: guardaroba e foto su iCloud invece che su Supabase; niente modelli scaricati da jsDelivr, Google e GitHub; niente microlink.io e Resend se la nativa non li usa; niente avatar realistico e Mobile-VTON; niente crediti @imgly, MediaPipe e ONNX Runtime; la cancellazione dei dati su iCloud oltre a quella dell'account; il percorso del Profilo dove si elimina l'account.

**Sede.** `AppConfig.privacyURL` e `AppConfig.supportURL` puntano ancora al sito (`fara2106.github.io/stylevault/privacy` e `/supporto`). Prima dell'App Store serve una nuova sede: vedi il design, `docs/superpowers/specs/2026-11-04-app-nativa-icloud-design.md`.

## Italiano

### Informativa sulla privacy

StyleVault è un guardaroba digitale: fotografi i tuoi capi, crei outfit e li provi su di te. Qui trovi quali dati usa, perché, dove finiscono e come cancellarli.

#### Chi è il titolare

Lorenzo Faraoni, persona fisica con sede in Italia, che sviluppa StyleVault. Per qualsiasi domanda sulla privacy scrivi a lorefara97@gmail.com.

#### Quali dati usiamo

Account: email, nome e password (la password è conservata solo in forma cifrata dal servizio di login).

Guardaroba: foto dei capi (fronte e retro), nome, categoria, colori, prezzo e link del negozio se li inserisci; outfit salvati e calendario.

Profilo: le foto del corpo (davanti, di lato, di spalle) e il risultato dell’Armocromia, la città predefinita, la lingua e il tema.

Posizione: solo quando scegli “La mia posizione” per il meteo. Le coordinate servono per la previsione e non vengono salvate nel tuo account.

Segnalazioni: se usi “Segnala un problema o un’idea”, il testo che scrivi e alcune informazioni tecniche (app o sito, modello del dispositivo) arrivano via email allo sviluppatore.

#### Perché li usiamo

Per darti il servizio che chiedi: salvare il guardaroba, proporti outfit adatti al meteo e al tuo stile, mostrarti i capi su di te (base giuridica: esecuzione del contratto, art. 6.1.b GDPR).

Per rispondere alle segnalazioni e migliorare l’app (base giuridica: la tua richiesta e il nostro legittimo interesse, art. 6.1.f).

Non c’è pubblicità, non c’è tracciamento tra app o siti, non usiamo strumenti di analisi e non vendiamo dati a nessuno.

#### Le analisi avvengono sul tuo dispositivo

Lo scontorno dei capi, l’analisi del corpo, l’Armocromia (analisi dei colori del viso) e la versione realistica dell’avatar girano sul tuo telefono o nel tuo browser. Le tue foto non vengono inviate a servizi di intelligenza artificiale.

I modelli che fanno queste analisi si scaricano la prima volta da jsDelivr, Google (MediaPipe) e GitHub: queste richieste non contengono le tue foto ma, come ogni richiesta su internet, rivelano l’indirizzo IP del dispositivo.

Le foto del corpo servono solo a mostrarti i vestiti addosso e a stimare forma e proporzioni: non le usiamo per riconoscerti.

#### A chi affidiamo i dati

Supabase: database, archivio delle foto e login, con server nell’Unione Europea (Irlanda).

GitHub (Pages e Releases): ospita il sito e i modelli dell’avatar; riceve l’indirizzo IP quando li apri o li scarichi.

Open-Meteo: previsioni del meteo e ricerca delle città; riceve le coordinate o il nome della città.

Apple: nell’app iPhone, i servizi di sistema di iOS (per esempio il Meteo di Apple, quando attivo).

microlink.io: quando incolli il link di un negozio, legge titolo e immagine della pagina; riceve solo il link.

Resend: invia per email le segnalazioni.

I fornitori con sede negli Stati Uniti (GitHub, Resend, microlink.io) trattano i dati con le garanzie previste dal GDPR per i trasferimenti fuori dall’UE.

#### Dati salvati sul dispositivo

Il sito e l’app salvano sul dispositivo solo ciò che serve a funzionare: la sessione di accesso, le preferenze, una copia dei tuoi dati per aprirsi più in fretta e i modelli scaricati. Non ci sono cookie di profilazione.

#### Per quanto tempo

Finché hai l’account. Se lo elimini, cancelliamo subito account, guardaroba, outfit, calendario, foto e Armocromia; le eventuali copie di sicurezza del fornitore si sovrascrivono entro pochi giorni.

Le email delle segnalazioni restano nella casella dello sviluppatore per il tempo necessario a gestirle.

#### I tuoi diritti

Puoi chiedere accesso, correzione, cancellazione, portabilità dei dati, limitazione od opposizione al trattamento scrivendo a lorefara97@gmail.com. Puoi anche presentare reclamo al Garante per la protezione dei dati personali (garanteprivacy.it).

Puoi eliminare l’account in qualsiasi momento da Profilo → Elimina account.

#### Minori

StyleVault non è pensato per chi ha meno di 14 anni.

#### Modifiche

Se questa informativa cambia in modo importante te lo diremo nell’app. Qui sotto trovi la data dell’ultimo aggiornamento.

### Supporto

Hai un problema o un’idea? Siamo qui.

#### Come contattarci

Dall’app o dal sito: Profilo → “Segnala un problema o un’idea”.

Per email: lorefara97@gmail.com. Rispondiamo di solito entro pochi giorni.

#### Ho dimenticato la password

Nell’app, nella schermata di accesso, tocca “Password dimenticata?”: ti arriva un’email con il link per sceglierne una nuova. Se sei già dentro, la cambi da Profilo → Cambia password.

#### Voglio rifare le foto del corpo

Profilo → Le tue foto: tocca la foto da cambiare.

#### La versione realistica dell’avatar occupa spazio

I modelli occupano circa 1,3 GB e si scaricano solo quando lo confermi. Puoi eliminarli quando vuoi dai Crediti dell’avatar.

#### Eliminare l’account

Profilo → Elimina account. Trovi tutti i dettagli nella pagina dedicata.

#### Crediti e licenze

Scontorno delle foto: @imgly/background-removal (licenza AGPL-3.0). Il codice sorgente completo di StyleVault è pubblico: github.com/Fara2106/stylevault.

Analisi del corpo e del viso: MediaPipe di Google (Apache 2.0). Calcoli nel browser: ONNX Runtime (MIT).

Versione realistica dell’avatar (app iPhone): Mobile-VTON (CC BY-NC-SA 4.0), Powered by Stability AI (Stability AI Community License), CLIP/OpenCLIP (MIT), DINOv2 (Apache 2.0). Dettagli nei Crediti dell’avatar.

Dati meteo: Open-Meteo.com (CC BY 4.0).

### Eliminare l’account

Puoi eliminare il tuo account StyleVault e tutti i dati collegati, in qualsiasi momento.

#### Dall’app o dal sito

Accedi, apri Profilo e tocca “Elimina account” in fondo alla pagina, poi conferma.

L’eliminazione è immediata e definitiva: account, guardaroba, outfit, calendario, foto del corpo e dei capi, Armocromia.

#### Se non riesci ad accedere

Scrivi a lorefara97@gmail.com dall’indirizzo con cui ti sei registrato: eliminiamo l’account entro 30 giorni e te lo confermiamo.

#### Cosa resta

Nulla nel servizio. Le eventuali copie di sicurezza del fornitore si sovrascrivono entro pochi giorni; le email di segnalazioni che ci hai mandato possono restare nella nostra casella, e puoi chiederci di cancellarle.

## English

### Privacy policy

StyleVault is a digital wardrobe: you photograph your clothes, build outfits and try them on yourself. Here is what data it uses, why, where it goes and how to delete it.

#### Who is responsible

Lorenzo Faraoni, an individual based in Italy who develops StyleVault. For any privacy question write to lorefara97@gmail.com.

#### What data we use

Account: email, name and password (the password is only stored encrypted by the sign-in service).

Wardrobe: photos of your clothes (front and back), name, category, colours, price and shop link if you add them; saved outfits and calendar.

Profile: body photos (front, side, back) and your colour analysis result, default city, language and theme.

Location: only when you choose “My location” for the weather. The coordinates are used for the forecast and are not saved to your account.

Reports: if you use “Report a problem or an idea”, the text you write and some technical details (app or website, device model) reach the developer by email.

#### Why we use it

To provide the service you ask for: saving your wardrobe, suggesting outfits for the weather and your style, showing clothes on you (legal basis: performance of a contract, Art. 6(1)(b) GDPR).

To answer reports and improve the app (legal basis: your request and our legitimate interest, Art. 6(1)(f)).

There are no ads, no tracking across apps or websites, no analytics tools, and we never sell data.

#### Analysis happens on your device

Garment cut-out, body analysis, colour analysis of your face and the realistic avatar run on your phone or in your browser. Your photos are not sent to artificial intelligence services.

The models behind these features are downloaded the first time from jsDelivr, Google (MediaPipe) and GitHub: these requests contain no photos but, like any internet request, reveal your device’s IP address.

Body photos are only used to show clothes on you and estimate shape and proportions: we do not use them to recognise you.

#### Who processes data for us

Supabase: database, photo storage and sign-in, with servers in the European Union (Ireland).

GitHub (Pages and Releases): hosts the website and the avatar models; receives your IP address when you open or download them.

Open-Meteo: weather forecasts and city search; receives coordinates or the city name.

Apple: in the iPhone app, iOS system services (for example Apple Weather, when enabled).

microlink.io: when you paste a shop link, it reads the page title and image; it only receives the link.

Resend: sends reports by email.

Providers based in the United States (GitHub, Resend, microlink.io) process data with the safeguards the GDPR requires for transfers outside the EU.

#### Data stored on your device

The website and the app only store what they need to work: your sign-in session, preferences, a copy of your data so they open faster, and downloaded models. There are no profiling cookies.

#### How long we keep it

For as long as you have an account. If you delete it, we immediately delete your account, wardrobe, outfits, calendar, photos and colour analysis; any provider backups are overwritten within a few days.

Report emails stay in the developer’s mailbox for as long as needed to handle them.

#### Your rights

You can ask for access, correction, deletion, portability, restriction or objection by writing to lorefara97@gmail.com. You can also lodge a complaint with your data protection authority (in Italy, garanteprivacy.it).

You can delete your account at any time from Profile → Delete account.

#### Children

StyleVault is not meant for anyone under 14.

#### Changes

If this policy changes in an important way we will tell you in the app. The date of the last update is below.

### Support

A problem or an idea? We are here.

#### How to reach us

In the app or on the website: Profile → “Report a problem or an idea”.

By email: lorefara97@gmail.com. We usually reply within a few days.

#### I forgot my password

In the app, on the sign-in screen, tap “Forgot password?”: you will get an email with a link to choose a new one. If you are signed in, change it from Profile → Change password.

#### I want to retake my body photos

Profile → Your photos: tap the photo to change.

#### The realistic avatar takes up space

Its models take about 1.3 GB and are only downloaded after you confirm. You can delete them at any time from the avatar’s Credits.

#### Deleting your account

Profile → Delete account. All details are on the dedicated page.

#### Credits and licences

Photo cut-out: @imgly/background-removal (AGPL-3.0 licence). StyleVault’s complete source code is public: github.com/Fara2106/stylevault.

Body and face analysis: Google MediaPipe (Apache 2.0). In-browser computation: ONNX Runtime (MIT).

Realistic avatar (iPhone app): Mobile-VTON (CC BY-NC-SA 4.0), Powered by Stability AI (Stability AI Community License), CLIP/OpenCLIP (MIT), DINOv2 (Apache 2.0). Details in the avatar’s Credits.

Weather data: Open-Meteo.com (CC BY 4.0).

### Delete your account

You can delete your StyleVault account and all related data at any time.

#### From the app or the website

Sign in, open Profile and tap “Delete account” at the bottom of the page, then confirm.

Deletion is immediate and permanent: account, wardrobe, outfits, calendar, body and clothing photos, colour analysis.

#### If you cannot sign in

Write to lorefara97@gmail.com from the address you signed up with: we delete the account within 30 days and confirm it to you.

#### What remains

Nothing in the service. Any provider backups are overwritten within a few days; report emails you sent us may remain in our mailbox, and you can ask us to delete them.
