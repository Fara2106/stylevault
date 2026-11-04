/**
 * Il luogo della pagina Outfit: "La mia posizione" oppure una città scelta a
 * mano (viaggi). Si ricorda solo la scelta su questo dispositivo, mai le
 * coordinate della posizione.
 */

const KEY = 'sv_outfit_place';
const POSITION = { mode: 'position' };

// Ripiego senza localStorage (test in Node, accesso negato)
export const _placeMemory = new Map();

function read() {
  try {
    if (typeof localStorage !== 'undefined') return localStorage.getItem(KEY);
  } catch {
    /* accesso negato: memoria */
  }
  return _placeMemory.get(KEY) ?? null;
}

function write(value) {
  try {
    if (typeof localStorage !== 'undefined') {
      localStorage.setItem(KEY, value);
      return;
    }
  } catch {
    /* come sopra */
  }
  _placeMemory.set(KEY, value);
}

const isCity = (city) =>
  city != null && typeof city.latitude === 'number' && typeof city.longitude === 'number';

/** @returns {{mode:'position'} | {mode:'city', city:object}} */
export function loadPlaceChoice() {
  try {
    const choice = JSON.parse(read());
    if (choice?.mode === 'city' && isCity(choice.city)) return { mode: 'city', city: choice.city };
  } catch {
    /* scelta rotta: posizione */
  }
  return POSITION;
}

/** true se l'utente ha già scelto (nel browser la posizione si chiede solo allora). */
export function hasSavedPlaceChoice() {
  return read() != null;
}

export function savePlaceChoice(choice) {
  const clean =
    choice?.mode === 'city' && isCity(choice.city) ? { mode: 'city', city: choice.city } : POSITION;
  write(JSON.stringify(clean));
}

/**
 * La città da usare adesso. Senza posizione (non ancora arrivata, negata) la
 * città predefinita: la pagina non aspetta mai.
 * @returns {{city:object, kind:'position'|'manual'|'default'}}
 */
export function resolvePlace({ choice, position, defaultCity }) {
  if (choice?.mode === 'city' && isCity(choice.city)) return { city: choice.city, kind: 'manual' };
  if (isCity(position)) return { city: position, kind: 'position' };
  return { city: defaultCity, kind: 'default' };
}

/** Posizione approssimativa dal browser; null se manca, negata o lenta. */
export function getBrowserPosition() {
  const geo = globalThis.navigator?.geolocation;
  if (!geo?.getCurrentPosition) return Promise.resolve(null);
  return new Promise((resolve) => {
    geo.getCurrentPosition(
      ({ coords }) => resolve({ latitude: coords.latitude, longitude: coords.longitude }),
      () => resolve(null),
      { enableHighAccuracy: false, timeout: 10000, maximumAge: 600000 }
    );
  });
}

/** Stesso luogo entro un centesimo di grado (~1 km): per abbinare le risposte dell'app. */
export function isSamePlace(a, b) {
  if (!isCity(a) || !isCity(b)) return false;
  return Math.abs(a.latitude - b.latitude) <= 0.01 && Math.abs(a.longitude - b.longitude) <= 0.01;
}
