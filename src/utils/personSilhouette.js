/**
 * Analisi della silhouette della persona dal PNG scontornato (@imgly):
 * dall'alpha si ricavano i punti del corpo che servono a vestirla con
 * proporzioni vere — spalle, fianchi, cavallo, caviglie. Puro (lavora su
 * un oggetto {width,height,data} come ImageData): testabile in node.
 *
 * Le fasce verticali sono frazioni dell'altezza della figura, prese
 * dall'antropometria di una persona in piedi frontale: spalle ~18%
 * dall'alto, fianchi ~52%, cavallo ~53%, caviglie ~95%. Le fasce sono
 * larghe apposta: dentro ciascuna si cerca il massimo (o la prima riga
 * col dato cercato), così la posa reale corregge la statistica.
 */

/** Sotto questa alpha un pixel è alone dello scontorno, non figura. */
export const ALPHA_OPAQUE = 40;

/** Le corse di una riga: intervalli [inizio, fine) di pixel opachi. */
const rowRuns = (image, y, threshold) => {
  const { width, data } = image;
  const runs = [];
  let start = -1;
  for (let x = 0; x < width; x++) {
    const opaque = data[(y * width + x) * 4 + 3] >= threshold;
    if (opaque && start < 0) start = x;
    if (!opaque && start >= 0) {
      runs.push([start, x]);
      start = -1;
    }
  }
  if (start >= 0) runs.push([start, width]);
  return runs;
};

/**
 * Riquadro dei pixel con alpha sopra soglia, o null se non ce ne sono.
 * Serve anche da solo, per ritagliare i capi scontornati al contenuto.
 * @returns {{top:number,bottom:number,left:number,right:number}|null}
 */
export function alphaBounds(image, threshold = ALPHA_OPAQUE) {
  const { width, height, data } = image;
  let top = -1;
  let bottom = -1;
  let left = width;
  let right = -1;
  for (let y = 0; y < height; y++) {
    let rowHas = false;
    for (let x = 0; x < width; x++) {
      if (data[(y * width + x) * 4 + 3] >= threshold) {
        rowHas = true;
        if (x < left) left = x;
        if (x > right) right = x;
      }
    }
    if (rowHas) {
      if (top < 0) top = y;
      bottom = y;
    }
  }
  return top < 0 ? null : { top, bottom, left, right };
}

/**
 * Riquadro del CONTENUTO di un capo scontornato: come alphaBounds, ma scarta
 * le righe strette in cima — il gancio e il collo della gruccia, che @imgly
 * tiene nel ritaglio perché attaccati al capo. Una riga è "gancio" se il suo
 * span è sotto il 25% dello span massimo del capo; le spalle di un capo
 * appeso raggiungono quasi subito la larghezza piena, il gancio mai.
 */
export function garmentContentBounds(image, threshold = ALPHA_OPAQUE) {
  const bounds = alphaBounds(image, threshold);
  if (!bounds) return null;

  const spans = [];
  let maxSpan = 0;
  for (let y = bounds.top; y <= bounds.bottom; y++) {
    const runs = rowRuns(image, y, threshold);
    if (runs.length === 0) continue;
    const span = runs[runs.length - 1][1] - runs[0][0];
    spans[y] = { span, left: runs[0][0], right: runs[runs.length - 1][1] - 1 };
    if (span > maxSpan) maxSpan = span;
  }

  let top = bounds.top;
  while (top < bounds.bottom && (!spans[top] || spans[top].span < maxSpan * 0.25)) top++;

  // left/right ricalcolati sulle sole righe rimaste: senza il gancio il capo
  // può essere meno largo del riquadro originale.
  let left = image.width;
  let right = -1;
  for (let y = top; y <= bounds.bottom; y++) {
    if (!spans[y]) continue;
    if (spans[y].left < left) left = spans[y].left;
    if (spans[y].right > right) right = spans[y].right;
  }
  return { top, bottom: bounds.bottom, left, right };
}

/** Riga con lo span (right-left) massimo nella fascia [f0, f1) dell'altezza. */
const widestRow = (rows, box, f0, f1) => {
  const y0 = box.top + Math.round(f0 * box.height);
  const y1 = box.top + Math.round(f1 * box.height);
  let best = null;
  for (let y = y0; y < y1; y++) {
    const row = rows[y];
    if (!row) continue;
    if (!best || row.width > best.width) best = { y, ...row };
  }
  return best;
};

