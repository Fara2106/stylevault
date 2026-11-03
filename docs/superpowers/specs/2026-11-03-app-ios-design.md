# App iOS StyleVault: Design

**Data:** 2026-11-03
**Stato:** bozza, da approvare da parte di Lorenzo
**Base:** `main` a `26feb27` (sito live su GitHub Pages, Supabase `frukvktbmxndyzgivwxq`
riattivato, "Su di te" ripristinata con GPU)

## 1. Perché

Lorenzo e Mary vogliono **vedersi addosso** i capi scelti per capire se l'outfit
"matcha", come in un camerino: il proprio corpo vero (non un manichino), con i
capi scontornati addosso, e poterlo **girare** per vedere come stanno anche di
lato e da dietro.

Il sito lo fa solo in parte: "Su di te" mostra il davanti, deve scaricare circa
25 MB di modelli al primo uso, è lento e lo scontorno è discreto. Un'app iOS
vera può usare lo **scontorno e il riconoscimento della posa integrati in iOS**
(framework Vision: lo stesso "stacca il soggetto" delle Foto), che sono già sul
telefono: nessun download, quasi istantanei, più puliti.

Parole di Lorenzo: «il telefono scontorna automaticamente la foto della persona,
e tutti i capi, anch'essi scontornati, vanno sull'avatar della persona, così per
vedere se matcha»; «si vede il suo corpo con i vestiti addosso, dove può anche
girarsi per vedere come le stanno».

## 2. Obiettivi

1. **App iOS** (SwiftUI) che contiene l'app web esistente: guardaroba, outfit,
   calendario, armocromia e account restano quelli del sito, con lo stesso
   account Supabase.
2. **Avatar nativo in 3 viste**: davanti, lato e spalle. La persona e i capi sono
   scontornati con Vision; i capi sono posizionati sul corpo con la posa rilevata
   da Vision. "Girarsi" significa **scorrere col dito tra le 3 viste**.
3. **Primo accesso guidato**: dopo il login l'app chiede 3 foto a figura intera
   (davanti, lato, spalle) con indicazioni su come farle. Le foto si salvano
   **nell'account** e si possono rifare quando si vuole.
4. **Accesso**: email e password (come oggi), **Accedi con Google** (subito),
   **Accedi con Apple** (progettato ora, attivato con l'account sviluppatore a
   pagamento, v. §5).
5. **Tema**: selettore a tre posizioni **Chiaro · Scuro · Sistema** nelle
   impostazioni, valido per app e sito; "Sistema" segue il telefono.
6. **Prova prima sull'iPhone di Lorenzo**, poi si decide come darla a Mary.

## 3. Non obiettivi (per ora)

- **Foto realistica generativa** (CatVTON, Core ML): possibile estensione futura,
  dopo una prova del modello sul Mac. In questa versione l'avatar è un
  **montaggio pulito**, non una foto generata.
- **Rotazione libera a 360°** o avatar 3D: senza scansione 3D e capi in 3D non è
  affidabile. Le 3 viste sono la risposta.
- **Pubblicazione su App Store o TestFlight**, e iscrizione all'Apple Developer
  Program: rimandate da Lorenzo («intanto proviamolo in locale»).
- **Riscrivere in Swift tutto il sito**: si riusa l'app web.
- **Cambiare "Su di te" del sito**: resta com'è (vista frontale, collage). Le 3
  viste sono una cosa dell'app.

## 4. Cosa sarebbe un fallimento anche se "funziona"

- Un **manichino stilizzato** al posto della persona vera: a luglio l'avatar
  stilizzato è stato scartato proprio per questo.
- Attese lunghe o download pesanti all'apertura dell'avatar: il punto dell'app è
  la velocità.
- Le **foto del corpo** visibili ad altri o fuori dallo spazio privato
  dell'account.
- Rompere il sito che Mary usa oggi: l'app si aggiunge, non sostituisce.

## 5. Vincoli

- **Firma gratuita**: con l'Apple ID gratuito di Lorenzo l'app si installa via
  cavo o Wi-Fi da Xcode e **scade dopo 7 giorni** (va reinstallata). Sul Mac non
  c'è ancora nessun certificato: Lorenzo deve entrare in Xcode con il suo Apple
  ID (passaggio suo).
- **Accedi con Apple richiede l'account a pagamento** (capability non
  disponibile con il team gratuito, servono anche Services ID e chiave per
  Supabase). Fino ad allora il bottone non compare (o compare disattivato con
  spiegazione: decide il costruttore).
- **Accedi con Google**: Google **blocca il login dentro una WebView**. Serve il
  login di sistema (`ASWebAuthenticationSession`) o l'SDK Google con
  `signInWithIdToken` di Supabase. Servono un client OAuth su Google Cloud
  Console e il provider Google attivo su Supabase: **li crea Lorenzo** (gratis,
  circa 15 minuti), guidato passo per passo.
