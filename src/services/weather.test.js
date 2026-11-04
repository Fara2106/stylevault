import { describe, it, expect, vi, beforeEach } from 'vitest';
import {
  mapWeatherCode,
  parseForecastPayload,
  fetchForecastWithCache,
  searchCities,
  _memoryStorage,
} from './weather';

const SAMPLE_PAYLOAD = {
  daily: {
    time: ['2026-07-08', '2026-07-09'],
    temperature_2m_max: [31.2, 24.0],
    temperature_2m_min: [21.5, 17.3],
    apparent_temperature_max: [33.8, 22.1],
    apparent_temperature_min: [22.0, 16.0],
    precipitation_probability_max: [10, 80],
    weather_code: [0, 61],
    wind_speed_10m_max: [12.4, 30.1],
    uv_index_max: [8.1, 3.2],
  },
};

describe('mapWeatherCode', () => {
  it('maps clear sky', () => {
    expect(mapWeatherCode(0)).toEqual({
      icon: 'sun',
      descriptionKey: 'weather.clear',
      rain: false,
      snow: false,
    });
  });

  it('maps rain codes with rain=true', () => {
    for (const code of [61, 63, 65, 80, 82]) {
      const mapped = mapWeatherCode(code);
      expect(mapped.rain).toBe(true);
      expect(mapped.icon).toBe('rain');
    }
  });

  it('maps snow codes with snow=true', () => {
    const mapped = mapWeatherCode(73);
    expect(mapped.snow).toBe(true);
    expect(mapped.icon).toBe('snow');
    expect(mapped.descriptionKey).toBe('weather.snow');
  });

  it('maps thunderstorm as rain', () => {
    const mapped = mapWeatherCode(95);
    expect(mapped.rain).toBe(true);
    expect(mapped.descriptionKey).toBe('weather.thunderstorm');
  });

  it('falls back to cloudy for unknown codes', () => {
    expect(mapWeatherCode(999).descriptionKey).toBe('weather.cloudy');
  });
});

describe('parseForecastPayload', () => {
  it('produces one day object per date with the fields the app uses', () => {
    const days = parseForecastPayload(SAMPLE_PAYLOAD, 'Milano');
    expect(days).toHaveLength(2);

    const [today, tomorrow] = days;
    expect(today.city).toBe('Milano');
    expect(today.date).toBe('2026-07-08');
    expect(today.tMin).toBe(21.5);
    expect(today.tMax).toBe(31.2);
    // temperatura di lavoro = media delle percepite
    expect(today.temperature).toBeCloseTo((33.8 + 22.0) / 2, 5);
    expect(today.windSpeed).toBe(12.4);
    expect(today.uvIndex).toBe(8.1);
    expect(today.precipProb).toBe(10);
    expect(today.rain).toBe(false);
    expect(today.icon).toBe('sun');

    // pioggia dal weather code
    expect(tomorrow.rain).toBe(true);
    expect(tomorrow.descriptionKey).toBe('weather.rainy');
  });

  it('marks rain=true when precipitation probability is high even with dry code', () => {
    const payload = structuredClone(SAMPLE_PAYLOAD);
    payload.daily.weather_code = [3, 3];
    payload.daily.precipitation_probability_max = [60, 10];
    const days = parseForecastPayload(payload, 'Oslo');
    expect(days[0].rain).toBe(true);
    expect(days[1].rain).toBe(false);
  });
});

describe('fetchForecastWithCache', () => {
  const city = { name: 'Milano', latitude: 45.46, longitude: 9.19 };

  beforeEach(() => {
    _memoryStorage.clear();
    vi.restoreAllMocks();
  });

  it('returns fresh data and stores them in cache', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({ ok: true, json: async () => SAMPLE_PAYLOAD })
    );

    const result = await fetchForecastWithCache(city);
    expect(result.stale).toBe(false);
    expect(result.days).toHaveLength(2);

    // seconda chiamata con rete rotta → usa la cache, stale=true
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new Error('offline')));
    const cached = await fetchForecastWithCache(city);
    expect(cached.stale).toBe(true);
    expect(cached.days).toHaveLength(2);
    expect(cached.fetchedAt).toBe(result.fetchedAt);
  });

  it('throws weather-unavailable when there is no network and no cache', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new Error('offline')));
    await expect(fetchForecastWithCache(city)).rejects.toThrow('weather-unavailable');
  });
});

