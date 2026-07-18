import { describe, it, expect } from 'vitest';
import { classifySeason, SEASON_AXES } from './armocromiaClassifier';

// Terne rappresentative (pelle, capelli, occhi) — una per stagione.
const FIXTURES = {
  'light-spring': { skin: '#f7dcc9', hair: '#e9c98f', eyes: '#8fb6a8' },
  'light-summer': { skin: '#f0d9d2', hair: '#cfc4b0', eyes: '#a9c1cf' },
  'true-spring': { skin: '#edc39e', hair: '#a9752e', eyes: '#6f8f55' },
  'true-summer': { skin: '#e6c4bd', hair: '#7e7468', eyes: '#6f8dad' },
  'true-autumn': { skin: '#cf9c6b', hair: '#6b4423', eyes: '#63512c' },
  'true-winter': { skin: '#e3c0b8', hair: '#2e2a28', eyes: '#4f6b8f' },
  'bright-spring': { skin: '#f4cdb0', hair: '#a86f2f', eyes: '#2e8b74' },
  'bright-winter': { skin: '#f0cabe', hair: '#221d1c', eyes: '#1e63c8' },
  'soft-autumn': { skin: '#ddb394', hair: '#8a6b4a', eyes: '#84805f' },
  'soft-summer': { skin: '#e5c6bf', hair: '#9a8f83', eyes: '#8496a0' },
  'deep-autumn': { skin: '#b97f4e', hair: '#4a2d17', eyes: '#5a3d20' },
  'deep-winter': { skin: '#a9765c', hair: '#1d1a19', eyes: '#3a4a63' },
};

describe('classifySeason', () => {
  for (const [season, input] of Object.entries(FIXTURES)) {
    it(`riconosce ${season}`, () => {
      expect(classifySeason(input).season).toBe(season);
    });
  }
  it('espone assi e confidenza', () => {
    const r = classifySeason(FIXTURES['deep-winter']);
    expect(r.axes.lightDeep).toBeLessThan(0);
    expect(r.confidence).toBeGreaterThan(0);
    expect(r.confidence).toBeLessThanOrEqual(1);
  });
  it('senza occhi le stagioni scure restano corrette', () => {
    expect(classifySeason({ ...FIXTURES['deep-winter'], eyes: null }).season).toBe('deep-winter');
    expect(classifySeason({ ...FIXTURES['true-autumn'], eyes: null }).season).toBe('true-autumn');
  });
  it('senza capelli la confidenza crolla (la UI inviterà a correggere)', () => {
    const r = classifySeason({ ...FIXTURES['light-spring'], hair: null });
    expect(r.confidence).toBeLessThan(0.3);
  });
  it('senza pelle e capelli → null', () => {
    expect(classifySeason({ skin: null, hair: null, eyes: '#4f6b8f' })).toBeNull();
  });
  it('SEASON_AXES ha esattamente i 12 id', () => {
    expect(Object.keys(SEASON_AXES).sort()).toEqual([
      'bright-spring', 'bright-winter', 'deep-autumn', 'deep-winter',
      'light-spring', 'light-summer', 'soft-autumn', 'soft-summer',
      'true-autumn', 'true-spring', 'true-summer', 'true-winter',
    ]);
  });
});
