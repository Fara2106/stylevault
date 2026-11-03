import { describe, it, expect, vi, beforeEach } from 'vitest';
import { modelsReady, markModelsReady } from './firstUse';

describe('firstUse', () => {
  beforeEach(() => {
    const store = new Map();
    vi.stubGlobal('localStorage', {
      getItem: (k) => (store.has(k) ? store.get(k) : null),
      setItem: (k, v) => store.set(k, String(v)),
    });
  });

  it('la prima volta i modelli non sono pronti, dopo il primo giro sì', () => {
    expect(modelsReady('tryon')).toBe(false);
    markModelsReady('tryon');
    expect(modelsReady('tryon')).toBe(true);
    expect(modelsReady('armocromia')).toBe(false);
  });

  it('senza localStorage (privata, bloccato) non lancia', () => {
    vi.stubGlobal('localStorage', {
      getItem: () => {
        throw new Error('blocked');
      },
      setItem: () => {
        throw new Error('blocked');
      },
    });
    expect(modelsReady('tryon')).toBe(false);
    expect(() => markModelsReady('tryon')).not.toThrow();
  });
});
