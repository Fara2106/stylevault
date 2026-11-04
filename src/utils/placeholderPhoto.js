/**
 * Segnaposto neutro per un capo salvato senza foto: fondo chiaro con
 * l'iniziale del nome. Prima c'era una foto a caso di picsum.photos, che
 * sembrava un contenuto finto (Apple 2.1). È un JPEG, così il salvataggio
 * sul cloud lo carica come le foto vere.
 */
export function placeholderInitial(name) {
  const first = (name || '').trim().charAt(0);
  return first ? first.toLocaleUpperCase('it') : '·';
}

/**
 * @param {string} name nome del capo
 * @param {Document|null} doc il documento (null fuori dal browser)
 * @returns {string} data URL JPEG, o '' se non si può disegnare
 */
export function makePlaceholderPhoto(name, doc = globalThis.document ?? null) {
  try {
    const canvas = doc?.createElement('canvas');
    const ctx = canvas?.getContext?.('2d');
    if (!ctx) return '';
    canvas.width = 600;
    canvas.height = 800;
    ctx.fillStyle = '#EFE9DF';
    ctx.fillRect(0, 0, 600, 800);
    ctx.fillStyle = '#9C9184';
    ctx.font = '300 220px Georgia, serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(placeholderInitial(name), 300, 400);
    return canvas.toDataURL('image/jpeg', 0.85);
  } catch {
    return '';
  }
}
