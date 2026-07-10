import { describe, it, expect } from 'vitest';
import { backgroundMask, BG_TOLERANCE, garmentBounds, dominantColor, extractGarment, fabricSwatch, printRegion, printPlacement } from './garmentTexture';

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

describe('garmentBounds', () => {
  it('trova il rettangolo che contiene il capo', () => {
    const img = makeImage(10, 10, WHITE, BLUE, { x: 3, y: 2, width: 4, height: 5 });
    const bounds = garmentBounds(backgroundMask(img), 10, 10);
    expect(bounds).toEqual({ x: 3, y: 2, width: 4, height: 5 });
  });

  it('restituisce null se non c\'è nessun pixel di capo', () => {
    const img = makeImage(5, 5, WHITE, WHITE, null);
    expect(garmentBounds(backgroundMask(img), 5, 5)).toBeNull();
  });
});

describe('dominantColor', () => {
  it('ignora lo sfondo e restituisce il colore del capo', () => {
    // sfondo bianco largo, capo blu piccolo: senza maschera vincerebbe il bianco
    const img = makeImage(10, 10, WHITE, BLUE, { x: 4, y: 4, width: 2, height: 2 });
    const mask = backgroundMask(img);
    expect(dominantColor(img, mask)).toBe('#284f7f');
  });

  it('senza maschera considera tutti i pixel', () => {
    const img = makeImage(10, 10, WHITE, BLUE, { x: 4, y: 4, width: 2, height: 2 });
    expect(dominantColor(img, null)).toBe('#ffffff');
  });
});

