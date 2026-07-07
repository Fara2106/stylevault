/**
 * Servizio meteo basato su Open-Meteo (gratuito, senza API key).
 * - searchCities: geocoding per la ricerca manuale della città
 * - fetchForecastWithCache: previsione 7 giorni con cache localStorage
 *   (se la rete manca si usa l'ultima previsione salvata, marcata stale)
 */

const GEOCODING_URL = 'https://geocoding-api.open-meteo.com/v1/search';
const FORECAST_URL = 'https://api.open-meteo.com/v1/forecast';
const CACHE_PREFIX = 'sv_weather_';

// Fallback in ambienti senza localStorage (test in Node)
export const _memoryStorage = new Map();
const storage = {
  get(key) {
    try {
      if (typeof localStorage !== 'undefined') return localStorage.getItem(key);
    } catch {
      /* quota o accesso negato: si ripiega sulla memoria */
    }
    return _memoryStorage.get(key) ?? null;
  },
  set(key, value) {
    try {
      if (typeof localStorage !== 'undefined') {
        localStorage.setItem(key, value);
        return;
      }
    } catch {
      /* come sopra */
    }
    _memoryStorage.set(key, value);
  },
};

/** Mappa un WMO weather code in icona, chiave descrizione e flag pioggia/neve. */
export function mapWeatherCode(code) {
  const entry = (icon, descriptionKey, rain = false, snow = false) => ({
    icon,
    descriptionKey,
    rain,
    snow,
  });

  if (code === 0) return entry('sun', 'weather.clear');
  if (code === 1 || code === 2) return entry('sun', 'weather.partlyCloudy');
  if (code === 3) return entry('cloud', 'weather.cloudy');
  if (code === 45 || code === 48) return entry('cloud', 'weather.fog');
  if (code >= 51 && code <= 57) return entry('rain', 'weather.drizzle', true);
  if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82))
    return entry('rain', 'weather.rainy', true);
  if ((code >= 71 && code <= 77) || code === 85 || code === 86)
    return entry('snow', 'weather.snow', false, true);
  if (code >= 95 && code <= 99) return entry('rain', 'weather.thunderstorm', true);
  return entry('cloud', 'weather.cloudy');
}

/** Sopra questa probabilità di pioggia trattiamo il giorno come piovoso. */
const RAIN_PROBABILITY_THRESHOLD = 45;

/**
 * Converte il payload daily di Open-Meteo in oggetti-giorno usati da
 * WeatherBadge e generateOutfits.
 */
export function parseForecastPayload(payload, cityLabel) {
  const d = payload?.daily;
  if (!d?.time?.length) return [];

  return d.time.map((date, i) => {
    const mapped = mapWeatherCode(d.weather_code?.[i]);
    const precipProb = d.precipitation_probability_max?.[i] ?? null;
    const apparentMax = d.apparent_temperature_max?.[i];
    const apparentMin = d.apparent_temperature_min?.[i];

    return {
      city: cityLabel,
      date,
      tMin: d.temperature_2m_min?.[i] ?? null,
      tMax: d.temperature_2m_max?.[i] ?? null,
      // temperatura "di lavoro" per l'algoritmo: media delle percepite
      temperature:
        apparentMax != null && apparentMin != null
          ? (apparentMax + apparentMin) / 2
          : (d.temperature_2m_max?.[i] ?? 20),
      windSpeed: d.wind_speed_10m_max?.[i] ?? 0,
      uvIndex: d.uv_index_max?.[i] ?? 0,
      precipProb,
      icon: mapped.icon,
      descriptionKey: mapped.descriptionKey,
      rain: mapped.rain || (precipProb != null && precipProb >= RAIN_PROBABILITY_THRESHOLD),
      snow: mapped.snow,
    };
  });
}

/**
 * Cerca città per nome (geocoding Open-Meteo).
 * @returns {Promise<{id,name,latitude,longitude,country,region}[]>}
 */
export async function searchCities(query, language = 'it') {
  const url = `${GEOCODING_URL}?name=${encodeURIComponent(query)}&count=6&language=${language}&format=json`;
  const res = await fetch(url);
  if (!res.ok) throw new Error('geocoding-failed');
  const data = await res.json();
  return (data.results || []).map((r) => ({
    id: r.id,
    name: r.name,
    latitude: r.latitude,
    longitude: r.longitude,
    country: r.country,
    region: r.admin1,
  }));
}

const cacheKey = (city) =>
  `${CACHE_PREFIX}${city.latitude.toFixed(2)}_${city.longitude.toFixed(2)}`;

/**
 * Previsione 7 giorni per una città {name, latitude, longitude}.
 * @returns {Promise<{days: object[], stale: boolean, fetchedAt: number}>}
 * @throws {Error} 'weather-unavailable' se rete e cache mancano entrambe
 */
export async function fetchForecastWithCache(city) {
  const params = new URLSearchParams({
    latitude: String(city.latitude),
    longitude: String(city.longitude),
    daily: [
      'temperature_2m_max',
      'temperature_2m_min',
      'apparent_temperature_max',
      'apparent_temperature_min',
      'precipitation_probability_max',
      'weather_code',
      'wind_speed_10m_max',
      'uv_index_max',
    ].join(','),
    timezone: 'auto',
    forecast_days: '7',
  });

  try {
    const res = await fetch(`${FORECAST_URL}?${params}`);
    if (!res.ok) throw new Error(`forecast-http-${res.status}`);
    const payload = await res.json();
    const days = parseForecastPayload(payload, city.name);
    const fetchedAt = Date.now();
    storage.set(cacheKey(city), JSON.stringify({ fetchedAt, cityName: city.name, days }));
    return { days, stale: false, fetchedAt };
  } catch (networkError) {
    const cached = storage.get(cacheKey(city));
    if (cached) {
      try {
        const { fetchedAt, days } = JSON.parse(cached);
        return { days, stale: true, fetchedAt };
      } catch {
        /* cache corrotta: cade nel throw finale */
      }
    }
    throw new Error('weather-unavailable', { cause: networkError });
  }
}
