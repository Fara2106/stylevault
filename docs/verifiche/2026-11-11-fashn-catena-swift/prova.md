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
- Nell'app: «Da solo / Indossato / Indossato, intera» e «Aggiungi un altro capo a questo risultato».

## Non provato

- Sul telefono: il capo isolato, due capi uno dopo l'altro, la pausa per il caldo, 20 passi con foto vere di Lorenzo.
- Foto con più persone, di spalle o tagliate; vestiti interi veri; 15 Pro di Mary; iPad.
- Il modello non lavora con l'app in secondo piano: va tenuta aperta.