/**
 * Come widestRow, ma misura solo la corsa che contiene `cx` (l'asse del
 * corpo): le macchie staccate ai lati — la mano scontornata — non contano.
 */
const widestCentralRun = (rows, box, f0, f1, cx) => {
  const y0 = box.top + Math.round(f0 * box.height);
  const y1 = box.top + Math.round(f1 * box.height);
  let best = null;
  for (let y = y0; y < y1; y++) {
    const row = rows[y];
    if (!row) continue;
    const run =
      row.runs.find(([a, b]) => a <= cx && cx < b) ||
      row.runs.reduce((m, r) => (r[1] - r[0] > m[1] - m[0] ? r : m));
    const width = run[1] - run[0];
    if (!best || width > best.width) {
      best = { y, left: run[0], right: run[1] - 1, width, cx: Math.round((run[0] + run[1] - 1) / 2) };
    }
  }
  return best;
};

/**
 * @param {{width:number,height:number,data:Uint8ClampedArray}} image PNG scontornato
 * @returns {null | {
 *   box: {top:number,bottom:number,left:number,right:number,width:number,height:number},
 *   shoulders: {y:number,left:number,right:number,width:number,cx:number},
 *   hips: {y:number,left:number,right:number,width:number,cx:number},
 *   crotchY: number, ankleY: number, cx: number,
 * }}
 */
export function analyzeSilhouette(image, threshold = ALPHA_OPAQUE) {
  const bounds = alphaBounds(image, threshold);
  if (!bounds) return null;
  const box = {
    ...bounds,
    width: bounds.right - bounds.left + 1,
    height: bounds.bottom - bounds.top + 1,
  };

  // Per ogni riga della figura: corse, span totale e centro.
  const rows = [];
  for (let y = box.top; y <= box.bottom; y++) {
    const runs = rowRuns(image, y, threshold);
    if (runs.length === 0) continue;
    const left = runs[0][0];
    const right = runs[runs.length - 1][1] - 1;
    rows[y] = { runs, left, right, width: right - left + 1, cx: Math.round((left + right) / 2) };
  }

  // Spalle: riga fissa al 18% dell'altezza dall'alto (antropometria di una
  // figura in piedi: testa ~13%, spalle subito sotto). Cercare la riga più
  // larga qui è fragile: le braccia leggermente scostate dal corpo diventano
  // più larghe delle spalle già a metà torace, e il capo finirebbe basso.
  const shoulderY = box.top + Math.round(0.18 * box.height);
  const shoulders = rows[shoulderY]
    ? { y: shoulderY, ...rows[shoulderY] }
    : widestRow(rows, box, 0.1, 0.3);
  // Fianchi: nella fascia c'è spesso anche la mano, che lo scontorno può
  // staccare dal corpo (una corsa separata). Si misura solo la corsa che
  // contiene l'asse del corpo, non lo span dell'intera riga.
  const hips = widestCentralRun(rows, box, 0.45, 0.62, shoulders?.cx);
  if (!shoulders || !hips) return null;

  // Cavallo: prima riga sotto i fianchi in cui la figura si divide in due
  // corse consistenti — le gambe — col vuoto A CAVALLO DELL'ASSE del corpo:
  // la separazione braccio-fianco o mano-coscia sta di lato, non sull'asse.
  // Se le gambe non si dividono mai (gonna lunga), si stima al 53%.
  const minLegRun = Math.max(2, Math.round(box.width * 0.08));
  let crotchY = null;
  const yFrom = box.top + Math.round(0.45 * box.height);
  const yTo = box.top + Math.round(0.7 * box.height);
  for (let y = yFrom; y < yTo; y++) {
    const row = rows[y];
    if (!row) continue;
    const legs = row.runs.filter(([a, b]) => b - a >= minLegRun);
    const split = legs.some((run, i) => {
      const next = legs[i + 1];
      return next && run[1] <= shoulders.cx && shoulders.cx < next[0];
    });
    if (split) {
      crotchY = y;
      break;
    }
  }
  if (crotchY === null) crotchY = box.top + Math.round(0.53 * box.height);

  const ankleY = box.bottom - Math.round(0.05 * box.height);

  return {
    box,
    shoulders,
    hips,
    crotchY,
    ankleY,
    cx: Math.round((shoulders.cx + hips.cx) / 2),
  };
}
