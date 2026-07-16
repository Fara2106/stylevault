/**
 * Warping dei capi sulla persona vera, riga per riga. Puro: produce PIANI
 * (liste di mappature riga→riga), l'esecuzione su canvas sta in modelImage.js.
 *
 * L'idea: invece di appoggiare la foto del capo come un rettangolo rigido,
 * ogni riga del capo viene stirata orizzontalmente per coprire lo span dei
 * vestiti (o del corpo) della persona a quella altezza — così la maglia
 * "abbraccia" il busto e copre il vestito originale, e ogni gamba dei
 * pantaloni segue la colonna della gamba vera (anca→ginocchio→caviglia).
 */
import { ALPHA_OPAQUE } from './personSilhouette';

/**
 * Corse opache per riga di un'immagine scontornata.
 * @returns {({runs:number[][], left:number, right:number}|null)[]}
 *          runs = intervalli [inizio, fine) in pixel.
 */
export function imageRows(image, threshold = ALPHA_OPAQUE) {
  const { width, height, data } = image;
  const rows = new Array(height).fill(null);
  for (let y = 0; y < height; y++) {
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
    if (runs.length > 0) {
      rows[y] = { runs, left: runs[0][0], right: runs[runs.length - 1][1] - 1 };
    }
  }
  return rows;
}

/** Distanza di un punto da un intervallo [a, b). */
const runDistance = (run, x) => (x < run[0] ? run[0] - x : x >= run[1] ? x - run[1] + 1 : 0);

/**
 * Per ogni riga della maschera classi: lo span {left,right} della corsa di
 * pixel delle classi date più vicina all'asse del corpo (idealmente quella
 * che lo contiene). null dove la classe non compare.
 * @param {{width:number,height:number,categories:Uint8Array}} seg
 * @param {number[]} classes classi accettate (es. [SEG_CLOTHES])
 * @param {number} axisX asse verticale del corpo, in pixel
 */
export function classRowSpans(seg, classes, axisX) {
  const { width, height, categories } = seg;
  const wanted = new Set(classes);
  const spans = new Array(height).fill(null);
  for (let y = 0; y < height; y++) {
    const runs = [];
    let start = -1;
    for (let x = 0; x < width; x++) {
      const ok = wanted.has(categories[y * width + x]);
      if (ok && start < 0) start = x;
      if (!ok && start >= 0) {
        runs.push([start, x]);
        start = -1;
      }
    }
    if (start >= 0) runs.push([start, width]);
    if (runs.length === 0) continue;
    let best = runs[0];
    for (const run of runs) if (runDistance(run, axisX) < runDistance(best, axisX)) best = run;
    spans[y] = { left: best[0], right: best[1] - 1 };
  }
  return spans;
}

/**
 * Ammorbidisce gli span con una media mobile (la maschera è rumorosa riga per
 * riga e il capo warpato vibrerebbe). I buchi restano buchi; vicino ai buchi
 * si media solo ciò che esiste.
 */
export function smoothSpans(spans, radius = 3) {
  const out = new Array(spans.length).fill(null);
  for (let y = 0; y < spans.length; y++) {
    if (!spans[y]) continue;
    let l = 0;
    let r = 0;
    let n = 0;
    for (let k = y - radius; k <= y + radius; k++) {
      const s = spans[k];
      if (!s) continue;
      l += s.left;
      r += s.right;
      n++;
    }
    out[y] = { left: Math.round(l / n), right: Math.round(r / n) };
  }
  return out;
}

/**
 * Tutte le corse per riga delle classi date (non solo quella sull'asse):
 * servono per le gambe, dove la corsa giusta è quella vicina alla gamba.
 * @returns {number[][][]} per riga: intervalli [inizio, fine).
 */
export function classRuns(seg, classes) {
  const { width, height, categories } = seg;
  const wanted = new Set(classes);
  const rows = new Array(height).fill(null);
  for (let y = 0; y < height; y++) {
    const runs = [];
    let start = -1;
    for (let x = 0; x < width; x++) {
      const ok = wanted.has(categories[y * width + x]);
      if (ok && start < 0) start = x;
      if (!ok && start >= 0) {
        runs.push([start, x]);
        start = -1;
      }
    }
    if (start >= 0) runs.push([start, width]);
    if (runs.length > 0) rows[y] = runs;
  }
  return rows;
}

