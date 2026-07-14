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

const luminance = (data, i) =>
  0.299 * data[i] + 0.587 * data[i + 1] + 0.114 * data[i + 2];

/**
 * Frazione di transizioni ad alto contrasto sulle scanline orizzontali: per ogni
 * coppia di pixel adiacenti sulla riga, conta quando il salto di luminanza supera
 * `contrast`. Il testo produce moltissimi salti chiaro/scuro; una foto no.
 */
export function textDensity({ data, width, height }, { contrast = 60 } = {}) {
  let flips = 0;
  let pairs = 0;
  for (let y = 0; y < height; y++) {
    let prev = luminance(data, (y * width) * 4);
    for (let x = 1; x < width; x++) {
      const i = (y * width + x) * 4;
      const lum = luminance(data, i);
      if (Math.abs(lum - prev) > contrast) flips++;
      pairs++;
      prev = lum;
    }
  }
  return pairs === 0 ? 0 : flips / pairs;
}

/**
 * Soglie tarate su immagini VERE (2026-07-14): screenshot dell'app vs foto di capi
 * reali. Scoperta: il TESTO non separa (una maglietta liscia ha densità di testo
 * maggiore di uno screenshot poco testuale). Separano invece nettissimo le ISOLE
 * di contenuto (capi reali 1–9, screenshot 52–145) e lo SFONDO uniforme (screenshot
 * 0.84–0.95 perché pieni di chrome dell'app; un capo riempie il frame, sfondo basso).
 * Quindi: screenshot = TANTE isole E MOLTO sfondo. Il testo resta solo diagnostico.
 */
export const ISLAND_SCREENSHOT = 24; // ben sopra il max dei capi (9), sotto il min screenshot (52)
export const REACH_SCREENSHOT = 0.4; // uno screenshot ha molto sfondo uniforme
export const REACH_CLEAN = 0.45;     // sfondo che copre buona parte del frame

/**
 * Verdetto sul tipo di immagine capo. Conservativo: 'screenshot' solo quando la
 * scena è frammentata in molte isole E c'è molto sfondo uniforme — così un capo
 * vero (un solo oggetto che riempie il frame) non viene mai scambiato per uno
 * screenshot e bloccato a torto, nemmeno se ha una fantasia molto "testurata".
 */
export function classifyGarmentImage(image, opts = {}) {
  const { width, height } = image;
  const mask = backgroundMask(image, opts);
  let bg = 0;
  for (let p = 0; p < mask.length; p++) if (!mask[p]) bg++;
  const reach = bg / (width * height);
  const islands = countIslands(mask, width, height);
  const text = textDensity(image, opts); // solo diagnostico, non entra nel verdetto

  let verdict;
  if (islands >= ISLAND_SCREENSHOT && reach >= REACH_SCREENSHOT) verdict = 'screenshot';
  else if (reach >= REACH_CLEAN && islands <= 1) verdict = 'clean';
  else verdict = 'messy';

  return { verdict, islands, text, reach };
}
