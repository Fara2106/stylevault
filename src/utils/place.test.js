import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import {
  loadPlaceChoice,
  savePlaceChoice,
  resolvePlace,
  getBrowserPosition,
  _placeMemory,
} from './place';

const ROMA = { name: 'Roma', latitude: 41.9, longitude: 12.5 };
const PARIGI = { name: 'Parigi', latitude: 48.86, longitude: 2.35 };
const MILANO = { name: 'Milano', latitude: 45.46, longitude: 9.19 };

describe('scelta del luogo', () => {
  beforeEach(() => _placeMemory.clear());

  it('di partenza è la mia posizione', () => {
    expect(loadPlaceChoice()).toEqual({ mode: 'position' });
  });

  it('salva e rilegge una città scelta a mano', () => {
    savePlaceChoice({ mode: 'city', city: PARIGI });
    expect(loadPlaceChoice()).toEqual({ mode: 'city', city: PARIGI });
  });

  it('per la posizione non salva coordinate', () => {
    savePlaceChoice({ mode: 'position', latitude: 1, longitude: 2 });
    expect(JSON.parse([..._placeMemory.values()][0])).toEqual({ mode: 'position' });
  });

  it('JSON rotto o città senza coordinate → posizione', () => {
    _placeMemory.set('sv_outfit_place', '{rotto');
    expect(loadPlaceChoice()).toEqual({ mode: 'position' });
    _placeMemory.set('sv_outfit_place', JSON.stringify({ mode: 'city', city: { name: 'X' } }));
    expect(loadPlaceChoice()).toEqual({ mode: 'position' });
  });
});

describe('resolvePlace', () => {
  it('città scelta a mano', () => {
    expect(
      resolvePlace({ choice: { mode: 'city', city: PARIGI }, position: ROMA, defaultCity: MILANO })
    ).toEqual({ city: PARIGI, kind: 'manual' });
  });

  it('posizione quando c\'è', () => {
    expect(resolvePlace({ choice: { mode: 'position' }, position: ROMA, defaultCity: MILANO })).toEqual(
      { city: ROMA, kind: 'position' }
    );
  });

  it('città predefinita finché la posizione non arriva', () => {
    expect(resolvePlace({ choice: { mode: 'position' }, position: null, defaultCity: MILANO })).toEqual(
      { city: MILANO, kind: 'default' }
    );
  });

  it('una posizione arrivata dopo la scelta a mano non la sostituisce', () => {
    const choice = { mode: 'city', city: PARIGI };
    expect(resolvePlace({ choice, position: null, defaultCity: MILANO }).kind).toBe('manual');
    expect(resolvePlace({ choice, position: ROMA, defaultCity: MILANO })).toEqual({
      city: PARIGI,
      kind: 'manual',
    });
  });
});

describe('getBrowserPosition', () => {
  afterEach(() => vi.unstubAllGlobals());

  it('null se il browser non ha la geolocalizzazione', async () => {
    vi.stubGlobal('navigator', {});
    expect(await getBrowserPosition()).toBeNull();
  });

  it('null se il permesso è negato', async () => {
    vi.stubGlobal('navigator', {
      geolocation: { getCurrentPosition: (_ok, fail) => fail({ code: 1 }) },
    });
    expect(await getBrowserPosition()).toBeNull();
  });

  it('coordinate se va bene', async () => {
    const getCurrentPosition = vi.fn((ok) =>
      ok({ coords: { latitude: 41.9, longitude: 12.5, accuracy: 3000 } })
    );
    vi.stubGlobal('navigator', { geolocation: { getCurrentPosition } });
    expect(await getBrowserPosition()).toEqual({ latitude: 41.9, longitude: 12.5 });
    expect(getCurrentPosition.mock.calls[0][2]).toEqual({
      enableHighAccuracy: false,
      timeout: 10000,
      maximumAge: 600000,
    });
  });
});
