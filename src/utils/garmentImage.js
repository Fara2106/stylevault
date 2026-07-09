/**
 * Guscio browser attorno a garmentTexture.js: porta la foto in un canvas,
 * chiama la logica pura, restituisce un PNG ritagliato con sfondo trasparente.
 *
 * Le foto dei capi aggiunti da link stanno su domini esterni: leggerne i pixel
 * fa scattare la protezione CORS del browser e il canvas diventa illeggibile.
 * In quel caso si ripiega sulla tinta unita, come già fa il try-on Gemini.
 */
import { extractGarment } from './garmentTexture';
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

/**
 * Ritaglia `bounds` e rende trasparenti i pixel di sfondo.
 * `mask` arriva già calcolata da extractGarment: ricalcolarla qui vorrebbe dire
 * ripetere il riempimento su tutta l'immagine per ogni capo.
 */
const cutout = (imageData, mask, bounds) => {
  const { data } = imageData;
  for (let p = 0; p < mask.length; p++) {
    if (!mask[p]) data[p * 4 + 3] = 0;
  }
  const full = document.createElement('canvas');
  full.width = imageData.width;
  full.height = imageData.height;
  full.getContext('2d').putImageData(imageData, 0, 0);

  const out = document.createElement('canvas');
  out.width = bounds.width;
  out.height = bounds.height;
  out
    .getContext('2d')
    .drawImage(
      full,
      bounds.x,
      bounds.y,
      bounds.width,
      bounds.height,
      0,
      0,
      bounds.width,
      bounds.height
    );
  return out.toDataURL('image/png');
};

export async function loadGarmentTexture(item) {
  const flat = (reason) => ({
    textureUrl: null,
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

  const result = extractGarment(imageData);
  if (!result.ok) {
    return { textureUrl: null, colorHex: result.dominantHex, kind: 'flat', reason: 'degraded' };
  }

  return {
    textureUrl: cutout(imageData, result.mask, result.bounds),
    colorHex: result.dominantHex,
    kind: 'texture',
    reason: null,
  };
}
