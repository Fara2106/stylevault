/**
 * Estrazione dei colori personali dalla foto, tutto on-device:
 * - pelle del viso e capelli: maschera del segmentatore selfie multiclass
 *   (riuso di segmentBody, già in bodyAnalysis.js) + colore rappresentativo;
 * - occhi: FaceLandmarker (stesso pacchetto MediaPipe, lazy) → centro iride
 *   → campiona un disco; il taglio del 35% esclude pupilla e riflessi.
 * Ogni pezzo che fallisce diventa null; se cade tutto → null totale:
 * la UI parte dalla correzione manuale.
 */
import { segmentBody, SEG_FACE_SKIN, SEG_HAIR } from './bodyAnalysis';
import { representativeColor, maskedPixels } from './colorSampling';

const VISION_VERSION = '0.10.35';
const WASM_URL = `https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@${VISION_VERSION}/wasm`;
const FACE_MODEL_URL =
  'https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/latest/face_landmarker.task';

// Landmark MediaPipe dell'iride (modello a 478 punti):
// 468 centro iride sinistra, 469-472 anello; 473 centro destra, 474-477 anello.
const IRIS = [
  { center: 468, ring: [469, 470, 471, 472] },
  { center: 473, ring: [474, 475, 476, 477] },
];

const MIN_REGION_PIXELS = 150;

let landmarkerPromise = null;
const getFaceLandmarker = () => {
  if (!landmarkerPromise) {
    landmarkerPromise = import('@mediapipe/tasks-vision').then(async (mp) => {
      const fileset = await mp.FilesetResolver.forVisionTasks(WASM_URL);
      return mp.FaceLandmarker.createFromOptions(fileset, {
        baseOptions: { modelAssetPath: FACE_MODEL_URL },
        runningMode: 'IMAGE',
        numFaces: 1,
      });
    });
  }
  return landmarkerPromise;
};

const loadImage = (src) =>
  new Promise((resolve, reject) => {
    const img = new Image();
    img.crossOrigin = 'anonymous';
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error('load'));
    img.src = src;
  });

const imageDataOf = (img, w, h) => {
  const canvas = document.createElement('canvas');
  canvas.width = w;
  canvas.height = h;
  const ctx = canvas.getContext('2d', { willReadFrequently: true });
  ctx.drawImage(img, 0, 0, w, h);
  return ctx.getImageData(0, 0, w, h);
};

/** Pixel in un disco attorno a (cx,cy) — coordinate già in pixel immagine. */
const discPixels = (imageData, cx, cy, radius) => {
  const out = [];
  const r2 = radius * radius;
  const { width, height, data } = imageData;
  for (let y = Math.max(0, Math.floor(cy - radius)); y <= Math.min(height - 1, Math.ceil(cy + radius)); y++) {
    for (let x = Math.max(0, Math.floor(cx - radius)); x <= Math.min(width - 1, Math.ceil(cx + radius)); x++) {
      if ((x - cx) ** 2 + (y - cy) ** 2 <= r2) {
        const o = (y * width + x) * 4;
        out.push({ r: data[o], g: data[o + 1], b: data[o + 2] });
      }
    }
  }
  return out;
};

/** Landmark del volto (478 punti, iridi incluse) o null. */
async function detectFacePoints(img) {
  try {
    const lm = await getFaceLandmarker();
    const result = lm.detect(img);
    return result.faceLandmarks?.[0] || null;
  } catch {
    return null;
  }
}

/**
 * Riquadro del MEZZOBUSTO attorno al volto, in pixel immagine: il
 * segmentatore selfie è addestrato su mezzibusti a 256px — su una foto a
 * figura intera il viso è una manciata di pixel del suo input e pelle/capelli
 * si perdono. Margini larghi: sopra 1.1×viso (i capelli), lati 0.7, sotto 0.5.
 */