- **Supabase** è il backend unico, con la chiave pubblica `sb_publishable_…` e i
  bucket privati con policy per utente (`profile-photos`, `wardrobe-photos`).
  Ogni modifica allo schema va in una nuova migrazione (`003_…`).
- **Ambiente**: Xcode 27.2, simulatore iOS 27 (iPhone 18 Pro), Mac M1 Pro
  16 GB. Il simulatore è **condiviso con un'altra app di Lorenzo** (Fitness Hub):
  non toccare i suoi pannelli e usare sempre il device esplicito.
- **Lingue**: italiano e inglese, come il sito.
- **Costi**: zero.

## 6. Decisioni di Lorenzo

| Aspetto | Decisione |
|---|---|
| Scopo | Vedersi addosso i capi per giudicare l'abbinamento, anche girandosi |
| Chi lo usa | Mary e Lorenzo, ognuno col proprio corpo |
| Input del corpo | 3 foto (davanti, lato, spalle) al primo accesso, poi in memoria per account |
| Login | Email, Google e Apple (Apple quando ci sarà l'account a pagamento) |
| Tema | Chiaro · Scuro · Sistema |
| Distribuzione | Prima in locale sul suo iPhone, account a pagamento rimandato |

## 7. Scelte del costruttore (proposte da Claude, non decise da Lorenzo)

- **Architettura ibrida**: app SwiftUI con una `WKWebView` che carica il sito,
  più schermate native per primo accesso, login e avatar. Comunicazione tra web
  e nativo tramite un ponte JavaScript (`WKScriptMessageHandler`). Esempio: dalla
  pagina Prova, "Su di te" nell'app apre l'avatar nativo con l'outfit scelto.
  Se la WebView carichi il sito pubblicato o una copia inclusa nell'app lo decide
  il costruttore; la copia inclusa evita problemi di rete e di versione.
- **Sessione condivisa**: il login avviene in nativo (Supabase Swift) e la
  sessione viene passata alla WebView, così non si fa login due volte.
- **Foto del corpo nel cloud**: nel bucket privato `profile-photos`, percorsi
  `<uid>/body-front|side|back.*`, con una colonna `body_photos jsonb` su
  `profiles`. Si salvano le foto originali; lo scontorno si rifà sul telefono,
  ed è istantaneo.
- **Retro e lato dei capi**: ogni capo può avere una foto del **retro**
  facoltativa (nuovo campo, aggiungibile da foto o dalle altre immagini dello
  shop). Senza retro, la vista di spalle usa il davanti; nella vista di lato il
  capo si adatta alla sagoma laterale. Da migliorare dopo la prova se si nota.
- **Tema sul sito**: la colonna/impostazione `theme` esiste già in
  `SettingsContext` (oggi sempre `light`). Va disegnata una palette scura per i
  token in `styles/tokens.css`; "Sistema" segue `prefers-color-scheme`
  (nell'app, l'aspetto dell'iPhone).
- **Una sola foto "davanti"**: la foto frontale del corpo **è** l'attuale foto
  di riferimento del profilo (`reference_photo_path`), che continua a servire a
  Prompt AI, armocromia e "Su di te" del sito. Lato e spalle si aggiungono.
- **Account esistenti**: chi ha già la foto di riferimento, al primo accesso
  nell'app vede la sua foto come "davanti" (può rifarla) e scatta solo lato e
  spalle.
- **Ingresso all'avatar**: dalla pagina Prova (scheda "Su di te", che nell'app
  apre la vista nativa) e da un bottone "Vedilo addosso" sugli outfit proposti.
  Le 3 foto si rifanno dal Profilo.
- **Foto del retro di un capo**: campo facoltativo nella pagina Aggiungi/Modifica
  capo del sito (quindi anche nell'app), da foto o fotocamera; per i capi da link
  si può scegliere un'altra immagine dello shop se disponibile.
- **Posizionamento dei capi**: si riusa la logica già tarata del sito
  (`modelComposer`, `modelWarp`, `personSilhouette`) dove ha senso,
  riscrivendola in Swift o richiamandola via WebView. Decide il costruttore.

## 8. Come capiamo che funziona

Sul suo iPhone Lorenzo:

1. installa l'app da Xcode ed entra con email o con Google;
2. al primo accesso fa le 3 foto guidate;
3. sceglie un outfit di 2–4 capi e apre l'avatar: vede sé stesso scontornato con
   i capi addosso **in meno di 2 secondi**, e scorrendo vede lato e spalle;
4. riapre l'app: le foto ci sono ancora, senza rifarle;
5. cambia il tema tra Chiaro, Scuro e Sistema e tutte le schermate seguono;
6. il sito continua a funzionare per Mary come prima.

## 9. Aperto per dopo

- Iscrizione all'Apple Developer Program, Accedi con Apple, TestFlight per Mary.
- Prova realistica on-device (CatVTON → Core ML): prima una prova sul Mac per
  giudicare realismo e tempi.
- Modello di iPhone di Mary e di Lorenzo (conta per l'eventuale modello
  generativo, non per questa versione).
