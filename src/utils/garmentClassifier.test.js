import { describe, it, expect } from 'vitest';
import { countIslands } from './garmentClassifier';

/** mask width*height con 1 dentro i rettangoli passati. */
const maskWith = (width, height, rects) => {
  const m = new Uint8Array(width * height);
  for (const r of rects)
    for (let y = r.y; y < r.y + r.h; y++)
      for (let x = r.x; x < r.x + r.w; x++) m[y * width + x] = 1;
  return m;
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