function faceCropBox(points, width, height) {
  let minX = 1, maxX = 0, minY = 1, maxY = 0;
  for (const p of points) {
    if (p.x < minX) minX = p.x;
    if (p.x > maxX) maxX = p.x;
    if (p.y < minY) minY = p.y;
    if (p.y > maxY) maxY = p.y;
  }
  const fw = (maxX - minX) * width;
  const fh = (maxY - minY) * height;
  const x0 = Math.max(0, Math.round(minX * width - 0.7 * fw));
  const y0 = Math.max(0, Math.round(minY * height - 1.1 * fh));
  const x1 = Math.min(width, Math.round(maxX * width + 0.7 * fw));
  const y1 = Math.min(height, Math.round(maxY * height + 0.5 * fh));
  const w = x1 - x0;
  const h = y1 - y0;
  return w > 8 && h > 8 ? { x: x0, y: y0, w, h } : null;
}

/** Ritaglio come dataURL, riscalato perché il lato lungo sia ~TARGET px. */
const CROP_TARGET = 720;
function cropDataUrl(img, box) {
  const scale = Math.min(2.5, CROP_TARGET / Math.max(box.w, box.h));
  const canvas = document.createElement('canvas');
  canvas.width = Math.round(box.w * scale);
  canvas.height = Math.round(box.h * scale);
  const ctx = canvas.getContext('2d');
  ctx.drawImage(img, box.x, box.y, box.w, box.h, 0, 0, canvas.width, canvas.height);
  return canvas.toDataURL('image/jpeg', 0.92);
}

function eyesColor(points, imageData) {
  try {
    if (!points) return null;
    const pixels = [];
    for (const { center, ring } of IRIS) {
      const c = points[center];
      if (!c) continue;
      const cx = c.x * imageData.width;
      const cy = c.y * imageData.height;
      const radius =
        (ring.reduce((t, i) => {
          const p = points[i];
          return t + Math.hypot(p.x * imageData.width - cx, p.y * imageData.height - cy);
        }, 0) / ring.length) * 0.7;
      if (radius < 1.5) continue; // iride troppo piccola per campionare
      pixels.push(...discPixels(imageData, cx, cy, radius));
    }
    if (pixels.length < 12) return null;
    return representativeColor(pixels, { trim: 0.35 }); // via pupilla e riflessi
  } catch {
    return null;
  }
}

/** Pelle/capelli via segmentazione dell'immagine indicata. */
async function skinAndHair(sourceUrl, sourceImg) {
  const seg = await segmentBody(sourceUrl);
  if (!seg) return { skin: null, hair: null, skinCount: 0 };
  const maskData = imageDataOf(sourceImg, seg.width, seg.height);
  const skinPx = maskedPixels(maskData, seg.categories, [SEG_FACE_SKIN]);
  const hairPx = maskedPixels(maskData, seg.categories, [SEG_HAIR]);
  return {
    skin: skinPx.length >= MIN_REGION_PIXELS ? representativeColor(skinPx) : null,
    hair: hairPx.length >= MIN_REGION_PIXELS ? representativeColor(hairPx) : null,
    skinCount: skinPx.length,
  };
}

export async function analyzeFaceColors(photoUrl) {
  try {
    const img = await loadImage(photoUrl);
    const points = await detectFacePoints(img);

    // Mezzobusto ritagliato quando il volto si trova: al segmentatore selfie
    // arriva un input nel suo dominio. Senza volto (o ritaglio degenere) si
    // resta sull'immagine intera, come prima.
    let result = { skin: null, hair: null, skinCount: 0 };
    const box = points ? faceCropBox(points, img.naturalWidth, img.naturalHeight) : null;
    if (box) {
      const cropUrl = cropDataUrl(img, box);
      result = await skinAndHair(cropUrl, await loadImage(cropUrl));
    }
    if (!result.skin && !result.hair) {
      result = await skinAndHair(photoUrl, img);
    }

    // occhi alla risoluzione naturale (l'iride è piccola)
    const fullData = imageDataOf(img, img.naturalWidth, img.naturalHeight);
    const eyes = eyesColor(points, fullData);

    const { skin, hair, skinCount } = result;
    if (!skin && !hair && !eyes) return null;
    const parts = [skin, hair, eyes].filter(Boolean).length;
    const confidence =
      Math.round(((parts / 3) * 0.7 + Math.min(1, skinCount / 2000) * 0.3) * 100) / 100;
    return { skin, hair, eyes, confidence };
  } catch {
    return null;
  }
}
