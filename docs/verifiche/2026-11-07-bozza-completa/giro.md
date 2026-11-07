# Giro da utente della bozza completa — 2026-11-07

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
è una cosa vecchia, non toccata.

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
