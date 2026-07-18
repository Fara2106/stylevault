import { describe, it, expect } from 'vitest';
import {
  hexToRgb, rgbToHex, rgbToLab, labToRgb, deltaE,
  representativeColor, maskedPixels,
} from './colorSampling';

describe('conversioni', () => {
  it('hex↔rgb', () => {
    expect(hexToRgb('#ff8000')).toEqual({ r: 255, g: 128, b: 0 });
    expect(hexToRgb('zzz')).toBeNull();
    expect(rgbToHex({ r: 255, g: 128, b: 0 })).toBe('#ff8000');
  });
  it('rgbToLab su valori noti (D65)', () => {
    const white = rgbToLab({ r: 255, g: 255, b: 255 });
    expect(white.L).toBeCloseTo(100, 0);
    expect(Math.abs(white.a)).toBeLessThan(0.5);
    const black = rgbToLab({ r: 0, g: 0, b: 0 });
    expect(black.L).toBeCloseTo(0, 0);
    const red = rgbToLab({ r: 255, g: 0, b: 0 });
    expect(red.L).toBeCloseTo(53.2, 0);
    expect(red.a).toBeGreaterThan(70);
  });
  it('roundtrip rgb→lab→rgb entro ±2', () => {
    for (const c of [{ r: 12, g: 200, b: 99 }, { r: 240, g: 219, b: 200 }]) {
      const back = labToRgb(rgbToLab(c));
      expect(Math.abs(back.r - c.r)).toBeLessThanOrEqual(2);
      expect(Math.abs(back.g - c.g)).toBeLessThanOrEqual(2);
      expect(Math.abs(back.b - c.b)).toBeLessThanOrEqual(2);
    }
  });
  it('deltaE: zero su se stesso, simmetrica, cresce con la distanza', () => {
    const a = rgbToLab({ r: 100, g: 50, b: 50 });
    const b = rgbToLab({ r: 110, g: 60, b: 55 });
    const c = rgbToLab({ r: 20, g: 200, b: 240 });
    expect(deltaE(a, a)).toBe(0);
    expect(deltaE(a, b)).toBeCloseTo(deltaE(b, a), 10);
    expect(deltaE(a, c)).toBeGreaterThan(deltaE(a, b));
  });
});

describe('representativeColor', () => {
  it('con 8 pixel identici + 1 nero + 1 bianco, il taglio li scarta', () => {
    const mid = { r: 106, g: 137, b: 165 };
    const px = [...Array(8).fill(mid), { r: 0, g: 0, b: 0 }, { r: 255, g: 255, b: 255 }];
    expect(representativeColor(px)).toBe(rgbToHex(mid));
  });
  it('vuoto → null', () => {
    expect(representativeColor([])).toBeNull();
  });
});

describe('maskedPixels', () => {
  it('estrae solo i pixel delle classi volute', () => {
    // 2x2: [classe0, classe4, classe4, classe1]
    const imageData = {
      width: 2, height: 2,
      data: new Uint8ClampedArray([
        1, 2, 3, 255,   10, 20, 30, 255,
        40, 50, 60, 255, 7, 8, 9, 255,
      ]),
    };
    const categories = new Uint8Array([0, 4, 4, 1]);
    expect(maskedPixels(imageData, categories, [4])).toEqual([
      { r: 10, g: 20, b: 30 }, { r: 40, g: 50, b: 60 },
    ]);
  });
  it('rispetta maxSamples con passo di campionamento', () => {
    const n = 100;
    const imageData = { width: 10, height: 10, data: new Uint8ClampedArray(n * 4).fill(50) };
    const categories = new Uint8Array(n).fill(2);
    expect(maskedPixels(imageData, categories, [2], 10).length).toBeLessThanOrEqual(10);
  });
});
