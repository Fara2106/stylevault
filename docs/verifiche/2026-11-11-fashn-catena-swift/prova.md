# FASHN VTON: catena intera in Swift, con la posa di Apple Vision

11/11/2026. Finora la posa (DWPose) e la preparazione delle foto venivano dal Mac, in Python. Ora stanno in
`tools/avatar-fashn/FashnKit` (pacchetto Swift, fuori dal progetto di Style Vault): riquadro e bordi, disegno della posa,
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

## Non provato

- Sul telefono: la catena intera con foto vere (posa di Vision sull'iPhone, tempi, memoria).
- Capi sotto e interi, capo indossato da qualcuno nella foto (l'originale lì ritaglia il capo con un modello a licenza
  solo ricerca, che qui non c'è: la foto entra intera con la sua posa), foto con più persone, di spalle o tagliate.
- Il modello non lavora con l'app in secondo piano: va tenuta aperta.
