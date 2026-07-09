# Avatar 3D e capi 3D — Design

**Data:** 2026-07-09
**Stato:** approvato da Lorenzo (brainstorming completato)
**Sostituisce:** la riga "Avatar" e la riga "Try-on" della tabella decisioni in
`2026-07-07-stylevault-design.md` (figura 2D SVG, try-on a collage).

## 1. Perché

Due segnalazioni di Lorenzo, con la stessa radice.

**"L'avatar non è 3D ma è piatto."** Corretto: non è mai stato 3D. La spec del
2026-07-07 prescriveva una figura 2D stilizzata in SVG, ed è quello che c'è in
`src/components/Avatar/AvatarSvg.jsx`. Non è una regressione, è un limite di
progetto che ora vogliamo superare.

**"I vestiti non si inseriscono correttamente."** Questo è un difetto vero, con
causa dimostrata. In `AvatarSvg.jsx` la foto del capo viene inserita in un
riquadro fisso con `preserveAspectRatio="xMidYMid slice"` e ritagliata dentro una
`clipPath` a forma di indumento. Il riquadro del bottom misura 68×238 unità
(rapporto ≈ 1:3,5) mentre le foto dei capi sono quasi quadrate: per "coprire" quel
riquadro l'immagine viene ingrandita finché sopravvive solo la striscia centrale,
circa il 28% della larghezza originale. Riproduzione con una foto sintetica di
jeans su sfondo grigio: le gambe della silhouette si riempiono quasi interamente
di **sfondo**, del capo resta una striscia verticale, la cintura finisce a metà
coscia.

Le cause sono due e sono entrambe strutturali:

1. il ritaglio `slice` su riquadri dalle proporzioni estreme butta via la maggior
   parte della foto (bottom e abiti sono i più colpiti; il top se la cava solo
   perché il suo riquadro è quasi quadrato);
2. nessuno scontorna il capo, quindi la sagoma viene riempita con i pixel della
   foto qualunque essi siano, sfondo compreso — e anche scontornando, la forma del
   capo nella foto non è allineata alla forma della sagoma.

Conclusione: incollare una foto rettangolare dentro una sagoma non produrrà mai un
capo indossato. L'approccio a collage ha raggiunto il suo limite, ed è lo stesso
limite che fa percepire la figura come piatta.

## 2. Decisioni prese

| Aspetto | Decisione |
|---|---|
| Figura | Corpo umano stilizzato low-poly, conserva `avatar_config` (corporatura, carnagione, colore e taglio capelli) |
| Origine delle mesh | Generate proceduralmente in codice con three.js. Nessun GLB esterno, nessuna licenza di terzi, nessun asset da scaricare |
| Capi | Mesh 3D generiche (top, abito, bottom, capospalla, scarpe), osservabili a tutto tondo ruotando la figura |
| Texture del capo | Ibrida: foto reale scontornata proiettata sul davanti, colore dominante campionato dalla foto su fianchi e retro |
| Dove | Solo la pagina "Prova sull'Avatar" (`/tryon`), scheda "Sull'avatar". Caricamento lazy |
| Fallback | Se WebGL non è disponibile, `AvatarSvg` **corretto** (approccio 2.5D): stessa pipeline di scontorno, capo intero dentro la sagoma invece del ritaglio `slice` di oggi |
| Try-on AI | Invariato: la scheda "Sulla tua foto (AI)" con Gemini resta la modalità fotorealistica |
| Onboarding, editor Profilo | Invariati, restano SVG 2D |

**Perché mesh procedurali e non un GLB scaricato.** Un modello esterno pesa
megabyte, va verificato nelle licenze, e soprattutto rende regolabile la
corporatura solo se il modello espone già dei morph target: senza, lo slider
corporatura che esiste oggi smetterebbe di funzionare. Con la geometria costruita
in codice la corporatura è letteralmente un parametro del profilo ruotato. Il
peso aggiunto è il solo three.js (~170 KB gzip) e viene scaricato unicamente da
chi apre `/tryon`.

**Perché la texture ibrida.** Avvolgere la foto su tutta la mesh la stira sui
fianchi e la ripete sul retro, e peggiora proprio nel momento in cui si ruota la
figura — cioè la ragione per cui vogliamo il 3D. La tinta unita è sempre
elegante ma rende identiche una camicia a righe e una a pois. L'ibrido mostra la
fantasia dove la si guarda e chiude il resto con un colore che viene comunque dal
capo vero.

## 3. Architettura

Tutto il nuovo codice vive in `src/components/Avatar/` e `src/utils/`, e segue la
divisione già in uso nel progetto: la logica pura sta negli `utils` ed è testata
con Vitest, i componenti React si limitano a montarla.

```
TryOnPage
  └── OutfitOnAvatar          sceglie 3D o SVG, monta le card ＋/✕ (invariate)
        ├── Avatar3D          React.lazy, solo se WebGL c'è
        │     ├── avatarMesh.js     corpo dai parametri di avatar_config
        │     ├── garmentMesh.js    le 5 mesh dei capi
        │     └── garmentTexture.js scontorno + colore dominante dalla foto
        └── AvatarSvg         fallback, corretto con garmentTexture.js
```

Il fallback non è l'`AvatarSvg` di oggi così com'è: quello contiene il difetto
descritto al punto 1. Riceve la stessa texture scontornata prodotta da
`garmentTexture.js` e la disegna **intera** dentro la sagoma (`meet`, non
`slice`), centrata sul rettangolo del capo. Resta piatto — è un ripiego — ma
mostra il capo giusto al posto giusto.

