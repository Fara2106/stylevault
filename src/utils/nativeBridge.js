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

// Chi ascolta posizione e previsione mandate dall'app; l'ultima posizione resta
// per chi si iscrive dopo (la pagina Outfit può aprirsi dopo l'arrivo)
const locationListeners = new Set();
const forecastListeners = new Set();
let lastLocation = null;

/** Solo per i test. */
export function _resetNativeListeners() {
  locationListeners.clear();
  forecastListeners.clear();
  lastLocation = null;
}

/** Espone al nativo le funzioni che può chiamare nella pagina. */
export function installNativeHooks({ setSession }) {
  if (!isNativeApp()) return;
  window.svNative = {
    setSession,
    setLocation: (location) => {
      lastLocation = location;
      locationListeners.forEach((cb) => cb(location));
    },
    setForecast: (forecast) => forecastListeners.forEach((cb) => cb(forecast)),
  };
  // Il nativo aspetta questo segnale per passare la sessione: prima la
  // chiamata a setSession cadrebbe nel vuoto (React non ha ancora montato).
  postToNative('ready');
}

/** Posizione del telefono {latitude, longitude, name}; restituisce la disiscrizione. */
export function onNativeLocation(cb) {
  locationListeners.add(cb);
  if (lastLocation) cb(lastLocation);
  return () => locationListeners.delete(cb);
}

/** Previsione dall'app {payload, source, attribution}; restituisce la disiscrizione. */
export function onNativeForecast(cb) {
  forecastListeners.add(cb);
  return () => forecastListeners.delete(cb);
}

/** Chiede all'app la posizione (un'app vecchia ignora il messaggio). */
export function requestNativeLocation() {
  return postToNative('requestLocation');
}

/** Chiede all'app la previsione del luogo (Meteo di Apple, se acceso). */
export function requestNativeForecast(city) {
  return postToNative('requestForecast', {
    latitude: city.latitude,
    longitude: city.longitude,
    name: city.name,
  });
}
