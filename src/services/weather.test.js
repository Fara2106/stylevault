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