- **`Avatar3D.jsx`** — scena three.js: camera, luci statiche, controllo di
  rotazione al trascinamento. È l'unico file che parla con three.js in modo
  imperativo. Riceve `config` e `outfit`, esattamente come `AvatarSvg` oggi.
- **`src/utils/avatarMesh.js`** — funzione pura da `avatar_config` a descrizioni
  di geometria: profili per torso, gambe, braccia e collo da ruotare attorno
  all'asse (`LatheGeometry`), sfere per testa e capigliature. Il fattore di
  larghezza corporea che oggi esiste in `avatarOptions.js` (`getBodyWidthFactor`)
  viene riusato tale e quale come moltiplicatore dei raggi.
- **`src/utils/garmentMesh.js`** — funzione pura da tipo di capo a descrizione di
  geometria, costruita come guscio del corpo con un piccolo scostamento verso
  l'esterno, così il capo aderisce alla corporatura scelta. I cinque tipi
  corrispondono ai `kind` che `garmentLayers()` restituisce già oggi
  (`top`, `dress`, `bottom`, `outerwear`, `shoes`): **`tryonComposer.js` non
  cambia**, cambia solo chi consuma il suo output.
- **`src/utils/garmentTexture.js`** — il cuore del secondo problema, vedi sotto.

`OutfitOnAvatar` resta il punto di ingresso e conserva le card polaroid con ＋ e ✕
intorno alla figura: sono controlli, funzionano, non si toccano.

## 4. Pipeline della foto del capo

Modulo puro `garmentTexture.js`, tutto in canvas, nessuna rete, nessun costo.
Da una foto produce due valori: una texture scontornata e un colore dominante.

1. **Scontorno.** Riempimento a partire dai quattro angoli con tolleranza sul
   colore (i pixel connessi a un angolo e cromaticamente vicini ad esso sono
   sfondo). Copre le foto di negozio e quelle scattate su una superficie piatta,
   che sono il caso normale.
2. **Rettangolo del capo.** Si calcola il bounding box dei pixel sopravvissuti e
   si scarta tutto il resto. **È esattamente il passo che manca oggi** e che fa
   entrare lo sfondo nelle gambe della silhouette.
3. **Colore dominante.** k-means sui soli pixel del capo, mai sullo sfondo.
4. **Applicazione.** Il ritaglio diventa la texture della faccia frontale della
   mesh, con `preserveAspectRatio` equivalente a "contain": il capo si vede
   **intero**, mai tagliato. Fianchi e retro prendono il colore dominante.

**Degradazione.** Se lo scontorno non converge (sfondo troppo movimentato: più di
una soglia di pixel classificati come capo, oppure bounding box che copre quasi
tutta l'immagine), si rinuncia alla texture e il capo resta in tinta unita con il
colore dominante calcolato sull'intera foto. Brutto no, sbagliato mai.

**Fotografie remote.** I capi aggiunti da link hanno una `photo` su dominio
esterno: leggerne i pixel in canvas può fallire per CORS, come già succede al
try-on Gemini. In quel caso si salta direttamente alla tinta unita, ricavando il
colore dal campo `colors` del capo, che è già in `sv_items` e nel DB.

## 5. Prestazioni

Vincolo: Mary la usa dal telefono.

- Nessun ciclo di rendering continuo. Si ridisegna solo quando cambia l'outfit o
  mentre si trascina per ruotare.
- `devicePixelRatio` limitato a 2.
- Luci statiche, nessuna ombra proiettata in tempo reale.
- `React.lazy` su `Avatar3D`: three.js entra nel bundle di `/tryon` e in nessun
  altro punto dell'app. Onboarding e Profilo non rallentano.
- Le texture dei capi si calcolano una volta e si riusano finché l'outfit non
  cambia.

## 6. Errori e casi limite

| Caso | Comportamento |
|---|---|
| WebGL assente o context perso | Si monta `AvatarSvg` corretto: figura piatta, ma capo intero e ben posizionato |
| Foto del capo su dominio esterno (CORS) | Tinta unita dal campo `colors` del capo |
| Scontorno fallito | Tinta unita dal colore dominante dell'intera foto |
| Capo senza foto | Tinta unita dal campo `colors` |
| Outfit vuoto | Corpo nudo stilizzato, come oggi |
| Accessori | Nessuna mesh: restano card intorno alla figura, come oggi |

## 7. Verifica

- **Test unitari Vitest** su `garmentTexture.js` (scontorno, bounding box, colore
  dominante, degradazioni) usando immagini sintetiche costruite in canvas, e su
  `avatarMesh.js` / `garmentMesh.js` (i parametri di corporatura producono
  geometrie con le proporzioni attese, i cinque tipi di capo producono mesh
  distinte). I 58 test esistenti devono restare verdi.
- **Verifica a schermo** con Chrome via playwright-core, come per la riproduzione
  del difetto: i cinque tipi di capo indossati, la rotazione a 360°, un outfit
  completo, il fallback SVG con WebGL disabilitato (dove il capo deve risultare
  intero, non più una striscia), zero errori in console, screenshot allegato.
- **Prova su mobile reale** prima di dire a Mary che c'è.

## 8. Fuori scope

- Simulazione fisica del tessuto (drappeggio, pieghe).
- Ricostruzione 3D del capo reale dalla foto: non esiste oggi un modo gratuito e
  nel browser. La forma resta generica, il tessuto è quello vero. Chi vuole il
  capo esatto addosso usa la scheda "Sulla tua foto (AI)".
- Pose e animazioni: la figura sta in piedi e ruota, nient'altro.
- Avatar 3D in onboarding ed editor del Profilo.
