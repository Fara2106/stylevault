/**
 * Scontorno del capo con modello ML on-device (@imgly/background-removal, gratis,
 * gira nel browser via WASM). Import dinamico: il modello non entra nel bundle
 * iniziale, si scarica solo al primo uso. Restituisce un dataURL PNG trasparente.
 *
 * L'inferenza gira in un Web Worker (cutoutWorker.js): sul percorso WASM
 * @imgly non sa spostarsi da solo fuori dal main thread (il suo proxyToWorker
 * vale solo con WebGPU) e un'inferenza da secondi congelerebbe la pagina —
 * era il freeze segnalato su "Cambia foto". Se il worker non parte o fallisce
 * si ripiega sull'esecuzione nel main thread, identica a prima.
 */

const blobToDataUrl = (blob) =>
  new Promise((resolve, reject) => {
    const r = new FileReader();
    r.onload = () => resolve(r.result);
    r.onerror = () => reject(new Error('read'));
    r.readAsDataURL(blob);
  });

let worker = null;
let workerBroken = false;
let nextId = 0;
const pending = new Map();

const failAllPending = (reason) => {
  for (const p of pending.values()) p.reject(new Error(reason));
  pending.clear();
};

const getWorker = () => {
  if (worker) return worker;
  worker = new Worker(new URL('./cutoutWorker.js', import.meta.url), { type: 'module' });
  worker.onmessage = (event) => {
    const { id, ok, blob, error } = event.data;
    const p = pending.get(id);
    if (!p) return;
    pending.delete(id);
    if (ok) p.resolve(blob);
    else p.reject(new Error(error || 'cutout'));
  };
  // Il worker non si è proprio caricato (browser vecchio, CSP): da qui in poi
  // si lavora nel main thread, senza ritentare a ogni foto.
  worker.onerror = () => {
    workerBroken = true;
    failAllPending('worker');
    worker.terminate();
    worker = null;
  };
  return worker;
};

const cutoutInWorker = (photoUrl) => {
  const id = nextId++;
  const w = getWorker();
  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject });
    w.postMessage({ id, photo: photoUrl });
  });
};

const cutoutInMain = async (photoUrl) => {
  const { removeBackground } = await import('@imgly/background-removal');
  const blob = await removeBackground(photoUrl);
  return blobToDataUrl(blob);
};

/**
 * @param {string} photoUrl dataURL o URL della foto del capo.
 * @returns {Promise<string>} dataURL PNG scontornato. Lancia in caso di errore.
 */
export async function removeGarmentBackground(photoUrl) {
  if (typeof Worker !== 'undefined' && !workerBroken) {
    try {
      const blob = await cutoutInWorker(photoUrl);
      return await blobToDataUrl(blob);
    } catch {
      // L'errore può essere del worker o della foto: si ritenta nel main
      // thread. Se lì riesce era l'ambiente del worker (resta spento per la
      // sessione); se fallisce anche lì è la foto e il worker resta valido.
      const url = await cutoutInMain(photoUrl);
      workerBroken = true;
      return url;
    }
  }
  return cutoutInMain(photoUrl);
}
