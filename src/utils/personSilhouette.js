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

  const shoulders = widestRow(rows, box, 0.1, 0.3);
  const hips = widestRow(rows, box, 0.45, 0.62);
  if (!shoulders || !hips) return null;

  // Cavallo: prima riga sotto i fianchi in cui la figura si divide in (almeno)
  // due corse consistenti — le gambe. Se non si divide mai (gambe unite,
  // gonna lunga), si stima al 53% dell'altezza.
  const minLegRun = Math.max(2, Math.round(box.width * 0.08));
  let crotchY = null;
  const yFrom = box.top + Math.round(0.45 * box.height);
  const yTo = box.top + Math.round(0.7 * box.height);
  for (let y = yFrom; y < yTo; y++) {
    const row = rows[y];
    if (!row) continue;
    const legs = row.runs.filter(([a, b]) => b - a >= minLegRun);
    if (legs.length >= 2) {
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
