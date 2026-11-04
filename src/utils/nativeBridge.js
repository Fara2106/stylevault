/**
 * Ponte con l'app iOS (WKWebView + handler "svNative").
 * Nel browser normale nessuna di queste funzioni fa qualcosa: il sito resta
 * identico. Nell'app:
 * - verso il nativo: { type, payload } con openAvatar, openBodyPhotos,
 *   signOut, themeChanged;
 * - dal nativo: window.svNative.setSession(access, refresh), così il login
 *   fatto in nativo vale anche per la WebView.
 */

import { garmentDescriptor } from './tryOnPrompt';

const handler = () => globalThis.window?.webkit?.messageHandlers?.svNative;

/** true se il sito gira dentro l'app iOS. */
export function isNativeApp() {
  return Boolean(handler());
}

/** Manda un messaggio al nativo; false fuori dall'app. */
export function postToNative(type, payload = {}) {
  const h = handler();
  if (!h) return false;
  h.postMessage({ type, payload });
  return true;
}

const SLOTS = ['top', 'bottom', 'shoes', 'outerwear'];

/** Outfit → dati per l'avatar nativo (gli accessori non si indossano sul corpo). */
export function avatarPayload(outfit) {
  const items = SLOTS.filter((slot) => outfit?.[slot]).map((slot) => {
    const item = outfit[slot];
    return {
      id: item.id,
      category: item.category,
      slot,
      photo: item.photo,
      photoBack: item.photoBack || null,
      name: item.name,
      descriptor: garmentDescriptor(item),
    };
  });
  return { items };
}

/** Espone al nativo le funzioni che può chiamare nella pagina. */
export function installNativeHooks({ setSession }) {
  if (!isNativeApp()) return;
  window.svNative = { setSession };
  // Il nativo aspetta questo segnale per passare la sessione: prima la
  // chiamata a setSession cadrebbe nel vuoto (React non ha ancora montato).
  postToNative('ready');
}
