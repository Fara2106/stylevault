import { describe, it, expect } from 'vitest';
import { backgroundMask, BG_TOLERANCE } from './garmentTexture';

/** Costruisce un'immagine RGBA piena di `bg`, con un rettangolo di `fg`. */
const makeImage = (width, height, bg, fg, rect) => {
  const data = new Uint8ClampedArray(width * height * 4);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const inRect =
        rect &&
        x >= rect.x &&
        x < rect.x + rect.width &&
        y >= rect.y &&
        y < rect.y + rect.height;
      const [r, g, b] = inRect ? fg : bg;
      const i = (y * width + x) * 4;
      data[i] = r;
      data[i + 1] = g;
      data[i + 2] = b;
      data[i + 3] = 255;
    }
  }
  return { data, width, height };
};

const WHITE = [255, 255, 255];
const BLUE = [40, 79, 127];

describe('backgroundMask', () => {
  it('marca come capo solo il rettangolo centrale su sfondo uniforme', () => {
    const img = makeImage(10, 10, WHITE, BLUE, { x: 3, y: 3, width: 4, height: 4 });
    const mask = backgroundMask(img);

    expect(mask).toHaveLength(100);
    expect(mask[0]).toBe(0); // angolo = sfondo
    expect(mask[4 * 10 + 4]).toBe(1); // centro = capo
    expect(mask.reduce((a, b) => a + b, 0)).toBe(16); // 4x4
  });

  it('tollera un lieve rumore sullo sfondo entro la soglia', () => {
    const img = makeImage(6, 6, [250, 250, 250], BLUE, { x: 2, y: 2, width: 2, height: 2 });
    // un pixel di sfondo leggermente diverso, ma dentro la tolleranza
    img.data[(0 * 6 + 3) * 4] = 250 - (BG_TOLERANCE - 5);
    const mask = backgroundMask(img);
    expect(mask[0 * 6 + 3]).toBe(0);
    expect(mask.reduce((a, b) => a + b, 0)).toBe(4);
  });

  it("non considera sfondo un'area del colore dello sfondo ma isolata dai bordi", () => {
    // Una "tasca" bianca dentro il capo resta parte del capo: non tocca i bordi.
    const img = makeImage(9, 9, WHITE, BLUE, { x: 2, y: 2, width: 5, height: 5 });
    const i = (4 * 9 + 4) * 4;
    img.data[i] = 255;
    img.data[i + 1] = 255;
    img.data[i + 2] = 255;
    const mask = backgroundMask(img);
    expect(mask[4 * 9 + 4]).toBe(1);
  });

  it("restituisce tutto sfondo se l'immagine è di un solo colore", () => {
    const img = makeImage(5, 5, WHITE, WHITE, null);
    const mask = backgroundMask(img);
    expect(mask.reduce((a, b) => a + b, 0)).toBe(0);
  });
});
