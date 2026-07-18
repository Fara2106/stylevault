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

async function eyesColor(img, imageData) {
  try {
    const lm = await getFaceLandmarker();
    const result = lm.detect(img);
    const points = result.faceLandmarks?.[0];
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

export async function analyzeFaceColors(photoUrl) {
  try {
    const [seg, img] = await Promise.all([segmentBody(photoUrl), loadImage(photoUrl)]);
    let skin = null;
    let hair = null;
    let skinCount = 0;
    if (seg) {
      const maskData = imageDataOf(img, seg.width, seg.height);
      const skinPx = maskedPixels(maskData, seg.categories, [SEG_FACE_SKIN]);
      const hairPx = maskedPixels(maskData, seg.categories, [SEG_HAIR]);
      skinCount = skinPx.length;
      if (skinPx.length >= MIN_REGION_PIXELS) skin = representativeColor(skinPx);
      if (hairPx.length >= MIN_REGION_PIXELS) hair = representativeColor(hairPx);
    }
    // occhi alla risoluzione naturale (l'iride è piccola)
    const fullData = imageDataOf(img, img.naturalWidth, img.naturalHeight);
    const eyes = await eyesColor(img, fullData);

    if (!skin && !hair && !eyes) return null;
    const parts = [skin, hair, eyes].filter(Boolean).length;
    const confidence =
      Math.round(((parts / 3) * 0.7 + Math.min(1, skinCount / 2000) * 0.3) * 100) / 100;
    return { skin, hair, eyes, confidence };
  } catch {
    return null;
  }
}
