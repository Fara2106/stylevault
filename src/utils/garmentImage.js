/**
 * Guscio browser attorno a garmentTexture.js: porta la foto in un canvas,
 * chiama la logica pura, restituisce un PNG ritagliato con sfondo trasparente.
 *
 * Le foto dei capi aggiunti da link stanno su domini esterni: leggerne i pixel
 * fa scattare la protezione CORS del browser e il canvas diventa illeggibile.
 * In quel caso si ripiega sulla tinta unita, come già fa il try-on Gemini.
 */
import { extractGarment } from './garmentTexture';
import { classifyGarmentImage } from './garmentClassifier';
import { getCachedCutout, putCachedCutout } from './garmentCutoutCache';
import { removeGarmentBackground } from './backgroundRemoval';
import { CLOTHING_COLORS } from './categories';

const FALLBACK_HEX = '#cfc7bb';

/** Colore di ripiego dai colori dichiarati del capo (sempre presenti nel DB). */
export const garmentFallbackHex = (item) =>
  CLOTHING_COLORS.find((c) => c.id === item?.colors?.[0])?.hex || FALLBACK_HEX;

const loadImage = (src) =>
  new Promise((resolve, reject) => {
    const img = new Image();
    img.crossOrigin = 'anonymous';
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error('load'));
    img.src = src;
  });

/** Canvas pieno con tutto `imageData` disegnato, da cui poi si ritaglia un rettangolo. */
const toCanvas = (imageData) => {
  const canvas = document.createElement('canvas');
  canvas.width = imageData.width;
  canvas.height = imageData.height;
  canvas.getContext('2d').putImageData(imageData, 0, 0);
  return canvas;
};

/**
 * Ritaglia `rect` da `imageData` così com'è, senza toccare l'alpha: serve per la
 * piastrella di tessuto, che va usata così com'è (un ritaglio di tessuto pieno,
 * niente sfondo da togliere). Non deve girare dopo `cutout`, che azzera l'alpha
 * sull'`imageData` condiviso: per questo va chiamata prima.
 */
const cropToDataUrl = (imageData, rect) => {
  const out = document.createElement('canvas');
  out.width = rect.width;
  out.height = rect.height;
  out
    .getContext('2d')
    .drawImage(
      toCanvas(imageData),
      rect.x,
      rect.y,
      rect.width,
      rect.height,
      0,
      0,
      rect.width,
      rect.height
    );
  return out.toDataURL('image/png');
};

/**
 * Ritaglia `bounds` e rende trasparenti i pixel di sfondo, **modificando
 * `imageData` sul posto** (azzera l'alpha dei pixel fuori maschera prima di
 * disegnare sul canvas). Va bene solo per il capo intero: deve essere l'ultima
 * a leggere `imageData`, dopo piastrella e stampa, altrimenti quelle due
 * ritaglierebbero un'immagine già bucata di trasparenza al posto dello sfondo.
 */
const cutout = (imageData, mask, bounds) => {
  const { data } = imageData;
  for (let p = 0; p < mask.length; p++) {
    if (!mask[p]) data[p * 4 + 3] = 0;
  }
  return cropToDataUrl(imageData, bounds);
};

/**
 * Ritaglia il rettangolo `print` e rende trasparenti i pixel che non fanno
 * parte della stampa: quelli entro `PRINT_MIN_DISTANCE` dal colore dominante
 * sono tessuto di fondo, non il logo. Stessa soglia e stessa metrica
 * (Chebyshev) di `printRegion` in garmentTexture.js, per restare coerenti con
 * la zona già individuata là. Anche questa legge `imageData` non ancora
 * toccato da `cutout`, quindi va chiamata prima di quella.
 */
const PRINT_MIN_DISTANCE = 60;