describe('extractGarment', () => {
  it('riesce su una foto normale: sfondo uniforme, capo al centro', () => {
    const img = makeImage(10, 10, WHITE, BLUE, { x: 3, y: 3, width: 4, height: 4 });
    const out = extractGarment(img);
    expect(out.ok).toBe(true);
    expect(out.bounds).toEqual({ x: 3, y: 3, width: 4, height: 4 });
    expect(out.dominantHex).toBe('#284f7f');
    expect(out.coverage).toBeCloseTo(0.16, 5);
  });

  it('degrada se lo sfondo non viene trovato (quasi tutto è "capo")', () => {
    // Ogni pixel diverso dal vicino oltre la tolleranza: il riempimento non parte.
    const width = 10;
    const height = 10;
    const data = new Uint8ClampedArray(width * height * 4);
    for (let p = 0; p < width * height; p++) {
      const i = p * 4;
      data[i] = (p * 97) % 256;
      data[i + 1] = (p * 57) % 256;
      data[i + 2] = (p * 31) % 256;
      data[i + 3] = 255;
    }
    const out = extractGarment({ data, width, height });
    expect(out.ok).toBe(false);
    expect(out.bounds).toBeNull();
    expect(out.dominantHex).toMatch(/^#[0-9a-f]{6}$/);
  });

  it('degrada se non trova nessun capo', () => {
    const img = makeImage(10, 10, WHITE, WHITE, null);
    const out = extractGarment(img);
    expect(out.ok).toBe(false);
    expect(out.bounds).toBeNull();
    expect(out.dominantHex).toBe('#ffffff');
  });
});

const RED = [200, 40, 40];

describe('fabricSwatch', () => {
  it('sta tutto dentro il capo, mai sui bordi', () => {
    const img = makeImage(20, 20, WHITE, BLUE, { x: 5, y: 5, width: 10, height: 10 });
    const mask = backgroundMask(img);
    const bounds = garmentBounds(mask, 20, 20);
    const s = fabricSwatch(mask, 20, 20, bounds);

    expect(s).not.toBeNull();
    for (let y = s.y; y < s.y + s.height; y++) {
      for (let x = s.x; x < s.x + s.width; x++) {
        expect(mask[y * 20 + x]).toBe(1); // ogni pixel della piastrella è capo
      }
    }
  });

  it('restituisce null se il capo è troppo sottile per contenere un quadrato', () => {
    // striscia alta 1 pixel: nessun quadrato di lato >= 2 ci sta dentro
    const img = makeImage(20, 20, WHITE, BLUE, { x: 2, y: 10, width: 16, height: 1 });
    const mask = backgroundMask(img);
    const bounds = garmentBounds(mask, 20, 20);
    expect(fabricSwatch(mask, 20, 20, bounds)).toBeNull();
  });

  it('non prende mai il tessuto dove c’è la stampa', () => {
    // Se la piastrella contiene il logo, il logo viene ripetuto su tutto il capo
    // come una fantasia a pois. È il difetto visto a schermo il 2026-07-10.
    const img = makeImage(40, 40, WHITE, BLUE, { x: 4, y: 4, width: 32, height: 32 });
    const mask = backgroundMask(img);
    const bounds = garmentBounds(mask, 40, 40);
    const print = { x: 14, y: 14, width: 12, height: 12 }; // logo al centro

    const s = fabricSwatch(mask, 40, 40, bounds, print);

    expect(s).not.toBeNull();
    const sovrapposti =
      Math.max(s.x, print.x) < Math.min(s.x + s.width, print.x + print.width) &&
      Math.max(s.y, print.y) < Math.min(s.y + s.height, print.y + print.height);
    expect(sovrapposti).toBe(false);
  });

  it('trova comunque il tessuto quando la stampa occupa il centro del capo', () => {
    // Capo 44x44, stampa 20x20 al centro: il tessuto buono resta solo nelle
    // fasce laterali. Cercarlo solo al centro non basta.
    const img = makeImage(60, 60, WHITE, BLUE, { x: 8, y: 8, width: 44, height: 44 });
    const mask = backgroundMask(img);
    const bounds = garmentBounds(mask, 60, 60);
    const print = { x: 20, y: 20, width: 20, height: 20 };

    const s = fabricSwatch(mask, 60, 60, bounds, print);

    expect(s).not.toBeNull();
    expect(s.width).toBeGreaterThanOrEqual(4);
    const sovrapposti =
      Math.max(s.x, print.x) < Math.min(s.x + s.width, print.x + print.width) &&
      Math.max(s.y, print.y) < Math.min(s.y + s.height, print.y + print.height);
    expect(sovrapposti).toBe(false);
  });
});

describe('printRegion con il bordo sfumato delle foto vere', () => {
  it('trova la stampa anche se il capo ha un anello antialiasato', () => {
    // Ogni foto reale ha, fra capo e sfondo, un anello di pixel sfumati: colori
    // lontanissimi dal dominante, ma dentro la maschera. La vecchia regola
    // "se un pixel di stampa tocca il bordo rinuncio" scattava sempre, e
    // nessuna stampa veniva mai trovata su una foto vera.
    const img = makeImage(40, 40, WHITE, BLUE, { x: 6, y: 6, width: 28, height: 28 });

    // anello di 1 pixel a mezza tinta lungo tutto il contorno del capo
    const MID = [128, 148, 168];
    for (let y = 6; y < 34; y++) {
      for (let x = 6; x < 34; x++) {
        const bordo = x === 6 || y === 6 || x === 33 || y === 33;
        if (!bordo) continue;
        const i = (y * 40 + x) * 4;
        img.data[i] = MID[0];
        img.data[i + 1] = MID[1];
        img.data[i + 2] = MID[2];
      }
    }
    // stampa rossa 6x6 al centro
    for (let y = 17; y < 23; y++) {
      for (let x = 17; x < 23; x++) {
        const i = (y * 40 + x) * 4;
        img.data[i] = RED[0];
        img.data[i + 1] = RED[1];
        img.data[i + 2] = RED[2];
      }
    }

    const mask = backgroundMask(img);
    const r = printRegion(img, mask, '#284f7f');
    expect(r).toEqual({ x: 17, y: 17, width: 6, height: 6 });
  });
});

describe('backgroundMask, righe chiare sul bordo del capo', () => {
  it('non si mangia le righe che sfiorano il colore dello sfondo', () => {
    // Maglietta verde a righe chiare: le righe distano 32 dallo sfondo e toccano
    // il bordo del capo. Con una tolleranza larga il riempimento entrava dai
    // lati e le cancellava, e il capo usciva in tinta unita.
    const GREEN = [31, 111, 92];
    const STRIPE = [232, 226, 208];
    const BG = [240, 240, 240];
    const img = makeImage(30, 30, BG, GREEN, { x: 5, y: 5, width: 20, height: 20 });
    for (let y = 5; y < 25; y++) {
      if ((y - 5) % 4 !== 0) continue;
      for (let x = 5; x < 25; x++) {
        const i = (y * 30 + x) * 4;
        img.data[i] = STRIPE[0];
        img.data[i + 1] = STRIPE[1];
        img.data[i + 2] = STRIPE[2];
      }
    }
    const mask = backgroundMask(img);
    // il centro di una riga chiara resta capo, non diventa sfondo
    expect(mask[9 * 30 + 15]).toBe(1);
    // e la piastrella esiste: senza righe nella maschera non ci starebbe
    const bounds = garmentBounds(mask, 30, 30);
    expect(fabricSwatch(mask, 30, 30, bounds, null)).not.toBeNull();
  });
});

describe('printRegion', () => {
  it('trova la stampa: una macchia rossa dentro un capo blu', () => {
    const img = makeImage(20, 20, WHITE, BLUE, { x: 2, y: 2, width: 16, height: 16 });
    // stampa 4x4 al centro
    for (let y = 8; y < 12; y++) {
      for (let x = 8; x < 12; x++) {
        const i = (y * 20 + x) * 4;
        img.data[i] = RED[0]; img.data[i + 1] = RED[1]; img.data[i + 2] = RED[2];
      }
    }
    const mask = backgroundMask(img);
    const r = printRegion(img, mask, '#284f7f');
    expect(r).toEqual({ x: 8, y: 8, width: 4, height: 4 });
  });

  it('non scambia per stampa un capo in tinta unita', () => {
    const img = makeImage(20, 20, WHITE, BLUE, { x: 2, y: 2, width: 16, height: 16 });
    const mask = backgroundMask(img);
    expect(printRegion(img, mask, '#284f7f')).toBeNull();
  });

  it('non scambia per stampa una macchia che occupa quasi tutto il capo', () => {
    const img = makeImage(20, 20, WHITE, BLUE, { x: 2, y: 2, width: 16, height: 16 });
    for (let y = 3; y < 17; y++) {
      for (let x = 3; x < 17; x++) {
        const i = (y * 20 + x) * 4;
        img.data[i] = RED[0]; img.data[i + 1] = RED[1]; img.data[i + 2] = RED[2];
      }
    }
    const mask = backgroundMask(img);
    expect(printRegion(img, mask, '#284f7f')).toBeNull(); // >25% dell'area
  });

  it('non scambia per stampa una zona attaccata al bordo del capo', () => {
    const img = makeImage(20, 20, WHITE, BLUE, { x: 2, y: 2, width: 16, height: 16 });
    // striscia rossa lungo il bordo sinistro del capo: e' un orlo, non una stampa
    for (let y = 2; y < 18; y++) {
      const i = (y * 20 + 2) * 4;
      img.data[i] = RED[0]; img.data[i + 1] = RED[1]; img.data[i + 2] = RED[2];
    }
    const mask = backgroundMask(img);
    expect(printRegion(img, mask, '#284f7f')).toBeNull();
  });
});

describe('printPlacement', () => {
  // Capo: rettangolo x 10..109, y 20..219 (100 x 200).
  const bounds = { x: 10, y: 20, width: 100, height: 200 };

  it('una stampa al centro esatto risulta al centro', () => {
    // stampa 20x20 centrata: centro (60, 120)
    const p = printPlacement(bounds, { x: 50, y: 110, width: 20, height: 20 });
    expect(p.cx).toBeCloseTo(0.5, 6);
    expect(p.cy).toBeCloseTo(0.5, 6);
    expect(p.w).toBeCloseTo(0.2, 6); // 20/100
    expect(p.h).toBeCloseTo(0.1, 6); // 20/200
  });

  it('un logo sul taschino resta in alto a sinistra, non al centro', () => {
    // stampa 10x10 con angolo (20, 40): centro (25, 45)
    const p = printPlacement(bounds, { x: 20, y: 40, width: 10, height: 10 });
    expect(p.cx).toBeCloseTo(0.15, 6); // (25-10)/100
    expect(p.cy).toBeCloseTo(0.125, 6); // (45-20)/200
    expect(p.cx).toBeLessThan(0.5);
    expect(p.cy).toBeLessThan(0.5);
  });

  it('una scritta sull’orlo basso resta in basso', () => {
    const p = printPlacement(bounds, { x: 40, y: 200, width: 30, height: 10 });
    expect(p.cy).toBeCloseTo(0.925, 6); // (205-20)/200
    expect(p.cy).toBeGreaterThan(0.8);
  });

  it('senza stampa o senza capo non c’è collocazione', () => {
    expect(printPlacement(bounds, null)).toBeNull();
    expect(printPlacement(null, { x: 1, y: 1, width: 1, height: 1 })).toBeNull();
  });
});
