/**
 * Worker dello scontorno: esegue @imgly/background-removal FUORI dal main
 * thread, così la pagina resta reattiva mentre l'inferenza WASM lavora
 * (secondi interi su telefono). Il worker riceve { id, photo } e risponde
 * { id, ok, blob | error }; la conversione a dataURL resta al chiamante.
 *
 * Requisiti nel worker: fetch, createImageBitmap e OffscreenCanvas — @imgly
 * li usa da solo quando ci sono (Safari ≥ 16.4, Chrome/Firefox da anni).
 * Se qualcosa manca l'import o l'inferenza lanciano: il chiamante ripiega
 * sul main thread come prima.
 */

let libPromise = null;

self.onmessage = async (event) => {
  const { id, photo } = event.data;
  try {
    if (!libPromise) libPromise = import('@imgly/background-removal');
    const { removeBackground } = await libPromise;
    const blob = await removeBackground(photo);
    self.postMessage({ id, ok: true, blob });
  } catch (err) {
    self.postMessage({ id, ok: false, error: String((err && err.message) || err) });
  }
};
