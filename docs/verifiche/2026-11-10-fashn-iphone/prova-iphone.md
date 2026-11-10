# FASHN VTON v1.5 sull'iPhone: prima misura

Data: 2026-11-10. Richiesta di Lorenzo («Sì, misuralo»): capire se FASHN può dare l'avatar preciso che il collage non dà.
App di prova: `tools/avatar-fashn/bench/` (`it.faraoni.stylevault.bench`, Release, permesso di memoria aumentata), installata
sull'iPhone di Lorenzo con il suo ok. Non è Style Vault e non tocca i suoi dati.

## Cosa è stato misurato

iPhone 18 Pro Max (iPhone19,7), modello a 6 bit da 704 MB (`out/coreml-6bit`), GPU (`cpuAndGPU`), 864×576, guida 1,5.
Stessi ingressi della prova sul Mac (`out/inputs.npz`: foto, maglione, pose e rumore catturati dalla pipeline originale).
La generazione è intera: 2 passaggi a passo, 1 all'ultimo, schedule originale riscritta in Swift.

| Passi | Totale | A passo | Primo passo | Picco di memoria |
|---|---|---|---|---|
| 30 | 121,7 s | 3,92 s | 9,75 s | 669 MB |
| 20 | 81,1 s | 3,95 s | 7,79 s | 765 MB |
| 12 | 49,5 s | 3,85 s | 8,45 s | 854 MB |

- Caricamento del modello: 1,6 s. Memoria libera per l'app all'avvio: 6133 MB.
- Sul Mac M1 Pro, con altre sessioni attive, gli stessi 30 passi a 6 bit avevano preso 265,5 s.
- L'immagine a 30 passi è la stessa del Mac a occhio (`iphone-vs-mac.jpg`: a sinistra l'iPhone, con le bande nere del
  formato, a destra il Mac). Nessun NaN.
- Qualità (`dettaglio-30-20-12.jpg`): a 20 passi le trecce del maglione restano, un po' più morbide; a 12 la forma è
  giusta ma la trama sparisce.
- Nei 30 passi il tempo sale da 3,1 a 4,1 s a passo: probabilmente il telefono che si scalda. Non verificato.

## Cosa NON dice questa prova

- Il picco è `phys_footprint`: la memoria della GPU potrebbe non esserci tutta. Non è stato provato senza il permesso
  di memoria aumentata.
- Solo iPhone 18 Pro Max. Il 15 Pro di Mary e l'iPad non sono misurati.
- Una sola coppia, capo steso (`flat-lay`), categoria sopra. Capi indossati, pantaloni e vestiti non provati.
- Neural Engine non provato (con Mobile-VTON il modello grande non si preparava).
- Le pose vengono dal Mac: DWPose non è convertito, quindi la catena intera sul telefono non esiste ancora.
- Batteria e calore su più generazioni di fila.

## Per rifarla

`tools/avatar-fashn/bench/prepara.sh 6bit`, poi progetto generato fuori da Documents e lancio con
`xcrun devicectl device process launch --console … it.faraoni.stylevault.bench -- --units gpu --steps 30 --esci`.
Il risultato sta in `Documents/fashn-result.json` e `.png` dell'app.
