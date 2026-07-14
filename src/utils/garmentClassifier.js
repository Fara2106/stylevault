/**
 * Classificatore del tipo di immagine capo. Puro, nessun DOM: il guscio che
 * decodifica la foto sta in garmentImage.js / AddItemPage.
 */
import { backgroundMask } from './garmentTexture';

/**
 * Numero di componenti connesse (4-vicini) di pixel capo (mask=1) con almeno
 * `minSize` pixel. Le isole piccole sono rumore e non contano. Uno screenshot
 * spezza il "non-sfondo" in tante isole (foto + badge + blocchi di testo);
 * una foto pulita del capo ne ha una sola.
 */
export function countIslands(mask, width, height, { minSize = 12 } = {}) {
  const seen = new Uint8Array(width * height);
  let islands = 0;
  for (let start = 0; start < mask.length; start++) {
    if (!mask[start] || seen[start]) continue;
    let count = 0;
    const stack = [start];
    seen[start] = 1;
    while (stack.length) {
      const p = stack.pop();
      count++;
      const x = p % width;
      const y = (p - x) / width;
      const neigh = [
        x > 0 ? p - 1 : -1,
        x < width - 1 ? p + 1 : -1,
        y > 0 ? p - width : -1,
        y < height - 1 ? p + width : -1,
      ];
      for (const n of neigh) {
        if (n < 0 || seen[n] || !mask[n]) continue;
        seen[n] = 1;
        stack.push(n);
      }
    }
    if (count >= minSize) islands++;
  }
  return islands;
}
