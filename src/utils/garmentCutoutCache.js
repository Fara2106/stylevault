/**
 * Cache locale (IndexedDB) dei PNG scontornati dei capi. La chiave lega id capo e
 * foto: se la foto cambia, la cache si invalida. `CUTOUT_VERSION` nel prefisso
 * permette di rigenerare tutto cambiando l'algoritmo di scontorno.
 */

export const CUTOUT_VERSION = 1;

/**
 * Hash stringa deterministico (djb2), in esadecimale. Non crittografico: serve
 * solo a distinguere foto diverse per la chiave di cache.
 */
const hashString = (s) => {
  let h = 5381;
  for (let i = 0; i < s.length; i++) h = ((h << 5) + h + s.charCodeAt(i)) | 0;
  return (h >>> 0).toString(16);
};

/** @returns {string} chiave di cache per il capo. */
export function cutoutCacheKey(item) {
  return `v${CUTOUT_VERSION}:${item.id}:${hashString(item.photo || '')}`;
}

const DB_NAME = 'sv_garment_cutouts';
const STORE = 'cutouts';

/** Apre (o crea) il DB. Risolve null se IndexedDB non c'è (es. modalità privata). */
const openDb = () =>
  new Promise((resolve) => {
    if (typeof indexedDB === 'undefined') return resolve(null);
    let req;
    try {
      req = indexedDB.open(DB_NAME, 1);
    } catch {
      return resolve(null);
    }
    req.onupgradeneeded = () => {
      if (!req.result.objectStoreNames.contains(STORE)) req.result.createObjectStore(STORE);
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => resolve(null);
  });

/** @returns {Promise<string|null>} dataURL PNG cachato, o null. */
export async function getCachedCutout(item) {
  const db = await openDb();
  if (!db) return null;
  return new Promise((resolve) => {
    try {
      const req = db.transaction(STORE, 'readonly').objectStore(STORE).get(cutoutCacheKey(item));
      req.onsuccess = () => resolve(typeof req.result === 'string' ? req.result : null);
      req.onerror = () => resolve(null);
    } catch {
      resolve(null);
    }
  });
}

/** Salva il dataURL. Non lancia mai. @returns {Promise<void>} */
export async function putCachedCutout(item, dataUrl) {
  const db = await openDb();
  if (!db) return;
  return new Promise((resolve) => {
    try {
      const tx = db.transaction(STORE, 'readwrite');
      tx.objectStore(STORE).put(dataUrl, cutoutCacheKey(item));
      tx.oncomplete = () => resolve();
      tx.onerror = () => resolve();
    } catch {
      resolve();
    }
  });
}
