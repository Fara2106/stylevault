/**
 * Analisi del corpo con MediaPipe Tasks Vision, tutto on-device:
 * - ImageSegmenter (selfie multiclass): distingue capelli/pelle/VESTITI —
 *   serve a sapere DOVE stanno i vestiti che la persona indossa in foto;
 * - PoseLandmarker (lite): i punti del corpo (spalle, gomiti, fianchi,
 *   ginocchia, caviglie) — servono ad ancorare e deformare i capi.
 *
 * Come per @imgly: il codice WASM arriva da CDN (jsdelivr, versione pinnata)
 * e i modelli dal CDN di MediaPipe, SOLO come download di file. L'immagine
 * non lascia mai il dispositivo: l'elaborazione è locale.
 *
 * Import dinamico: niente nel bundle iniziale; primo uso ~20MB di download
 * (poi cache HTTP del browser). Ogni funzione ritorna null se qualcosa va
 * storto: il chiamante deve degradare con grazia alla pipeline senza ML.
 */

import { fetchModel } from './modelDownload';

const VISION_VERSION = '0.10.35';
const WASM_URL = `https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@${VISION_VERSION}/wasm`;
const SEGMENTER_MODEL_URL =
  'https://storage.googleapis.com/mediapipe-models/image_segmenter/selfie_multiclass_256x256/float32/latest/selfie_multiclass_256x256.tflite';
const POSE_MODEL_URL =
  'https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/latest/pose_landmarker_lite.task';

/** Classi del segmentatore selfie multiclass. */
export const SEG_BACKGROUND = 0;
export const SEG_HAIR = 1;
export const SEG_BODY_SKIN = 2;
export const SEG_FACE_SKIN = 3;
export const SEG_CLOTHES = 4;
export const SEG_ACCESSORIES = 5;

/**
 * Crea un task MediaPipe sulla GPU del telefono (WebGL2: su iPhone è molto
 * più veloce della CPU); se il browser non la concede si ripiega sulla CPU.
 * Le maschere restano leggibili con getAsUint8Array() in entrambi i casi.
 */
export async function createVisionTask(Task, fileset, options) {
  const withDelegate = (delegate) => ({
    ...options,
    baseOptions: { ...options.baseOptions, delegate },
  });
  try {
    return await Task.createFromOptions(fileset, withDelegate('GPU'));
  } catch {
    return Task.createFromOptions(fileset, withDelegate('CPU'));
  }
}

/**
 * Dimensioni attese dei file (decompressi) per la barra del primo uso.
 * Il motore WASM arriva compresso (~3 MB in rete) ma si legge decompresso.
 */
export const MODEL_FILES = {
  wasm: { key: 'vision-wasm', bytes: 11153617 },
  segmenter: { key: 'selfie-multiclass', bytes: 16371837 },
  pose: { key: 'pose-lite', bytes: 5777746 },
};

let visionPromise = null;
/** MediaPipe e il suo motore WASM, scaricato una volta con l'avanzamento. */
export const getVision = () => {
  if (!visionPromise) {
    visionPromise = import('@mediapipe/tasks-vision')
      .then(async (mp) => {
        const fileset = await mp.FilesetResolver.forVisionTasks(WASM_URL);
        const { key, bytes } = MODEL_FILES.wasm;
        const wasm = await fetchModel(key, fileset.wasmBinaryPath, bytes);
        const blob = new Blob([wasm], { type: 'application/wasm' });
        return { mp, fileset: { ...fileset, wasmBinaryPath: URL.createObjectURL(blob) } };
      })
      .catch((error) => {
        visionPromise = null; // rete caduta: al prossimo tentativo si riprova
        throw error;
      });
  }
  return visionPromise;
};

const modelBuffer = (file, url) => fetchModel(file.key, url, file.bytes);