/** Lo span della corsa più vicina a `x`, o null. */
export function nearestRunSpan(runs, x) {
  if (!runs || runs.length === 0) return null;
  let best = runs[0];
  for (const run of runs) if (runDistance(run, x) < runDistance(best, x)) best = run;
  return { left: best[0], right: best[1] - 1 };
}

/**
 * X di una polilinea (punti ordinati per y crescente) all'altezza y,
 * con interpolazione lineare e bloccata agli estremi.
 */
export function polylineX(points, y) {
  if (y <= points[0].y) return points[0].x;
  for (let i = 1; i < points.length; i++) {
    if (y <= points[i].y) {
      const a = points[i - 1];
      const b = points[i];
      const t = b.y === a.y ? 0 : (y - a.y) / (b.y - a.y);
      return a.x + t * (b.x - a.x);
    }
  }
  return points[points.length - 1].x;
}

/** Le corse di una riga larghe almeno `minWidth`. */
const bigRuns = (row, minWidth) => (row ? row.runs.filter(([a, b]) => b - a >= minWidth) : []);

/**
 * Divide un capo "bottom" nelle due gambe: trova la prima riga in cui il capo
 * si separa in due corse consistenti e da lì in giù tiene la corsa sinistra e
 * destra per riga. null se non si separa mai (gonna, abito).
 * @returns {{crotchRow:number, legL:number[][], legR:number[][]}|null}
 */
export function garmentLegSplit(garmentRows, imageWidth) {
  const minRun = Math.max(2, Math.round(imageWidth * 0.15));
  let crotchRow = null;
  for (let y = 0; y < garmentRows.length; y++) {
    if (bigRuns(garmentRows[y], minRun).length >= 2) {
      crotchRow = y;
      break;
    }
  }
  if (crotchRow === null) return null;

  const legL = [];
  const legR = [];
  for (let y = crotchRow; y < garmentRows.length; y++) {
    const runs = bigRuns(garmentRows[y], minRun);
    if (runs.length >= 2) {
      legL[y] = runs[0];
      legR[y] = runs[runs.length - 1];
    } else if (runs.length === 1) {
      // gambe accavallate/unite in questa riga: la stessa corsa per entrambe
      legL[y] = runs[0];
      legR[y] = runs[0];
    }
  }
  return { crotchRow, legL, legR };
}

/** Una riga di piano: copia la riga sorgente ys [sx0, sx0+sw) in [dx0, dx0+dw) a yd. */
const planRow = (yd, ys, src, dest) =>
  src && dest
    ? {
        yd,
        ys,
        sx0: src[0],
        sw: src[1] - src[0],
        dx0: dest.left,
        dw: dest.right - dest.left + 1,
      }
    : null;

/**
 * Piano di warping per top/abito/capospalla: le righe del capo (dal colletto
 * all'orlo) coprono gli span di destinazione (i vestiti della persona, o il
 * corpo). Le righe senza destinazione si saltano.
 *
 * `shoulderRefWidth` (opzionale): larghezza "di spalla" del capo. Le righe
 * più strette (scollo, fine maniche) NON vengono stirate a tutta larghezza:
 * restano proporzionali e centrate — sennò il colletto diventa una banda.
 */
export function topWarpPlan({ garmentRows, garmentBox, destSpans, collarY, hemY, shoulderRefWidth }) {
  const plan = [];
  const gh = garmentBox.bottom - garmentBox.top;
  const dh = Math.max(1, hemY - collarY);
  for (let yd = Math.round(collarY); yd <= Math.round(hemY); yd++) {
    const t = (yd - collarY) / dh;
    const ys = garmentBox.top + Math.round(t * gh);
    const row = garmentRows[ys];
    const dest = destSpans[yd];
    const p = row && planRow(yd, ys, [row.left, row.right + 1], dest);
    if (!p) continue;
    if (shoulderRefWidth) {
      const srcW = row.right - row.left + 1;
      if (srcW < shoulderRefWidth * 0.97) {
        const baseW = dest.right - dest.left + 1;
        p.dw = Math.max(1, Math.round((baseW * srcW) / shoulderRefWidth));
        p.dx0 = Math.round((dest.left + dest.right) / 2 - p.dw / 2);
      }
    }
    plan.push(p);
  }
  return plan;
}