describe('searchCities', () => {
  it('maps geocoding results to app city objects', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({
          results: [
            {
              id: 1,
              name: 'Milano',
              latitude: 45.46,
              longitude: 9.19,
              country: 'Italia',
              admin1: 'Lombardia',
            },
          ],
        }),
      })
    );

    const cities = await searchCities('mila', 'it');
    expect(cities).toEqual([
      {
        id: 1,
        name: 'Milano',
        latitude: 45.46,
        longitude: 9.19,
        country: 'Italia',
        region: 'Lombardia',
      },
    ]);
  });

  it('returns [] when the API has no results', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({ ok: true, json: async () => ({}) })
    );
    expect(await searchCities('xyzxyz', 'it')).toEqual([]);
  });
});

/** Payload con 2 giorni e 48 ore (percepita = ora del giorno). */
const hourlyPayload = (utcOffsetSeconds) => ({
  ...structuredClone(SAMPLE_PAYLOAD),
  utc_offset_seconds: utcOffsetSeconds,
  hourly: {
    time: ['2026-07-08', '2026-07-09'].flatMap((d) =>
      Array.from({ length: 24 }, (_, h) => `${d}T${String(h).padStart(2, '0')}:00`)
    ),
    apparent_temperature: Array.from({ length: 48 }, (_, i) => i % 24),
    precipitation_probability: Array.from({ length: 48 }, () => 0),
    weather_code: Array.from({ length: 48 }, () => 0),
  },
});

describe('parseForecastPayload — ore', () => {
  it('con hourly aggiunge fasce e usa la media 8–20', () => {
    const now = new Date('2026-07-09T05:00:00Z'); // 06:00 sul posto
    const days = parseForecastPayload(hourlyPayload(3600), 'Milano', now);
    expect(days[1].temperature).toBe(13.5);
    expect(days[1].parts).toHaveLength(3);
    expect(days[1].parts[0].icon).toBe('sun');
    expect(days[1].parts[0].descriptionKey).toBe('weather.clear');
    expect(days[1].rainFrom).toBeNull();
    expect(days[0].parts).toHaveLength(3);
  });

  it('il fuso del luogo decide le ore passate', () => {
    const now = new Date('2026-07-08T20:00:00Z'); // 15:00 a New York
    const days = parseForecastPayload(hourlyPayload(-18000), 'New York', now);
    expect(days[0].parts[0].past).toBe(true);
    expect(days[0].parts[1].past).toBe(false);
    expect(days[0].temperature).toBe(17);
    expect(days[1].parts.some((p) => p.past)).toBe(false);
  });

  it('senza hourly il giorno è come prima', () => {
    const [today] = parseForecastPayload(SAMPLE_PAYLOAD, 'Milano');
    expect(today).not.toHaveProperty('parts');
    expect(today.temperature).toBeCloseTo((33.8 + 22.0) / 2, 5);
  });
});

describe('fetchForecastWithCache — ore e fonte', () => {
  const city = { name: 'Milano', latitude: 45.46, longitude: 9.19 };

  beforeEach(() => {
    _memoryStorage.clear();
    vi.restoreAllMocks();
  });

  it('chiede i dati orari e mette la fonte nella chiave della cache', async () => {
    const fetchMock = vi.fn().mockResolvedValue({ ok: true, json: async () => SAMPLE_PAYLOAD });
    vi.stubGlobal('fetch', fetchMock);
    await fetchForecastWithCache(city);
    expect(fetchMock.mock.calls[0][0]).toContain(
      'hourly=apparent_temperature%2Cprecipitation_probability%2Cweather_code'
    );
    expect([..._memoryStorage.keys()].some((k) => k.startsWith('sv_weather_openmeteo_'))).toBe(
      true
    );
  });
});
