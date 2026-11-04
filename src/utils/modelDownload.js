/**
 * Download dei modelli on-device (MediaPipe) con l'avanzamento, per la barra
 * del primo uso. MediaPipe scaricherebbe da solo i file senza dire a che punto
 * è: li scarichiamo noi leggendo i byte man mano e glieli passiamo già pronti.
 * I file restano sul dispositivo nella Cache Storage (sito e app, che è lo
 * stesso sito in una WebView): dalla seconda volta niente rete. Dove manca
 * (pagine in http) resta la cache HTTP del browser.
 */

const CACHE_NAME = 'sv-models-v1';

async function openModelCache() {
  try {
    return globalThis.caches ? await globalThis.caches.open(CACHE_NAME) : null;
  } catch {
    return null; // bloccata o piena: si scarica e basta
  }
}

const downloads = new Map(); // key -> { loaded, done, promise }
const listeners = new Set();

const notify = () => listeners.forEach((fn) => fn());

/** Avvisa `fn` a ogni pezzo arrivato; restituisce la funzione per smettere. */
export function onModelProgress(fn) {
  listeners.add(fn);
  return () => listeners.delete(fn);
}

/**
 * Quanto è scaricato (0–1) di un gruppo di file, pesato sulle dimensioni.
 * `bytes` è la dimensione attesa (decompressa): un file finito conta per
 * intero, uno in corso al massimo per la sua dimensione attesa.
 * @param {{key:string, bytes:number}[]} items
 */
export function downloadFraction(items) {
  const total = items.reduce((sum, i) => sum + i.bytes, 0);
  if (!total) return 1;
  const loaded = items.reduce((sum, { key, bytes }) => {
    const d = downloads.get(key);
    if (!d) return sum;
    return sum + (d.done ? bytes : Math.min(d.loaded, bytes));
  }, 0);
  return loaded / total;
}

async function readAll(res, entry) {
  if (!res.body?.getReader) {
    const data = new Uint8Array(await res.arrayBuffer());
    entry.loaded = data.length;
    return data;
  }
  const reader = res.body.getReader();
  const chunks = [];
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    chunks.push(value);
    entry.loaded += value.length;
    notify();
  }
  const data = new Uint8Array(entry.loaded);
  let offset = 0;
  for (const c of chunks) {
    data.set(c, offset);
    offset += c.length;
  }
  return data;
}

/**
 * Scarica un file di modello una volta sola (le richieste uguali si uniscono).
 * @param {string} key nome del file nel gruppo (per downloadFraction)
 * @param {string} url
 * @param {number} expectedBytes dimensione attesa, per la barra
 * @returns {Promise<Uint8Array>}
 * @throws {Error} 'model-http-<status>' o l'errore di rete
 */
export function fetchModel(key, url, expectedBytes, fetchImpl = globalThis.fetch) {
  const existing = downloads.get(key);
  if (existing && !existing.failed) return existing.promise;

  const entry = { loaded: 0, done: false, failed: false, expectedBytes };
  entry.promise = (async () => {
    try {
      const cache = await openModelCache();
      const saved = cache ? await cache.match(url).catch(() => undefined) : undefined;
      let data;
      if (saved) {
        data = await readAll(saved, entry);
      } else {
        const res = await fetchImpl(url);
        if (!res.ok) throw new Error(`model-http-${res.status}`);
        data = await readAll(res, entry);
        // Conservato sul dispositivo; se non ci sta pazienza, si riscarica
        await cache?.put(url, new Response(data)).catch(() => {});
      }
      entry.done = true;
      notify();
      return data;
    } catch (error) {
      // Al prossimo tentativo si riparte da zero
      downloads.delete(key);
      entry.failed = true;
      notify();
      throw error;
    }
  })();
  downloads.set(key, entry);
  notify();
  return entry.promise;
}

/** Solo per i test. */
export function _resetModelDownloads() {
  downloads.clear();
  listeners.clear();
}
