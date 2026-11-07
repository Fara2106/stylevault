# Giro da utente della bozza completa — 2026-11-07

## RC 1.0 (6)

Build 1.0 (6), commit `99048c5`, ramo `feat/app-nativa`, iOS 27.2 simulato. Ogni giro parte da installazione nuova: i 26 passi
di sotto più Privacy, Supporto, Eliminare l'account, ognuna fino in fondo, e il capo cancellato nel calendario. Sono 33 schermate.

| Prova | Dove | Esito |
|-------|------|-------|
| Suite completa | iPhone 18 Pro | 272 su 272 |
| Suite completa | iPad Pro 11" | 272 su 272 |
| Giro r1, italiano chiaro | iPhone 18 Pro | passato, 33 schermate viste |
| Giro r1d, italiano scuro | iPhone 18 Pro | passato, 33 schermate viste |
| Giro r1e, inglese chiaro | iPhone 18 Pro | passato al secondo tentativo, 33 schermate viste |
| Giro duo, italiano chiaro | iPhone Duo, schermo interno | passato al terzo tentativo, 33 schermate viste |

Core non è stato rilanciato: 187 verdi prima di questo round, e il commit `99048c5` non lo tocca. Nessun crash dell'app durante
il round: l'ultimo report dell'app è delle 09:29, precedente.

Un difetto dell'app, corretto, con il giro ripartito da zero: nel primo round i moduli di sistema davano titoli e note a 3,35:1 e
segnaposto a 1,72:1 in chiaro, 2,48:1 in scuro. Ora usano il testo secondario della palette.

I tentativi falliti non vengono dall'app. Inglese: al secondo capo il campo nome non ha preso il fuoco, con il Mac a carico sopra
300; il test ora riprova il tocco. Duo, primo tentativo: il programma di test è andato in crash prima di aprire l'app
(`handleStalledWait`, a carico alto). Duo, secondo tentativo: non compilava per una copia `TempGiroTests 2.swift` comparsa da sola.
Il fuoco perso non è dimostrato estraneo all'app: il modulo non resetta il campo e non è cambiato, ma il motivo non è provato.

Contrasti misurati dai pixel degli screenshot, in italiano:

| Testo | Chiaro | Scuro |
|-------|--------|-------|
| Link Privacy e Supporto, nota dei primi passi, date delle pagine legali | 5,38:1 | 6,81:1 |
| Titoli e note delle sezioni nel Profilo e in Segnala, contatore | 5,38:1 | 6,81:1 |
| Segnaposto di Segnala | 5,74:1 | 6,20:1 |
| Capo cancellato nel calendario | 5,74:1 | 6,31:1 |

Nessun pixel del grigio di sistema #888789 in r1, r1d, r1e. In inglese i colori sono gli stessi, ma i numeri non sono stati misurati
perché le zone di misura sono tarate sull'italiano. Il Duo non è stato misurato: stessi colori, schermate solo viste.

