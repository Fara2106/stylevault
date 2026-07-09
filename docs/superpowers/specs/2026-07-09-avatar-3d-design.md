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
| Scelta della resa | La decide l'utente, non noi: un selettore "3D" / "Piatto" dentro la scheda "Sull'avatar". Preferenza salvata in `localStorage['sv_avatar_render']` |
| Modalità piatta | `AvatarSvg` **corretto** (approccio 2.5D): stessa pipeline di scontorno, capo intero dentro la sagoma invece del ritaglio `slice` di oggi |
| Fallback automatico | Se WebGL non è disponibile si forza la modalità piatta e il selettore 3D si disabilita, spiegando perché |
| Try-on AI | Invariato **in questa spec**: la scheda "Sulla tua foto (AI)" resta con la chiave dell'utente. Il proxy lato server è una spec separata (vedi §9) |
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
  └── OutfitOnAvatar          selettore 3D/Piatto, card ＋/✕ (invariate)
        ├── Avatar3D          React.lazy, solo in modalità 3D
        │     ├── avatarMesh.js     corpo dai parametri di avatar_config
        │     ├── garmentMesh.js    le 5 mesh dei capi
        │     └── garmentTexture.js scontorno + colore dominante dalla foto
        └── AvatarSvg         modalità piatta, corretta con garmentTexture.js
```

La modalità piatta non è l'`AvatarSvg` di oggi così com'è: quello contiene il
difetto descritto al punto 1. Riceve la stessa texture scontornata prodotta da
`garmentTexture.js` e la disegna **intera** dentro la sagoma (`meet`, non
`slice`), centrata sul rettangolo del capo. Resta piatta — costa poco e va
sempre — ma mostra il capo giusto al posto giusto.

**Il selettore.** Due modalità esposte all'utente, non una scelta nostra
mascherata da fallback: "3D" (si ruota col dito, si vede il capo a tutto tondo)
e "Piatto" (leggero, istantaneo, non consuma batteria). La preferenza vive in
`localStorage['sv_avatar_render']`, default "3D" dove WebGL c'è. È l'utente a
decidere, come per le due schede avatar/foto già esistenti.

**Ogni modalità dichiara cosa costa e cosa non sa fare** (richiesta esplicita di
Lorenzo: "metti tutto a scelta, esponendo anche quanto costa e dando tutte le
info"). Sotto ogni scelta compare una riga onesta:

| Modalità | Testo mostrato |
|---|---|
| 3D | Gratis e illimitata. Ruoti la figura col dito. La forma del capo è generica: colore e fantasia sono i tuoi, il taglio no |
| Piatto | Gratis e illimitata. Leggera, non consuma batteria. La figura non ruota |
| Sulla tua foto (AI) | A pagamento: circa 4 centesimi a foto, a carico di chi possiede la chiave. È l'unica che mostra il tuo capo esatto addosso a te. L'immagine è ferma, non ruota |

Nessun testo deve promettere gratuità dove non c'è, né realismo dove non c'è.

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
3. **Colore dominante.** Istogramma quantizzato (bucket a 4 bit per canale, si
   prende la moda, poi si media sui pixel reali di quel bucket) sui soli pixel
   del capo, mai sullo sfondo. Deterministico, quindi testabile — a differenza di
   un k-means con centroidi casuali.
4. **Applicazione in 3D.** Il ritaglio, con sfondo trasparente, veste una
   superficie curva applicata sul davanti del capo; la mesh sotto è colorata con
   il colore dominante. Fianchi e retro restano in tinta.
5. **Applicazione in piatto.** Il ritaglio viene disegnato **intero** sopra il
   corpo, ancorato alla parte giusta (`xMidYMin meet`). Non c'è più nessuna
   `clipPath`: avendo lo sfondo trasparente, il capo non ha bisogno di essere
   infilato dentro una sagoma. Il difetto del §1 non viene aggiustato, viene
   eliminato alla radice. Le sagome di `GARMENT_SHAPES` sopravvivono solo per il
   caso degradato: quando la texture manca, si riempiono di tinta unita.

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
| WebGL assente o context perso | Si forza la modalità piatta, il selettore 3D si disabilita e spiega perché |
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
- Il proxy server per Gemini: spec separata, vedi §9.

## 9. Il progetto gemello: Gemini senza chiave dell'utente

**Non fa parte di questa spec.** Va scritto e implementato subito dopo, come
progetto a sé, perché ha rischi e ciclo di vita completamente diversi.

Il problema: oggi la scheda "Sulla tua foto (AI)" richiede che sia **l'utente** a
creare una chiave su Google AI Studio e ad attivarsi la fatturazione
(`localStorage['sv_gemini_key']`, vedi `src/services/geminiTryon.js`).
Realisticamente Mary non lo farà mai, quindi la modalità fotorealistica per lei
non esiste.

La soluzione: una Edge Function Supabase che tiene la chiave di Lorenzo lato
server e inoltra la richiesta a Google. Il progetto ne ha già una
(`supabase/functions/fetch-link-metadata/`), quindi il terreno è noto.

**Il rischio che rende obbligatoria la spec separata:** la chiave è di Lorenzo, il
sito è pubblico e ogni immagine costa ~$0.04. Senza difese, chiunque si registri
può spendere i suoi soldi. Vincoli non negoziabili per quel progetto:

- la funzione accetta solo utenti autenticati (verifica del JWT);
- quota per utente, contata su Postgres (ordine di grandezza: 20 generazioni al
  mese), applicata **lato server**, mai nel browser;
- l'utente resta libero di usare una propria chiave, che bypassa la quota.
