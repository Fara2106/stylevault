/**
 * Estrazione del capo dalla sua foto: sfondo via, rettangolo del capo, colore
 * dominante. Tutto puro e senza DOM, così è testabile in Vitest (ambiente node).
 * Il guscio che tocca il canvas sta in garmentImage.js.
 */

/** Distanza di Chebyshev fra due colori RGB: massimo scarto su un canale. */
const colorDistance = (data, i, r, g, b) =>
  Math.max(
    Math.abs(data[i] - r),
    Math.abs(data[i + 1] - g),
    Math.abs(data[i + 2] - b)
  );

export const BG_TOLERANCE = 32;

/**
 * Riempimento dai quattro angoli: un pixel è sfondo se è raggiungibile da un
 * angolo attraverso pixel cromaticamente vicini a quell'angolo. Una zona del
 * colore dello sfondo ma circondata dal capo resta capo, perché non è raggiungibile.
 *
 * @returns {Uint8Array} 1 = capo, 0 = sfondo
 */
export function backgroundMask({ data, width, height }, { tolerance = BG_TOLERANCE } = {}) {
  const isBackground = new Uint8Array(width * height);
  const queue = [];

  const corners = [
    [0, 0],
    [width - 1, 0],
    [0, height - 1],
    [width - 1, height - 1],
  ];

  for (const [cx, cy] of corners) {
    const p = cy * width + cx;
    if (isBackground[p]) continue;
    const i = p * 4;
    const [r, g, b] = [data[i], data[i + 1], data[i + 2]];
    isBackground[p] = 1;
    queue.push(p);

    while (queue.length) {
      const cur = queue.pop();
      const x = cur % width;
      const y = (cur - x) / width;
      const neighbours = [
        x > 0 ? cur - 1 : -1,
        x < width - 1 ? cur + 1 : -1,
        y > 0 ? cur - width : -1,
        y < height - 1 ? cur + width : -1,
      ];
      for (const n of neighbours) {
        if (n < 0 || isBackground[n]) continue;
        if (colorDistance(data, n * 4, r, g, b) <= tolerance) {
          isBackground[n] = 1;
          queue.push(n);
        }
      }
    }
  }

  const mask = new Uint8Array(width * height);
  for (let p = 0; p < mask.length; p++) mask[p] = isBackground[p] ? 0 : 1;
  return mask;
}

/** Rettangolo minimo che contiene i pixel del capo. */
export function garmentBounds(mask, width, height) {
  let minX = width;
  let minY = height;
  let maxX = -1;
  let maxY = -1;

  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      if (!mask[y * width + x]) continue;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }
  if (maxX < 0) return null;
  return { x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1 };
}

const toHex = (n) => Math.round(n).toString(16).padStart(2, '0');

/**
 * Colore dominante per istogramma quantizzato: si raggruppano i pixel in bucket
 * da 4 bit per canale, si prende il bucket più popolato e si media sui suoi
 * pixel reali. Deterministico — a differenza di un k-means con centroidi casuali.
 */
export function dominantColor({ data, width, height }, mask) {
  const counts = new Map();
  for (let p = 0; p < width * height; p++) {
    if (mask && !mask[p]) continue;
    const i = p * 4;
    const key =
      ((data[i] >> 4) << 8) | ((data[i + 1] >> 4) << 4) | (data[i + 2] >> 4);
    counts.set(key, (counts.get(key) || 0) + 1);
  }
  if (counts.size === 0) return '#000000';

  let best = null;
  let bestCount = -1;
  for (const [key, count] of counts) {
    if (count > bestCount) {
      best = key;
      bestCount = count;
    }
  }

  let r = 0;
  let g = 0;
  let b = 0;
  let n = 0;
  for (let p = 0; p < width * height; p++) {
    if (mask && !mask[p]) continue;
    const i = p * 4;
    const key =
      ((data[i] >> 4) << 8) | ((data[i + 1] >> 4) << 4) | (data[i + 2] >> 4);
    if (key !== best) continue;
    r += data[i];
    g += data[i + 1];
    b += data[i + 2];
    n++;
  }
  return `#${toHex(r / n)}${toHex(g / n)}${toHex(b / n)}`;
}

/** Soglie oltre le quali non ci si fida della maschera. */
const MAX_COVERAGE = 0.92;
const MIN_COVERAGE = 0.02;

/** Vero se il quadrato di lato `side` con angolo (x,y) è tutto dentro il capo. */
const squareInside = (mask, width, x, y, side) => {
  for (let yy = y; yy < y + side; yy++) {
    for (let xx = x; xx < x + side; xx++) {
      if (!mask[yy * width + xx]) return false;
    }
  }
  return true;
};

/**
 * Quadrato tutto interno al capo, da usare come piastrella di tessuto ripetuta.
 * Si parte dal baricentro della maschera e si rimpicciolisce finché ogni pixel
 * del quadrato appartiene al capo: così non entrano mai bordi, cuciture del
 * disegno o sfondo.
 * @returns {{x,y,width,height}|null} null se non c'è spazio (capo troppo sottile)
 */
