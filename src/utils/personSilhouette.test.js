import { describe, it, expect } from 'vitest';
import { alphaBounds, analyzeSilhouette } from './personSilhouette';

/**
 * Silhouette sintetica di una persona in piedi, frontale, braccia lungo i
 * fianchi. ATTENZIONE (vedi memoria "test che non falliscono mai"): niente
 * bordi sfumati qui — l'alpha è 0 o 255. La verifica sui bordi veri la fa
 * la prova a schermo con foto reali.
 *
 * Layout (100×220, coordinate [inclusa..esclusa)):
 *  - testa    y 10..30,  x 40..61
 *  - collo    y 30..36,  x 45..56
 *  - spalle   y 36..50,  x 25..76   (larghezza 51: la riga più larga in alto)
 *  - vita     y 50..90,  x 32..69   (37)
 *  - fianchi  y 90..120, x 28..73   (45)
 *  - gambe    y 120..200, due corse x 32..48 e x 53..69 (cavallo a y=120)
 *  - piedi    y 200..211, due corse x 28..48 e x 53..73
 */
const W = 100;
const H = 220;

const makeImage = (paint) => {
  const data = new Uint8ClampedArray(W * H * 4);
  const setRow = (y, x0, x1, alpha = 255) => {
    for (let x = x0; x < x1; x++) {
      const i = (y * W + x) * 4;
      data[i] = 200;
      data[i + 1] = 180;
      data[i + 2] = 160;
      data[i + 3] = alpha;
    }
  };
  paint(setRow);
  return { width: W, height: H, data };
};

const paintPerson = (setRow, { splitLegs = true } = {}) => {
  for (let y = 10; y < 30; y++) setRow(y, 40, 61);
  for (let y = 30; y < 36; y++) setRow(y, 45, 56);
  for (let y = 36; y < 50; y++) setRow(y, 25, 76);
  for (let y = 50; y < 90; y++) setRow(y, 32, 69);
  for (let y = 90; y < 120; y++) setRow(y, 28, 73);
  for (let y = 120; y < 200; y++) {
    if (splitLegs) {
      setRow(y, 32, 48);
      setRow(y, 53, 69);
    } else {
      setRow(y, 32, 69);
    }
  }
  for (let y = 200; y < 211; y++) {
    if (splitLegs) {
      setRow(y, 28, 48);
      setRow(y, 53, 73);
    } else {
      setRow(y, 28, 73);
    }
  }
};

describe('alphaBounds', () => {
  it('trova il rettangolo dei pixel opachi', () => {
    const image = makeImage((setRow) => paintPerson(setRow));
    const b = alphaBounds(image);
    expect(b).toEqual({ top: 10, bottom: 210, left: 25, right: 75 });
  });

  it('ignora i pixel quasi trasparenti (alone dello scontorno)', () => {
    const image = makeImage((setRow) => {
      setRow(5, 0, 100, 20); // alone sopra la testa, alpha sotto soglia
      paintPerson(setRow);
    });
    expect(alphaBounds(image).top).toBe(10);
  });

  it('è null su un\'immagine tutta trasparente', () => {
    const image = makeImage(() => {});
    expect(alphaBounds(image)).toBeNull();
  });
});

describe('analyzeSilhouette', () => {
  const image = makeImage((setRow) => paintPerson(setRow));
  const person = analyzeSilhouette(image);

  it('è null senza una figura', () => {
    expect(analyzeSilhouette(makeImage(() => {}))).toBeNull();
  });

  it('misura il riquadro della figura', () => {
    expect(person.box).toMatchObject({ top: 10, bottom: 210, left: 25, right: 75 });
    expect(person.box.height).toBe(201);
  });

  it('trova le spalle: la riga più larga nella fascia alta del corpo', () => {
    expect(person.shoulders.y).toBeGreaterThanOrEqual(36);
    expect(person.shoulders.y).toBeLessThan(50);
    expect(person.shoulders.width).toBe(51);
    expect(person.shoulders.cx).toBe(50);
  });

  it('trova i fianchi nella fascia centrale', () => {
    expect(person.hips.y).toBeGreaterThanOrEqual(90);
    expect(person.hips.y).toBeLessThan(120);
    expect(person.hips.width).toBe(45);
  });

  it('trova il cavallo: la prima riga in cui le gambe si separano', () => {
    expect(person.crotchY).toBe(120);
  });

  it('gambe unite (pantaloni larghi, gonna): cavallo stimato a ~53% dell\'altezza', () => {
    const together = analyzeSilhouette(
      makeImage((setRow) => paintPerson(setRow, { splitLegs: false }))
    );
    expect(together.crotchY).toBe(10 + Math.round(0.53 * 201));
  });

  it('caviglie poco sopra il fondo', () => {
    expect(person.ankleY).toBe(210 - Math.round(0.05 * 201));
  });

  it('asse del corpo: media fra centro spalle e centro fianchi', () => {
    expect(person.cx).toBe(50);
  });
});