Sotto soglia e non corretti: chevron dei NavigationLink e interruttore spento di "Blocca l'app" (#C5C5C7, di sistema); l'accento
chiaro sulla scheda selezionata resta a 4,2:1, vecchio. Non controllati: alert "Nuova categoria" e ricerca della città, lasciati di
sistema. Da guardare sul telefono: nelle pagine legali, scorrendo, il testo passa sotto il tasto Indietro senza sfocatura;
con il cappotto nell'outfit il consiglio dice comunque "Troppo leggero per 12°", logica già presente prima.

Sul Duo la barra è verticale a destra e il contenuto regge. Nel calendario il capo cancellato è sotto il bordo dello schermo e lì non
è stato visto.

Finti come sotto. Non provati: "Aumenta contrasto", testo grande, VoiceOver, schermo esterno e passaggio aperto e chiuso del Duo,
giro a mano su iPad. Le schermate sono in `.superpowers/sdd/rc/giro`, fuori da git.

## Build 1.0 (5)

Build 1.0 (5), commit `e5003bb`, ramo `feat/app-nativa`. iPhone 18 Pro simulato, iOS 27.2.

## Com'è andato

Ogni giro parte da installazione nuova e archivio vero: login, primi passi, 5 capi, riapertura, dettaglio,
Vedilo addosso, Prompt AI col consenso, Outfit, Indossa, Calendario, Profilo, Armocromia, Statistiche, Esporta,
Segnalazione, °F. Sono 26 schermate per giro.

| Giro | Lingua e tema | Esito |
|------|---------------|-------|
| c1 | italiano, chiaro | passato, trovato un difetto: spazio prima dei due punti nell'Armocromia |
| c2 | italiano, chiaro | pulito, dopo la correzione |
| c2d | italiano, scuro | pulito |
| c2e | inglese, chiaro | pulito |

Prima del giro pulito il giro è ripartito una volta perché il test non chiudeva la tastiera: difetto del test, non dell'app.

Suite: Core 180 verdi. Suite completa iPhone 241 su 243 e iPad 242 su 243. I rossi erano difetti dei test
(scelta dei primi passi rimasta salvata sul simulatore, statistiche fuori schermo o sul bordo). Corretti e rilanciati
quei soli test su iPhone e iPad: verdi. Le suite complete non sono state rifatte dopo: l'unico cambio di codice
successivo è il testo dell'Armocromia, coperto dai giri. Nessun crash nuovo il 7 novembre.

Contrasti misurati sui colori della palette, sfondo e superficie: nelle schermate nuove il minimo è 5,38:1 in chiaro
(testo secondario) e 6,31:1 in scuro. L'accento chiaro sulla scheda selezionata resta a 4,2:1, con etichetta piccola:
è una cosa vecchia, non toccata. Correzione: quel minimo veniva dalla palette, non dai pixel, e non valeva per i moduli di sistema.
Vedi sopra, RC 1.0 (6).

Screenshot: `it-chiaro-*.png`, `it-scuro-*.png`, `en-chiaro-*.png` in questa cartella.

## Finti nel giro

Il simulatore non ha Vision, fotocamera, posizione vera e iCloud. Nel giro erano finti: analisi del corpo e del viso,
foto del corpo (un rettangolo), meteo, posizione, invio della segnalazione. Il banner "Sincronizzazione non attiva" è
quello giusto per un simulatore senza iCloud.

## Non provato

Solo su telefono vero si può vedere: Vision con foto vere, composizione con capi veri, fotocamera, posizione concessa,
registrazione e reset password, Esci con un account vero, invio reale della segnalazione (nessuna email inviata), cambio
password, importazione dal selettore file (provata solo negli unit test), iCloud tra dispositivi, Release su dispositivo.
Lo script Supabase non è mai stato lanciato contro il servizio vero. iPad solo con la suite, nessun giro a mano;
iPhone piccoli, testo grande, VoiceOver e iPhone Duo non provati su queste schermate.

## Dopo la revisione esterna

Il revisore ha lavorato su `26feb27..71245db`. Corretti: crash della scheda Outfit con due capi dallo stesso id, crash con un
viso tagliato dal bordo della foto, meteo vecchio che spostava il giorno e il registro di "Indossa", scontorni in memoria senza
limite, esporta e importa a blocchi, testo di "Elimina account", manifest privacy.

Provato sul codice corretto: Core 182 verdi, iPhone 248 su 249 (il rosso era il test della privacy da aggiornare, ora verde),
giro c3 in italiano chiaro passato. iPad 245 su 250: un rosso era lo stesso test della privacy e quattro erano crash di
SpringBoard con il Mac a carico 900. Rilanciati, verdi; nel rilancio un altro test è caduto su un'attesa di 5 secondi ed è
passato da solo. Il tema scuro e l'inglese non sono stati rifatti dopo queste correzioni.

Non dimostrato: il minor consumo di memoria di esporta e importa non è stato misurato, e la nuova schermata di meteo a mano
con previsione vecchia non è stata vista a schermo, solo nei test del modello. Il testo di "Elimina account" non compare nel giro,
che non usa un account.

Aperto: i doppioni restano possibili se lo stesso file si importa su due dispositivi. Non chiudono più l'app, ma vanno tolti con un
campo nuovo prima di portare lo schema iCloud in Production.
