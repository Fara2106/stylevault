# Secondo giro: l'avatar 3D senza AI, fatto bene (2026-07-10)

Feedback di Lorenzo: «non è proprio bellissima l'immagine sull'avatar» e
«il logo sarebbe carino vedere dove è posizionato nel capo, e mantenere quella
coerenza».

**Cos'era brutto.** La foto del capo veniva incollata su una superficie curva
appoggiata davanti al corpo: si vedeva il *disegno* della maglietta (collo,
maniche, orli) schiacciato su un torso che ha già la sua forma, e la superficie,
a raggio costante mentre il busto si assottiglia, sporgeva di lato come una
piastra. I pantaloni, incollati su un'unica superficie che abbracciava entrambe
le gambe, si leggevano come una gonna. Era lo stesso errore del bug originale,
in tre dimensioni.

**Cosa c'è ora.** La forma la fa la mesh, il tessuto la foto.

- `01-logo-al-centro.png` e `02-logo-sul-taschino.png` — **la prova della
  coerenza**: due magliette identiche, cambia solo dove sta il logo nella foto.
  Sull'avatar il logo compare nei due punti diversi. Sui jeans la toppa gialla
  compare **una volta sola, sulla gamba giusta**, non duplicata.
- `03-maglietta-a-righe.png` — la piastrella di tessuto porta le righe vere sul
  corpo e sulle maniche, senza inventare nessuna stampa.
- `04-ruotato.png` — nessuna piastra che sporge; la fantasia gira col corpo.
- `05-piatto.png` — modalità piatta, coi pantaloni che ora arrivano alla caviglia.

Zero errori in console.

## Difetti trovati durante la verifica (e corretti)

1. **Il logo finiva nel tessuto** e si ripeteva a pois su tutto il capo: la
   piastrella veniva presa dal baricentro, cioè proprio dove sta la stampa.
2. **Le righe sparivano**: distavano dallo sfondo esattamente quanto la
   tolleranza dello scontorno, e toccando il bordo del capo il riempimento se le
   mangiava dai lati.
3. **La stampa non veniva trovata su nessuna foto vera**: l'anello di pixel
   sfumati fra capo e sfondo (antialiasing) sembrava "stampa" e faceva rinunciare.
4. **Sui jeans la stampa restava introvabile**: i pixel diversi dal tessuto erano
   due macchie staccate — la toppa e una cucitura all'inguine — e il rettangolo
   che le conteneva entrambe era quasi vuoto. Ora si prende la macchia connessa
   più grande.

Nessuno dei quattro era visibile dai test: il primo e il secondo si vedono solo a
schermo, il terzo e il quarto solo su immagini con bordi veri, che i test
sintetici non hanno. Sono stati diagnosticati interrogando le funzioni pure
direttamente, dentro il browser, sulle foto reali.
