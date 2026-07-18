import { describe, it, expect } from 'vitest';
import { SEASONS, getSeason } from './armocromiaSeasons';
import { SEASON_AXES } from './armocromiaClassifier';
import { hexToRgb } from './colorSampling';
import it_ from '../i18n/it.json';
import en from '../i18n/en.json';

const tKey = (obj, dotted) => dotted.split('.').reduce((o, k) => o && o[k], obj);

describe('integrità SEASONS', () => {
  it('le 12 stagioni combaciano col classificatore', () => {
    expect(Object.keys(SEASONS).sort()).toEqual(Object.keys(SEASON_AXES).sort());
  });
  it('ogni stagione è completa e con hex validi', () => {
    for (const s of Object.values(SEASONS)) {
      expect(s.palette.length).toBeGreaterThanOrEqual(5);
      expect(s.avoid.length).toBeGreaterThanOrEqual(2);
      expect(s.neutrals.length).toBeGreaterThanOrEqual(3);
      expect(['gold', 'silver', 'both']).toContain(s.metal);
      expect(s.makeup.lips.length).toBeGreaterThanOrEqual(2);
      expect(s.makeup.blush.length).toBeGreaterThanOrEqual(1);
      expect(s.makeup.eyes.length).toBeGreaterThanOrEqual(2);
      expect(['warm', 'cool', 'neutral']).toContain(s.makeup.foundationUndertone);
      for (const c of [...s.palette, ...s.avoid, ...s.neutrals,
                       ...s.makeup.lips, ...s.makeup.blush, ...s.makeup.eyes]) {
        expect(hexToRgb(c.hex)).not.toBeNull();
        expect(c.nameKey).toMatch(/^armocromia\.colors\./);
      }
    }
  });
  it('ogni chiave i18n esiste in IT e in EN', () => {
    const keys = new Set();
    for (const s of Object.values(SEASONS)) {
      keys.add(s.nameKey);
      keys.add(s.descKey);
      for (const c of [...s.palette, ...s.avoid, ...s.neutrals,
                       ...s.makeup.lips, ...s.makeup.blush, ...s.makeup.eyes]) {
        keys.add(c.nameKey);
      }
    }
    for (const k of keys) {
      expect(tKey(it_, k), `IT manca ${k}`).toBeTruthy();
      expect(tKey(en, k), `EN manca ${k}`).toBeTruthy();
    }
  });
  it('getSeason', () => {
    expect(getSeason('deep-winter').metal).toBe('silver');
    expect(getSeason('nope')).toBeNull();
  });
});
