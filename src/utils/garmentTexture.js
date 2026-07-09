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
    };
  }
  return {
    ok: true,
    bounds: garmentBounds(mask, width, height),
    dominantHex: dominantColor(image, mask),
    coverage,
    mask,
  };
}
