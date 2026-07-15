/**
 * Guscio browser per la modalità "Su modello": porta le immagini in canvas e
 * chiama la logica pura (personSilhouette, modelComposer). Qui vivono solo
 * I/O e ritagli; niente geometria.
 *
 * La foto della persona passa dallo stesso scontorno @imgly dei capi e dalla
 * stessa cache IndexedDB, con l'id riservato `__person__`: se la foto di
 * riferimento cambia, la chiave (id+hash foto) cambia e si riscontorna.
 */
import { removeGarmentBackground } from './backgroundRemoval';
import { getCachedCutout, putCachedCutout } from './garmentCutoutCache';
import { alphaBounds, analyzeSilhouette } from './personSilhouette';

const loadImage = (src) =>
  new Promise((resolve, reject) => {
    const img = new Image();
    img.crossOrigin = 'anonymous';
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error('load'));
    img.src = src;
  });

const readImageData = (img) => {
  const canvas = document.createElement('canvas');
  canvas.width = img.naturalWidth;
  canvas.height = img.naturalHeight;
  const ctx = canvas.getContext('2d', { willReadFrequently: true });
  ctx.drawImage(img, 0, 0);
  return ctx.getImageData(0, 0, canvas.width, canvas.height);
};

/** Scontorno della persona, cachato. @returns {Promise<string>} dataURL PNG. */
export async function loadPersonCutout(photo) {
  const pseudoItem = { id: '__person__', photo };
  let url = await getCachedCutout(pseudoItem);
  if (!url) {
    url = await removeGarmentBackground(photo);
    await putCachedCutout(pseudoItem, url);
  }
  return url;
}

/**
 * Landmark del corpo dal PNG scontornato della persona.
 * @returns {Promise<{person:object, width:number, height:number}|null>}
 *          null se nella foto non si distingue una figura.
 */
export async function analyzePersonImage(cutoutUrl) {
  const img = await loadImage(cutoutUrl);
  const person = analyzeSilhouette(readImageData(img));
  if (!person) return null;
  return { person, width: img.naturalWidth, height: img.naturalHeight };
}

/**
 * Ritaglia il PNG scontornato del capo al suo contenuto (il riquadro dei pixel
 * opachi): serve il rapporto larghezza/altezza VERO del capo, senza i margini
 * trasparenti che @imgly lascia attorno (la foto intera meno lo sfondo).
 * @returns {Promise<{url:string, aspect:number}|null>}
 */
export async function trimmedGarment(cutoutUrl) {
  const img = await loadImage(cutoutUrl);
  let imageData;
  try {
    imageData = readImageData(img);
  } catch {
    // dataURL nostro o foto senza CORS: in quest'ultimo caso niente ritaglio,
    // si usa la foto com'è (il chiamante decide).
    return null;
  }
  const b = alphaBounds(imageData);
  if (!b) return null;
  const w = b.right - b.left + 1;
  const h = b.bottom - b.top + 1;
  const out = document.createElement('canvas');
  out.width = w;
  out.height = h;
  out.getContext('2d').drawImage(img, b.left, b.top, w, h, 0, 0, w, h);
  return { url: out.toDataURL('image/png'), aspect: w / h };
}

/** Rapporto larghezza/altezza di un'immagine qualunque (per i ripieghi senza scontorno). */
export async function imageAspect(url) {
  const img = await loadImage(url);
  return img.naturalWidth / img.naturalHeight;
}
