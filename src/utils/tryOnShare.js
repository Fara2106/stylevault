/**
 * Condivisione del try-on verso le app AI (ChatGPT/Gemini) con la Web Share
 * API: un gesto solo e nell'app di destinazione arrivano INSIEME il prompt e
 * le foto, già in ordine — la persona per prima (è la "Image 1" del prompt),
 * poi i capi numerati come nel testo. I nomi file numerati rendono l'ordine
 * visibile anche se l'app di arrivo riordina gli allegati.
 *
 * Nessun URL sa allegare foto a una chat esterna: la share sheet nativa è
 * l'unico canale che porta immagini + testo dentro l'app giusta. Dove non
 * c'è (desktop) restano i link e il bottone Copia.
 */

const slug = (name) =>
  String(name || '')
    .toLowerCase()
    .split(/[^a-z0-9]+/)
    .filter(Boolean)
    .join('-');

/**
 * Piano puro dei file da condividere (testabile senza browser).
 * @param {string|null} referencePhoto foto della persona (Image 1), se c'è.
 * @param {Array<{name?:string, photo:string}>} items capi nell'ordine del prompt.
 * @returns {Array<{source:string, name:string}>} nomi SENZA estensione (la
 *          decide il blob al momento del fetch).
 */
export function shareFilePlan(referencePhoto, items) {
  const plan = [];
  if (referencePhoto) plan.push({ source: referencePhoto, name: '1-persona' });
  items.forEach((item, i) => {
    plan.push({ source: item.photo, name: `${i + 2}-${slug(item.name) || 'capo'}` });
  });
  return plan;
}

const EXT_BY_MIME = { 'image/png': 'png', 'image/webp': 'webp', 'image/jpeg': 'jpg' };

/** Scarica le foto del piano e le impacchetta come File pronti per la share.
 *  Una foto irraggiungibile (CORS) si salta: meglio condividere il resto. */
export async function buildShareFiles(plan) {
  const files = [];
  for (const { source, name } of plan) {
    try {
      const blob = await (await fetch(source)).blob();
      const ext = EXT_BY_MIME[blob.type] || 'jpg';
      files.push(new File([blob], `${name}.${ext}`, { type: blob.type || 'image/jpeg' }));
    } catch {
      // si prosegue senza questa foto
    }
  }
  return files;
}

/** true se il browser sa condividere file (in pratica: telefono/tablet). */
export function canShareFiles() {
  if (typeof navigator === 'undefined' || typeof File === 'undefined') return false;
  if (!navigator.share || !navigator.canShare) return false;
  try {
    const probe = new File(['x'], 'probe.jpg', { type: 'image/jpeg' });
    return navigator.canShare({ files: [probe] });
  } catch {
    return false;
  }
}
