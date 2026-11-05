# Giro da utente della fase 2

Data: 2026-11-05. Ramo `feat/app-nativa`. Procedura: `mobile-app-publishing`,
`references/test-and-security-audit.md`, sezione "Giro da utente prima del telefono".

Il primo giro è stato fatto a mano sul simulatore. Gli altri con un test temporaneo che tocca lo schermo
e salva una schermata a ogni passo, cancellato alla fine e mai finito in git. Ogni correzione ha fatto
ricominciare il giro da installazione pulita. I test girano con l'archivio in memoria: per questo in
alto compare "Non riesco ad aprire i dati", che non è un difetto.

## Passate finali, senza difetti nuovi

| Dispositivo | Lingua | Tema | Testo | Schermate |
|---|---|---|---|---|
| iPhone 18 Pro | it | scuro | normale | `giro/f-iphone-it-scuro.jpg` |
| iPhone 18 Pro | en | chiaro | normale | `giro/f-iphone-en-chiaro.jpg` |
| iPhone 18 Pro | it | chiaro | accessibilità grande | `giro/f-iphone-testo-grande.jpg` |
| iPhone 18 Pro | en | scuro | normale | `giro/f-iphone-en-scuro.jpg` |
| iPad Pro 11" verticale | it | chiaro | normale | `giro/f-ipad-verticale.jpg` |
| iPad Pro 11" orizzontale | en | scuro | normale | `giro/f-ipad-orizzontale.jpg` |

Le prime tre iPhone sono precedenti all'ultima correzione, che riguarda solo l'iPad: l'iPhone è stato
ripassato dopo quella correzione nella passata `en scuro`.

## Difetti trovati e corretti

| Difetto | Causa | Prova |
|---|---|---|
| Salva con un campo mancante non dava riscontro | errore fuori schermo | `testSalvaPortaAlPrimoErrore` RED→GREEN |
| Foto grandi: cache fino a 2,7 GB | nessun tetto | `PhotoCacheTests` RED→GREEN |
| L'errore rosso restava dopo aver corretto il campo | il modello non lo toglieva | `testLErroreSparisceQuandoSiCorreggeIlCampo` RED→GREEN |
| Pallini delle foto invisibili su fondo chiaro | pallini bianchi senza fondo | eval visiva |
| Tasti degli stati vuoti illeggibili in tema scuro | `.borderedProminent` scrive in bianco | eval visiva |
| Prezzo, Brand e Taglia sotto la tastiera dopo il primo carattere | fine corsa che non conta la tastiera | `testIlPrezzoRestaSopraLaTastiera` RED→GREEN |
| Cuore invisibile sulle foto chiare | nessun fondo sotto il cuore | eval visiva, contrasto misurato |
| iPad: titolo sotto le tab tornando dal dettaglio | barra nascosta nella fascia delle tab | `testIlTitoloRestaAlSuoPostoTornandoDalDettaglio` RED→GREEN |

## Eval

| Id | Tipo | Passi | Esito atteso | Evidenza |
|---|---|---|---|---|
| V1 | Visiva | Stati vuoti in chiaro e scuro | Testo e tasto leggibili | schermate 01-02 |
| V2 | Visiva | Nome lunghissimo nel modulo, griglia, dettaglio | Tagliato nel campo e in griglia, intero nel dettaglio | schermate 05, griglia, dettaglio |
| V3 | Visiva | Cuore e pallini su foto chiara | Visibili nei due temi | griglia e dettaglio |
| V4 | Visiva | Testo accessibilità grande | Niente sovrapposizioni, testi non tagliati | `f-iphone-testo-grande.jpg` |
| V5 | Visiva | Contrasto di ogni coppia testo e sfondo | Almeno 4,5:1 | calcolato sui colori di `Palette`; una coppia a 4,20:1, vedi sotto |
| N1 | Numerica | Aggiungi un capo | Il contatore dice "1 capo", con il singolare | griglia |
| N2 | Numerica | Aggiungi un desiderio | Il segmento dice "Wishlist 1", poi torna "Wishlist" | wishlist piena e vuota |
| N3 | Numerica | Prezzo 12,50 e 12.50 | Il dettaglio mostra 12,50 € | dettaglio fondo |
| L1 | Logica | Salva a vuoto | Errori su nome e categoria, porta al primo | schermata 04 |
| L2 | Logica | Prezzo con lettere | "Scrivi il prezzo in numeri", niente salvataggio | passata intermedia |
| L3 | Logica | Comprato su un desiderio | Passa al guardaroba e sparisce dalla wishlist | schermate comprato |
| L4 | Logica | Elimina categoria in uso | "Prima sposta i capi in un'altra categoria", resta | schermate categoria |
| I1 | Interazione | Aggiunta completa con foto e retro | Capo salvato, retro sfogliabile con etichetta | griglia, dettaglio retro |
| I2 | Interazione | Preferito, filtro, ricerca senza esito | Cuore pieno, filtro corretto, "Nessun risultato" | schermate finali |
| I3 | Interazione | Tastiera su Brand e Prezzo | Campo sempre visibile, si chiude trascinando | schermate brand e prezzo |
| I4 | Interazione | Ritorno dal dettaglio su iPad | Il titolo non si muove | test automatico |
| I5 | Interazione | Fotocamera nel simulatore | Si apre, annullare torna al modulo intatto | primo giro |
| I6 | Interazione | Link H&M reale | Avviso, il link resta | primo giro |
| I7 | Interazione | Chiusura e riapertura | Dati conservati | primo giro |

## Non provato dal simulatore

- Vision dentro l'app, scatto vero, foto su iCloud.
- Lettura riuscita di un link di negozio.
- Sincronizzazione fra dispositivi e funzionamento senza rete.
- Build Release su dispositivo reale.
- Blocco con Face ID in tema scuro.

## Test automatici finali

- `StyleVaultCore`: 27 test verdi.
- `StyleVaultNative` su iPhone 18 Pro: 140 verdi (120 unitari e 20 UI).
- `StyleVaultNative` su iPad Pro 11": 140 verdi.

Due test sono stati intermittenti col Mac saturo. `testNuovaCategoria` falliva per un difetto del test,
trovato e corretto: `Salva` stava oltre il bordo dello schermo ma risultava toccabile; dopo la correzione
8 su 8. `testBloccoConAutenticatoreFinto` è fallito 3 volte su iPad, poi 20 su 20 a carico basso: causa
non provata, test lasciato com'era.