export function fabricSwatch(mask, width, height, bounds) {
  if (!bounds) return null;
  // baricentro dei pixel del capo: sta nel pieno del tessuto, non sui bordi
  let sx = 0;
  let sy = 0;
  let n = 0;
  for (let y = bounds.y; y < bounds.y + bounds.height; y++) {
    for (let x = bounds.x; x < bounds.x + bounds.width; x++) {
      if (!mask[y * width + x]) continue;
      sx += x;
      sy += y;
      n++;
    }
  }
  if (!n) return null;
  const cx = Math.round(sx / n);
  const cy = Math.round(sy / n);

  const maxSide = Math.min(bounds.width, bounds.height);
  for (let side = maxSide; side >= 2; side--) {
    const x = Math.max(0, Math.min(width - side, cx - (side >> 1)));
    const y = Math.max(0, Math.min(height - side, cy - (side >> 1)));
    if (squareInside(mask, width, x, y, side)) {
      return { x, y, width: side, height: side };
    }
  }
  return null;
}

const hexToRgb = (hex) => [
  parseInt(hex.slice(1, 3), 16),
  parseInt(hex.slice(3, 5), 16),
  parseInt(hex.slice(5, 7), 16),
];

/** Vero se il pixel `p` tocca lo sfondo: sta sul bordo del capo. */
const onGarmentEdge = (mask, width, height, p) => {
  const x = p % width;
  const y = (p - x) / width;
  if (x === 0 || y === 0 || x === width - 1 || y === height - 1) return true;
  return (
    !mask[p - 1] || !mask[p + 1] || !mask[p - width] || !mask[p + width]
  );
};

const PRINT_MIN_AREA = 0.005;
const PRINT_MAX_AREA = 0.25;

/**
 * Zona di stampa: pixel interni al capo il cui colore dista dal dominante più
 * di `minDistance` (Chebyshev). Si restituisce il loro rettangolo solo se è una
 * stampa plausibile: fra lo 0.5% e il 25% dell'area del capo, e non attaccata al
 * bordo del capo (quello sarebbe un'ombra o un orlo, non una stampa).
 * @returns {{x,y,width,height}|null}
 */
export function printRegion(image, mask, dominantHex, { minDistance = 60 } = {}) {
  const { data, width, height } = image;
  const [dr, dg, db] = hexToRgb(dominantHex);

  let minX = width;
  let minY = height;
  let maxX = -1;
  let maxY = -1;
  let printPixels = 0;
  let garmentPixels = 0;

  for (let p = 0; p < mask.length; p++) {
    if (!mask[p]) continue;
    garmentPixels++;
    const i = p * 4;
    if (colorDistance(data, i, dr, dg, db) <= minDistance) continue;
    // Una zona attaccata al bordo del capo è un orlo, un'ombra, una cucitura:
    // non è una stampa. Se ne trovo anche solo un pixel, rinuncio.
    if (onGarmentEdge(mask, width, height, p)) return null;
    printPixels++;
    const x = p % width;
    const y = (p - x) / width;
    if (x < minX) minX = x;
    if (x > maxX) maxX = x;
    if (y < minY) minY = y;
    if (y > maxY) maxY = y;
  }

  if (!garmentPixels || maxX < 0) return null;
  const share = printPixels / garmentPixels;
  if (share < PRINT_MIN_AREA || share > PRINT_MAX_AREA) return null;

  return { x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1 };
}

/**
 * Dove sta la stampa dentro il capo, in frazioni da 0 a 1 del rettangolo del capo.
 * Serve a rimetterla sulla mesh **nello stesso punto in cui stava sul capo vero**:
 * un logo sul taschino resta sul taschino, non finisce in mezzo al petto.
 *
 * `cx`: 0 = bordo sinistro del capo, 0.5 = centro, 1 = bordo destro.
 * `cy`: 0 = orlo alto (spalle), 1 = orlo basso.
 * `w`, `h`: quanto è larga e alta la stampa, sempre in frazioni del capo.
 *
 * @returns {{cx:number, cy:number, w:number, h:number}|null}
 */
export function printPlacement(bounds, print) {
  if (!bounds || !print) return null;
  return {
    cx: (print.x + print.width / 2 - bounds.x) / bounds.width,
    cy: (print.y + print.height / 2 - bounds.y) / bounds.height,
    w: print.width / bounds.width,
    h: print.height / bounds.height,
  };
}

/**
 * Da foto a capo utilizzabile. `ok: false` significa: niente texture, vesti il
 * capo di tinta unita col colore dominante. Brutto no, sbagliato mai.
 */
export function extractGarment(image, opts) {
  const { width, height } = image;
  const mask = backgroundMask(image, opts);
  let garmentPixels = 0;
  for (let p = 0; p < mask.length; p++) garmentPixels += mask[p];
  const coverage = garmentPixels / (width * height);

  if (coverage > MAX_COVERAGE || coverage < MIN_COVERAGE) {
    return {
      ok: false,
      bounds: null,
      dominantHex: dominantColor(image, null),
      coverage,
      mask,
      swatch: null,
      print: null,
      printAt: null,
    };
  }
  const dominantHex = dominantColor(image, mask);
  const bounds = garmentBounds(mask, width, height);
  const print = printRegion(image, mask, dominantHex);
  return {
    ok: true,
    bounds,
    dominantHex,
    coverage,
    mask,
    swatch: fabricSwatch(mask, width, height, bounds),
    print,
    printAt: printPlacement(bounds, print),
  };
}
