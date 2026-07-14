import { describe, it, expect } from 'vitest';
import { countIslands, textDensity, classifyGarmentImage } from './garmentClassifier';

/** mask width*height con 1 dentro i rettangoli passati. */
const maskWith = (width, height, rects) => {
  const m = new Uint8Array(width * height);
  for (const r of rects)
    for (let y = r.y; y < r.y + r.h; y++)
      for (let x = r.x; x < r.x + r.w; x++) m[y * width + x] = 1;
  return m;
};

/** imageData RGBA da una funzione (x,y)->[r,g,b]. */
const imageFrom = (width, height, fn) => {
  const data = new Uint8ClampedArray(width * height * 4);
  for (let y = 0; y < height; y++)
    for (let x = 0; x < width; x++) {
      const [r, g, b] = fn(x, y);
      const i = (y * width + x) * 4;
      data[i] = r; data[i + 1] = g; data[i + 2] = b; data[i + 3] = 255;
    }
  return { data, width, height };
};

describe('countIslands', () => {
  it('un solo blocco = una isola', () => {
    const m = maskWith(20, 20, [{ x: 4, y: 4, w: 8, h: 8 }]);
    expect(countIslands(m, 20, 20)).toBe(1);
  });

  it('tre blocchi staccati = tre isole', () => {
    const m = maskWith(30, 30, [
      { x: 1, y: 1, w: 5, h: 5 },
      { x: 12, y: 1, w: 5, h: 5 },
      { x: 1, y: 12, w: 5, h: 5 },
    ]);
    expect(countIslands(m, 30, 30)).toBe(3);
  });

  it('ignora granelli sotto minSize', () => {
    const m = maskWith(20, 20, [
      { x: 4, y: 4, w: 8, h: 8 }, // 64 px
      { x: 18, y: 18, w: 1, h: 1 }, // 1 px: rumore
    ]);
    expect(countIslands(m, 20, 20, { minSize: 12 })).toBe(1);
  });
});

describe('textDensity', () => {
  it('una foto liscia ha densità quasi nulla', () => {
    const img = imageFrom(40, 40, () => [150, 160, 170]);
    expect(textDensity(img)).toBeLessThan(0.02);
  });

  it('un pattern fitto bianco/nero (tipo testo) ha densità alta', () => {
    const img = imageFrom(40, 40, (x) => (x % 2 === 0 ? [0, 0, 0] : [255, 255, 255]));
    expect(textDensity(img)).toBeGreaterThan(0.4);
  });
});

describe('classifyGarmentImage (sintetico)', () => {
  it('capo pieno su fondo bianco uniforme = clean', () => {
    // fondo bianco, un rettangolo azzurro liscio al centro
    const img = imageFrom(60, 60, (x, y) =>
      x >= 15 && x < 45 && y >= 15 && y < 45 ? [150, 170, 200] : [255, 255, 255]
    );
    const out = classifyGarmentImage(img);
    expect(out.verdict).toBe('clean');
  });

  it('collage: tante isole sparse su molto sfondo = screenshot', () => {
    // Uno screenshot frammenta il contenuto in molte isole su chrome uniforme.
    // Griglia 6x6 di blocchetti (36 isole) su fondo bianco: isole alte, sfondo alto.
    const img = imageFrom(80, 80, (x, y) => {
      const inBlock = x % 12 < 6 && y % 12 < 6 && x < 72 && y < 72; // 6x6 blocchi 6x6px
      return inBlock ? [40, 60, 90] : [255, 255, 255];
    });
    const out = classifyGarmentImage(img);
    expect(out.verdict).toBe('screenshot');
  });

  it('oggetto su sfondo NON uniforme e senza testo = messy, mai screenshot', () => {
    // sfondo rumoroso (niente flood-fill pulito), un blocco: nessun testo
    const img = imageFrom(60, 60, (x, y) => {
      if (x >= 20 && x < 40 && y >= 20 && y < 40) return [150, 170, 200];
      return [200 + ((x * 7 + y * 13) % 40), 190, 180]; // sfondo variato
    });
    const out = classifyGarmentImage(img);
    expect(out.verdict).not.toBe('screenshot');
  });
});
