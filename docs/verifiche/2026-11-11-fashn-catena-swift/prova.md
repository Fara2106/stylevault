# FASHN VTON: catena intera in Swift, con la posa di Apple Vision

11/11/2026. Finora la posa (DWPose) e la preparazione delle foto venivano dal Mac, in Python. Ora stanno in
`ios/FashnKit` (pacchetto Swift; fino all'11/11 pomeriggio stava in `tools/avatar-fashn/FashnKit`): riquadro e bordi, disegno della posa,
posa con Apple Vision (corpo, mani, viso), campionamento Core ML con avanzamento.

## Confronto sul Mac (Vision vero), stessa coppia della prova originale

`fashn-confronto <persona> <capo> <uscita> --originali out/bench-payload/inputs` (numeri in `confronto-mac.txt`):

| Ingresso | Differenza media dall'originale (su 255) |
|---|---|
| foto della persona nel riquadro | 0,38 |
| foto del capo nel riquadro | 0,20 |
| posa del capo (capo da solo: tela nera) | 0,00 |
| posa della persona | 1,19 |

- Posa: Vision trova 18 punti su 18, le due mani e il viso. Sovrapposta a quella di DWPose coincide quasi del tutto
  (`pose-dwpose-vision-sovrapposte.jpg`: DWPose, Vision, le due insieme); stesso grigio nel 92% dei pixel in comune, quindi
  destra e sinistra sono quelle giuste.
- Immagine finale: 30 passi, modello a 6 bit, stesso rumore di partenza dell'originale, 271 s sul Mac.
  `originale-sinistra-swift-vision-destra.jpg`: a occhio equivalenti (maglione, maniche, trecce, viso e pantaloncini intatti).
- Test del pacchetto: 15 su 15 (`swift test`).

## App di prova

`tools/avatar-fashn/bench`: di base apre la prova (scegli persona e capo dalle foto, tipo di capo, passi, **barra di
avanzamento con la percentuale accanto**, risultato da salvare). `--misura` riapre il banco dei tempi del 10/11.
La barra conta i passaggi del modello (due a passo, uno all'ultimo). `barra-simulatore.jpg` è la barra sul simulatore,
con avanzamento finto (`--finta`): sul simulatore il modello e Vision non girano.

## Sul telefono (iPhone 18 Pro Max di Lorenzo, 11/11 pomeriggio)

Quattro generazioni di fila a 30 passi, persona `1-davanti`, foto scelte dalla libreria (`iphone-maglione-jeans-maglietta-outfit.jpg`):

| Capo | Impostazioni | Tempo | Picco | Esito |
|---|---|---|---|---|
| maglione da solo | Sopra | 116 s | circa 715 MB | buono, come sul Mac |
| jeans da soli | Sotto | 119 s | 716 MB | buono: jeans lunghi al posto dei pantaloncini, maglietta e scarpe intatte |
| maglietta arancione addosso a una modella | Sopra, foto intera | non letto | non letto | **sbagliato**: braccia e pancia con la pelle chiara della modella |
| polo e pantaloni addosso a una modella | Intero, foto intera | 136 s | 702 MB | buono, con due polsini gialli in più ai polsi |

- Posa di Vision sul telefono: 18 punti su 18 in tutte. Preparazione 0,1-0,2 s. La barra con la percentuale ha funzionato.
- **Il telefono si è scaldato «non poco»** (parole di Lorenzo). Batteria dal 76% al 71% nelle quattro generazioni, in otto minuti.
  Da allora l'app va in pausa tra un passaggio e l'altro se iOS segnala «caldo», e scrive temperatura e batteria a fine generazione.

## Capo indossato: si isola prima

La foto intera porta nel risultato la pelle di chi indossa il capo. L'originale lì ritaglia il capo con un modello a licenza
solo ricerca; qui lo isola lo scontorno di Style Vault (`WornGarment`, tramite `FashnWorn`) e il capo entra come «da solo».
- `capi-indossati-isolati.jpg`: maglietta arancione, polo gialla, pantaloni (resta una mano in alto) e, con «Intero», polo più
  mezza gamba di pantaloni: per un outfit di due capi «Intero» non va, si fanno sopra e sotto uno dopo l'altro.
- `maglietta-foto-intera-sinistra-capo-isolato-destra.jpg`: sul Mac, 20 passi, con il capo isolato braccia e pancia restano
  della persona. La maglietta perde il taglio corto e l'arancione è più acceso.
- Nell'app: riconoscimento automatico del capo indossato, «Usa la foto del capo intera» solo per confronto, «Aggiungi un altro
  capo a questo risultato».

## Secondo giro sul telefono (15:32-15:35, 20 passi)

`iphone-secondo-giro-capo-non-isolato.jpg`. La maglietta arancione è uscita ancora con la pelle della modella: nella riga sotto
il risultato manca «Capo isolato», quindi la scelta «Indossato» non era attiva e la foto è entrata intera. La scelta a mano era
un difetto della schermata: ora l'app guarda da sola se nella foto del capo c'è una persona (stesso controllo di Style Vault) e
in quel caso isola il capo. Sul Mac riconosce giuste le sette foto di prova (quattro capi da soli, tre indossati).
- Il secondo capo sul risultato funziona (jeans aggiunti), ma partiva dall'immagine sbagliata.
- **Tempi peggiorati col telefono già caldo e in carica: 20 passi in 160 e 158 s, cioè 8 s a passo contro 3,9 a freddo.**
  iOS segnava «normale» e «tiepido», quindi la pausa per il caldo non è scattata: il rallentamento arriva prima. I tempi del
  10/11 (81 s a 20 passi) valgono solo a telefono freddo. L'app ora scrive i secondi a passo all'inizio e alla fine.
- Picco di memoria 895 MB alla prima generazione dopo l'avvio (carica il modello), 703 MB alla seconda.

## Terzo giro sul telefono (15:52, 20 passi, riconoscimento automatico)

`iphone-terzo-giro-capo-isolato-e-jeans.jpg`: maglietta arancione isolata, poi jeans aggiunti sul risultato. **Giusto:** braccia
e pelle della persona, maglietta e jeans credibili, scarpe e viso intatti. È il primo outfit di due capi fatto tutto sul telefono.
- Tempo della seconda generazione: 274 s, con 3,5 s a passo all'inizio (come a freddo) e 32,5 s di media sugli ultimi quattro.
  Temperatura «tiepido», telefono in chiamata (da 9 minuti). Causa non accertata: la media non distingue un rallentamento da
  un passo rimasto fermo, per esempio con l'app fuori dal primo piano, dove la GPU non lavora.
- Da allora l'app scrive il passo più veloce, quello di mezzo e il più lento, conta i secondi fuori dal primo piano e lì si
  mette in pausa invece di trascinare il passo.
- Lorenzo conferma che l'app è rimasta sempre aperta davanti: non era il secondo piano. Restano due cause possibili, non
  distinte: la pausa per il caldo aggiunta poco prima (se a metà generazione iOS è salito a «caldo», l'app ha aspettato; la riga
  mostrava solo la temperatura di partenza e di arrivo) oppure iOS che taglia la GPU durante una chiamata a telefono già caldo.
  Ora la riga riporta anche la temperatura massima e i secondi di pausa per il caldo.

## Quarto giro sul telefono (16:16-16:23): i tempi spiegati

`iphone-quarto-giro-12-20-30-passi.jpg`. Maglietta arancione isolata, tre generazioni di fila. Tutte giuste, pelle compresa.

| Passi | Totale | Passo più veloce / di mezzo / più lento | Pausa per il caldo | Fuori dal primo piano | Calcolo al netto |
|---|---|---|---|---|---|
| 12 | 44 s | 3,3 / 3,9 / 4,4 s | nessuna (massimo «tiepido») | no | 44 s |
| 20 | 136 s | 3,1 / 3,7 / 67,1 s | 39 s (massimo «caldo») | 25 s | circa 72 s |
| 30 | 267 s | 3,1 / 3,6 / 88,1 s | 163 s (massimo «caldo») | no | circa 104 s |

- **I 274 s del terzo giro erano la pausa per il caldo**, non iOS: il calcolo resta a 3,1-3,9 s a passo anche a telefono caldo.
  Al netto: 12 passi 44 s, 20 passi circa 72 s, 30 passi circa 104 s, come le misure a freddo del 10/11.
- **Il caldo arriva alla seconda o terza generazione di fila.** La prima, da «tiepido», resta «tiepido». Dalla seconda iOS sale a
  «caldo» e l'app aspetta: 39 s, poi 163 s. Una generazione ogni tanto non lo fa scattare; tante di fila sì.
- Gli 8 s a passo delle 15:32-15:35 (senza pausa, telefono in carica) restano l'unico caso in cui il calcolo stesso era lento.
- **Uscire dall'app non rompe più la generazione**: 25 s fuori dal primo piano, pausa e ripresa, risultato giusto.
- Memoria di picco 786-794 MB con anche lo scontorno del capo.
- La batteria letta dall'app va a scatti del 5% (80 → 80, 80 → 75, 75 → 75): non serve a misurare una generazione. Dalle
  schermate: 78% alle 16:16, 75% alle 16:23, circa 3 punti per 62 passi.
- Qualità su questa maglietta a tinta unita: 12, 20 e 30 passi vanno tutti bene. Su una trama (il maglione a trecce del
  10/11) 12 passi la perdevano: non è una prova che 12 bastino sempre.

## Le immagini che Style Vault dà al modello (11/11, 17:24, sul Mac)

Con la versione realistica dentro Style Vault il modello non riceve le foto com'erano nell'app di prova: la persona è
ritagliata nel suo riquadro 2:3 (`PersonFraming`) e ogni capo passa dallo scontorno dell'app (solo il capo, se è addosso
a qualcuno). `fashn-confronto … --outfit <sotto> --come-app` prepara le stesse immagini e genera con il modello vero.

- Persona di prova, maglione giallo fotografato addosso in strada, jeans fotografati da soli; 20 passi, 310 s sul Mac.
- Risultato giusto: maglione a maniche lunghe con zip e tasca, jeans, viso e pelle della persona di partenza
  (`come-app-outfit-20-passi.jpg`; `come-app-persona-ritagliata.jpg`, `come-app-capo-sopra-isolato.png`).
- Il maglione isolato è piccolo (181×175 pixel, la foto di partenza è piccola): il modello lo regge.
- **Sul simulatore la catena dell'app non si può provare**: Vision lì non calcola la posa del corpo
  («Unable to setup request in VNDetectHumanBodyPoseRequest») e lo scontorno non c'è. Il modello si carica (34 s), poi
  la generazione si ferma alla posa. Per questo la verifica è sul Mac, e il primo giro vero dentro Style Vault sarà sul telefono.

## Non provato

- Sul telefono: foto vere di Lorenzo (finora solo la persona di prova in studio), capi con trama a 12 passi.
- Foto con più persone, di spalle o tagliate; vestiti interi veri; 15 Pro di Mary; iPad.
- Il modello non lavora con l'app in secondo piano: va tenuta aperta.
