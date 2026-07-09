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