let segmenterPromise = null;
const getSegmenter = () => {
  if (!segmenterPromise) {
    segmenterPromise = getVision().then(async ({ mp, fileset }) =>
      createVisionTask(mp.ImageSegmenter, fileset, {
        baseOptions: {
          modelAssetBuffer: await modelBuffer(MODEL_FILES.segmenter, SEGMENTER_MODEL_URL),
        },
        runningMode: 'IMAGE',
        outputCategoryMask: true,
        outputConfidenceMasks: false,
      })
    ).catch((error) => {
      segmenterPromise = null; // rete caduta: al prossimo tentativo si riprova
      throw error;
    });
  }
  return segmenterPromise;
};

let posePromise = null;
const getPose = () => {
  if (!posePromise) {
    posePromise = getVision().then(async ({ mp, fileset }) =>
      createVisionTask(mp.PoseLandmarker, fileset, {
        baseOptions: { modelAssetBuffer: await modelBuffer(MODEL_FILES.pose, POSE_MODEL_URL) },
        runningMode: 'IMAGE',
        numPoses: 1,
      })
    ).catch((error) => {
      posePromise = null; // rete caduta: al prossimo tentativo si riprova
      throw error;
    });
  }
  return posePromise;
};

const loadImage = (src) =>
  new Promise((resolve, reject) => {
    const img = new Image();
    img.crossOrigin = 'anonymous';
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error('load'));
    img.src = src;
  });

/**
 * Maschera per classi della persona nella foto.
 * @param {string} photoUrl dataURL della foto (quella ORIGINALE, con sfondo:
 *        il modello è addestrato su foto vere, e le coordinate coincidono con
 *        il PNG scontornato che ha le stesse dimensioni).
 * @returns {Promise<{width:number,height:number,categories:Uint8Array}|null>}
 *          categories[y*width+x] = SEG_*.
 */
export async function segmentBody(photoUrl) {
  try {
    const [segmenter, img] = await Promise.all([getSegmenter(), loadImage(photoUrl)]);
    const result = segmenter.segment(img);
    const mask = result.categoryMask;
    const categories = new Uint8Array(mask.getAsUint8Array());
    const out = { width: mask.width, height: mask.height, categories };
    result.close();
    return out;
  } catch {
    return null;
  }
}

/** Indici dei landmark MediaPipe Pose che usiamo. */
const POSE_POINTS = {
  shoulderL: 11,
  shoulderR: 12,
  elbowL: 13,
  elbowR: 14,
  wristL: 15,
  wristR: 16,
  hipL: 23,
  hipR: 24,
  kneeL: 25,
  kneeR: 26,
  ankleL: 27,
  ankleR: 28,
};

/** Sotto questa visibilità un punto è inaffidabile (fuori foto, coperto). */
const MIN_VISIBILITY = 0.5;

/**
 * Punti del corpo in PIXEL della foto. null se la posa non si trova.
 * Ogni punto: {x, y, visible}. "L"/"R" sono di CHI GUARDA la foto specchiata
 * da MediaPipe: shoulderL è la spalla che appare a sinistra nell'immagine? No:
 * MediaPipe usa la sinistra ANATOMICA del soggetto. Per noi conta poco: i
 * consumatori ordinano i punti per x quando serve destra/sinistra visiva.
 * @returns {Promise<Record<string,{x:number,y:number,visible:boolean}>|null>}
 */
export async function detectPose(photoUrl) {
  try {
    const [pose, img] = await Promise.all([getPose(), loadImage(photoUrl)]);
    const result = pose.detect(img);
    const lm = result.landmarks?.[0];
    if (!lm) return null;
    const points = {};
    for (const [name, idx] of Object.entries(POSE_POINTS)) {
      const p = lm[idx];
      if (!p) return null;
      points[name] = {
        x: p.x * img.naturalWidth,
        y: p.y * img.naturalHeight,
        visible: (p.visibility ?? 1) >= MIN_VISIBILITY,
      };
    }
    return points;
  } catch {
    return null;
  }
}