const printToDataUrl = (imageData, print, dominantHex) => {
  const [dr, dg, db] = [
    parseInt(dominantHex.slice(1, 3), 16),
    parseInt(dominantHex.slice(3, 5), 16),
    parseInt(dominantHex.slice(5, 7), 16),
  ];

  const out = document.createElement('canvas');
  out.width = print.width;
  out.height = print.height;
  const ctx = out.getContext('2d');
  ctx.drawImage(
    toCanvas(imageData),
    print.x,
    print.y,
    print.width,
    print.height,
    0,
    0,
    print.width,
    print.height
  );

  const cropped = ctx.getImageData(0, 0, print.width, print.height);
  const { data } = cropped;
  for (let p = 0; p < print.width * print.height; p++) {
    const i = p * 4;
    const dist = Math.max(
      Math.abs(data[i] - dr),
      Math.abs(data[i + 1] - dg),
      Math.abs(data[i + 2] - db)
    );
    if (dist <= PRINT_MIN_DISTANCE) data[i + 3] = 0;
  }
  ctx.putImageData(cropped, 0, 0);
  return out.toDataURL('image/png');
};

/**
 * @typedef {Object} GarmentTexture
 * @property {string|null} textureUrl PNG del capo intero scontornato (modalità piatta)
 * @property {string|null} swatchUrl  PNG della piastrella di tessuto, da ripetere sulla mesh
 * @property {string|null} printUrl   PNG della sola stampa, sfondo trasparente
 * @property {{cx:number,cy:number,w:number,h:number}|null} printAt posizione della stampa sul capo, in frazioni
 * @property {string} colorHex
 * @property {'texture'|'flat'} kind
 * @property {string|null} reason
 */

/** @returns {Promise<GarmentTexture>} */
export async function loadGarmentTexture(item) {
  const flat = (reason) => ({
    textureUrl: null,
    swatchUrl: null,
    printUrl: null,
    printAt: null,
    colorHex: garmentFallbackHex(item),
    kind: 'flat',
    reason,
  });

  if (!item?.photo) return flat('no-photo');

  let img;
  try {
    img = await loadImage(item.photo);
  } catch {
    return flat('cors');
  }

  const canvas = document.createElement('canvas');
  canvas.width = img.naturalWidth;
  canvas.height = img.naturalHeight;
  const ctx = canvas.getContext('2d', { willReadFrequently: true });
  ctx.drawImage(img, 0, 0);

  let imageData;
  try {
    imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
  } catch {
    // canvas "sporcato" da un'immagine cross-origin senza header CORS
    return flat('cors');
  }

  // Rete di sicurezza per i capi già in guardaroba: se la foto è uno screenshot
  // (collage con UI), lo scontorno geometrico incollerebbe l'intera schermata
  // sul manichino. Meglio la sagoma in tinta unita. I capi NUOVI vengono già
  // bloccati all'aggiunta (AddItemPage); questo copre il backlog.
  if (classifyGarmentImage(imageData).verdict === 'screenshot') {
    return {
      textureUrl: null,
      swatchUrl: null,
      printUrl: null,
      printAt: null,
      colorHex: garmentFallbackHex(item),
      kind: 'flat',
      reason: 'screenshot',
    };
  }

  const result = extractGarment(imageData);

  // Piastrella e stampa (servono al 3D) si leggono da `imageData` PRIMA di qualunque
  // `cutout`, che azzera l'alpha dello sfondo: se giro l'ordine, ritaglierebbero un
  // tessuto già bucato. Nulli se il geometrico degrada (il 3D ripiega a tinta unita).
  const swatchUrl = result.ok && result.swatch ? cropToDataUrl(imageData, result.swatch) : null;
  const printUrl =
    result.ok && result.print ? printToDataUrl(imageData, result.print, result.dominantHex) : null;

  // textureUrl (modalità piatta): scontorno ML on-device, cachato. Vale per TUTTE le
  // foto non-screenshot, ANCHE quando il geometrico degrada (una foto che riempie il
  // frame): è proprio lì che @imgly serve di più. Miss → @imgly → salva in cache. Se
  // @imgly fallisce, ripiego sul ritaglio geometrico (solo se il geometrico è valido).
  let textureUrl = await getCachedCutout(item);
  if (!textureUrl) {
    try {
      textureUrl = await removeGarmentBackground(item.photo);
      await putCachedCutout(item, textureUrl);
    } catch {
      textureUrl = result.ok ? cutout(imageData, result.mask, result.bounds) : null;
    }
  }

  return {
    textureUrl,
    swatchUrl,
    printUrl,
    printAt: result.ok ? result.printAt : null,
    colorHex: result.dominantHex,
    kind: textureUrl ? 'texture' : 'flat',
    reason: textureUrl ? null : 'degraded',
  };
}
