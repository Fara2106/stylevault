/**
 * Scontorno sulla GPU del telefono (WebGPU: Safari iOS 26, Chrome): molte
 * volte più veloce del WASM a un solo thread, l'unico disponibile senza
 * isolamento cross-origin (GitHub Pages non può inviare gli header COOP/COEP).
 * Senza WebGPU @imgly ripiega da solo sulla CPU; se invece la GPU c'è ma
 * l'inferenza fallisce (driver, memoria) si ritenta esplicitamente su CPU.
 * proxyToWorker resta spento: siamo già noi in un worker (o nel ripiego).
 */
let gpuBroken = false;

/** Solo per i test: dimentica un fallimento GPU precedente. */
export function resetGpuFallback() {
  gpuBroken = false;
}

export async function cutoutWithGpuFallback(removeBackground, photo) {
  if (!gpuBroken) {
    try {
      return await removeBackground(photo, { device: 'gpu', proxyToWorker: false });
    } catch {
      gpuBroken = true;
    }
  }
  return removeBackground(photo, { device: 'cpu', proxyToWorker: false });
}
