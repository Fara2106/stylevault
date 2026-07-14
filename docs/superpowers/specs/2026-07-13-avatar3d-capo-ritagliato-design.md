# Avatar 3D: il capo ritagliato messo sul manichino (non tilato)

Data: 2026-07-13

## Problema

Nell'avatar 3D il capo viene reso prendendo un quadratino di tessuto
(`swatchUrl`) e **ripetendolo come piastrella** (`repeat(3,3)`) su tutta la
mesh del corpo, con le gambe specchiate. Il risultato sono strisce verticali
"spiattellate", che leggono come carta da parati e non come un capo indossato.

Vogliamo invece che il capo venga **ritagliato dalla foto e messo addosso al
manichino come un capo intero** (una maglietta che sembra una maglietta), anche
in stile "a mo' di cartone". Il manichino può restare stilizzato: il corpo non
è il problema, lo è la resa del capo.

## Scoperta che riduce il lavoro

Il ritaglio del capo intero con sfondo trasparente **esiste già**: è
`textureUrl` prodotto da `loadGarmentTexture` in
[`src/utils/garmentImage.js`](../../../src/utils/garmentImage.js) tramite
`cutout(imageData, mask, bounds)`. Oggi è usato **solo dalla modalità piatta
2D**; l'avatar 3D lo ignora e usa `swatchUrl`. Quindi non serve inventare
l'estrazione: serve solo far usare al 3D il ritaglio che già produciamo.

## Obiettivo

Nell'avatar 3D, sostituire la piastrella tilata con **il ritaglio del capo
intero mappato su un pannello che segue il corpo**, sul davanti e sul dietro.

## Non-obiettivi

- Nessun modello GLB / avatar realistico (pivot scartato).
- Nessuna modifica alla modalità piatta 2D (`AvatarSvg`, `OutfitOnAvatar`):
  continua a usare le sue immagini invariata.
- Nessuna riscrittura del corpo/manichino. Eventuali ritocchi al corpo sono
  lavoro separato, fuori da questa spec.
- Nessun cambio all'estrazione del capo in `garmentTexture.js` /
  `garmentImage.js` (produce già `textureUrl`).

## Design

Intervento concentrato in
[`src/components/Avatar/Avatar3D.jsx`](../../../src/components/Avatar/Avatar3D.jsx).

### 1. Il capo diventa un pannello, non un pattern

Per ogni layer di capo (`garmentLayers(outfit)`):

- Se la texture ha un ritaglio (`texture.textureUrl`, cioè `kind === 'texture'`):
  - Ricavare la **zona del capo** (intervallo di altezza `y` e raggio del
    corpo) dai `garmentParts(kind, config)` già esistenti — la parte
    principale `parts[0]` dà il profilo, da cui `y` min/max e il raggio via
    `radiusAt`.
  - Costruire un **pannello frontale curvo**: un arco di cilindro (~140°, come
    l'attuale `DECAL_ARC`) al raggio del corpo + un piccolo offset, alto quanto
    la zona del capo. Mapparci sopra `textureUrl` con UV planare (u attorno
    all'arco, v verticale), materiale `transparent: true`, `side: DoubleSide`,
    così lo sfondo trasparente del ritaglio lascia vedere il corpo attorno.
  - Aggiungere una **copia dietro** (arco speculare a ~180°), stessa texture.
  - **Proporzioni:** il ritaglio va inserito nella zona rispettando il proprio
    aspect ratio (letterbox trasparente), così una maglietta occupa l'area del
    busto senza deformarsi. L'aspect si legge dall'immagine caricata
    (`image.width/height`) nel callback del `TextureLoader`.

### 2. Via piastrella e decal separato della stampa

- Rimuovere, nel percorso 3D, l'uso di `swatchUrl` tilato e la chiamata a
  `printDecal`: la stampa/logo è già dentro il ritaglio intero, non va
  ri-estratta né ri-posizionata. Questo elimina anche il rischio di z-fighting
  del decal.
- Le funzioni `garmentMaterial` (ramo swatch) e `printDecal` possono essere
  rimosse o ridotte se non più usate nel 3D. `swatchUrl`/`printUrl`/`printAt`
  restano nel contratto di `loadGarmentTexture` perché la modalità 2D li usa.

### 3. Rete di sicurezza (fallback)

- Se il capo **non è ritagliabile** (`kind === 'flat'`: foto bloccata da CORS,
  o estrazione degradata → niente `textureUrl`), rendere il capo in **tinta
  unita** col colore dominante (`texture.colorHex`), riusando le mesh
  `garmentParts` come oggi. Comportamento invariato: "brutto no, sbagliato mai".

### Zone per tipo di capo

Le zone derivano dai profili di `garmentParts(kind, config)` esistenti:

- `top` → busto + spalle
- `bottom` → gambe (capo specchiato: pannello per gamba, oppure un unico
  pannello frontale sull'area gambe — da decidere in fase di piano, preferendo
  la resa più pulita)
- `outerwear` / capospalla → busto + braccia

Non si introducono nuove zone: si usa l'intervallo `y`/raggio della parte
principale di ciascun `kind`.

## Contratto dati usato (già esistente)

Da `loadGarmentTexture(item)` in `garmentImage.js`:

- `textureUrl: string|null` — PNG del capo intero scontornato (sfondo
  trasparente). **È l'input principale del nuovo rendering.**
- `colorHex: string` — colore dominante, per il fallback tinta unita.
- `kind: 'texture' | 'flat'` — `'flat'` → percorso fallback.

## Test e verifica

- Le funzioni pure (estrazione, eventuali helper di geometria del pannello
  estraibili senza three.js) restano coperte da Vitest.
- three.js non gira nei test (vincolo noto): la resa 3D si verifica **a
  schermo** con foto di capi veri, controllando che:
  1. il capo appaia come un capo intero sul busto/gambe, non come pattern
     ripetuto;
  2. ruotando la figura il capo resti davanti e ci sia il dietro;
  3. un capo con logo mostri il logo al posto giusto (perché è dentro il
     ritaglio);
  4. una foto non ritagliabile ricada sulla tinta unita senza rompersi.

## File toccati

- `src/components/Avatar/Avatar3D.jsx` — nuovo rendering a pannello, rimozione
  del ramo piastrella/decal nel 3D.
- (Eventuale) nuovo modulo puro per la geometria del pannello, se conviene
  isolarlo e testarlo.

## Rischi

- Un pannello frontale piatto/curvo, ruotato di lato, mostra il suo spessore
  nullo: mitigato dalla curvatura sull'arco e dalla copia dietro. Accettabile
  nello stile "a mo' di cartone" concordato.
- Foto di capo in flat-lay con maniche molto aperte: il ritaglio le include e
  potrebbero "sporgere" piatte ai lati del busto. Accettabile nello stile
  concordato; se disturba, si può ritagliare più stretto in un secondo momento.
