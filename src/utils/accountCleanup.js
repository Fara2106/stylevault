/**
 * Dopo la cancellazione dell'account: cosa togliere da questo browser (o
 * dalla WebView dell'app). Restano solo lingua e tema (`sv_settings`), i
 * segni dei modelli già scaricati e il guardiano del ricaricamento.
 */
const KEEP = [/^sv_settings$/, /^sv_models_ready_/, /^sv_chunk_reload$/];

/** @param {string[]} keys tutte le chiavi di localStorage */
export function keysToForget(keys) {
  return keys.filter((k) => k.startsWith('sv_') && !KEEP.some((re) => re.test(k)));
}

/** Toglie dal dispositivo i dati locali dell'account (localStorage e scontorni). */
export function forgetLocalData(storage = globalThis.localStorage) {
  try {
    const keys = Array.from({ length: storage.length }, (_, i) => storage.key(i));
    keysToForget(keys).forEach((k) => storage.removeItem(k));
  } catch {
    // storage bloccato: niente da togliere
  }
  try {
    globalThis.indexedDB?.deleteDatabase('sv_garment_cutouts');
  } catch {
    // come sopra
  }
}