/**
 * Piano di warping per i pantaloni. La mappa VERTICALE è un'unica scala
 * lineare vita→caviglia: ancorare il cavallo del capo al cavallo della
 * persona distorce quando in foto le cosce si toccano (la separazione
 * arriva solo al ginocchio). L'ORIZZONTALE si decide riga per riga:
 * - la riga del capo ha UNA corsa → copre il tronco (sopra il cavallo)
 *   o l'unione delle due gambe (sotto);
 * - ha DUE corse → una per gamba, sulle colonne della gamba vera; se le
 *   colonne non ci sono ancora (capo diviso sopra il cavallo della
 *   persona, foto in diagonale) si divide a metà lo span del tronco.
 * Gonna/abito (mai due corse): sempre il primo caso.
 */
export function bottomWarpPlan({
  garmentRows,
  garmentBox,
  legSplit,
  waistY,
  crotchY,
  ankleY,
  trunkSpans,
  legLSpans,
  legRSpans,
}) {
  const plan = [];
  const gh = Math.max(1, garmentBox.bottom - garmentBox.top);
  const dh = Math.max(1, ankleY - waistY);
  const unionSpan = (a, b) =>
    a && b ? { left: Math.min(a.left, b.left), right: Math.max(a.right, b.right) } : a || b;
  const halfSpan = (s, side) => {
    const mid = Math.floor((s.left + s.right) / 2);
    return side === 'L' ? { left: s.left, right: mid } : { left: mid + 1, right: s.right };
  };

  for (let yd = Math.round(waistY); yd <= Math.round(ankleY); yd++) {
    const t = (yd - waistY) / dh;
    const ys = garmentBox.top + Math.round(t * gh);
    const row = garmentRows[ys];
    if (!row) continue;
    const srcL = legSplit ? legSplit.legL[ys] : null;
    const srcR = legSplit ? legSplit.legR[ys] : null;
    if (srcL && srcR && yd > crotchY) {
      // riga fusa (risvolti o cosce che si toccano in foto): metà per gamba,
      // sennò finirebbe stirata come una barra sull'unione delle due gambe
      let a = srcL;
      let b = srcR;
      if (a === b) {
        const mid = Math.round((a[0] + a[1]) / 2);
        b = [mid, a[1]];
        a = [a[0], mid];
      }
      const destL = legLSpans[yd] || (trunkSpans[yd] && halfSpan(trunkSpans[yd], 'L'));
      const destR = legRSpans[yd] || (trunkSpans[yd] && halfSpan(trunkSpans[yd], 'R'));
      const pL = planRow(yd, ys, a, destL);
      const pR = planRow(yd, ys, b, destR);
      if (pL) plan.push(pL);
      if (pR) plan.push(pR);
    } else if (srcL && srcR && srcL !== srcR) {
      // capo già diviso ma siamo ancora sopra il cavallo della persona
      // (foto in diagonale): metà dello span del tronco per parte
      const destL = legLSpans[yd] || (trunkSpans[yd] && halfSpan(trunkSpans[yd], 'L'));
      const destR = legRSpans[yd] || (trunkSpans[yd] && halfSpan(trunkSpans[yd], 'R'));
      const pL = planRow(yd, ys, srcL, destL);
      const pR = planRow(yd, ys, srcR, destR);
      if (pL) plan.push(pL);
      if (pR) plan.push(pR);
    } else {
      const dest =
        yd <= crotchY
          ? trunkSpans[yd]
          : unionSpan(legLSpans[yd], legRSpans[yd]) || trunkSpans[yd];
      const p = planRow(yd, ys, [row.left, row.right + 1], dest);
      if (p) plan.push(p);
    }
  }
  return plan;
}
