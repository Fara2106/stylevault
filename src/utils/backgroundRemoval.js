/**
 * Scontorno del capo con modello ML on-device (@imgly/background-removal, gratis,
 * gira nel browser via WASM). Import dinamico: il modello non entra nel bundle
 * iniziale, si scarica solo al primo uso. Restituisce un dataURL PNG trasparente.
 */

const blobToDataUrl = (blob) =>
  new Promise((resolve, reject) => {
    const r = new FileReader();
    r.onload = () => resolve(r.result);
    r.onerror = () => reject(new Error('read'));
    r.readAsDataURL(blob);
  });

/**
 * @param {string} photoUrl dataURL o URL della foto del capo.
 * @returns {Promise<string>} dataURL PNG scontornato. Lancia in caso di errore.
 */
export async function removeGarmentBackground(photoUrl) {
  const { removeBackground } = await import('@imgly/background-removal');
  const blob = await removeBackground(photoUrl);
  return blobToDataUrl(blob);
}
