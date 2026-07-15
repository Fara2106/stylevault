import { describe, it, expect } from 'vitest';
import {
  garmentPlacements,
  TOP_WIDTH_FACTOR,
  DRESS_WIDTH_FACTOR,
  OUTER_WIDTH_FACTOR,
  BOTTOM_MAX_WIDTH_FACTOR,
} from './modelComposer';

/** Landmark come li produce analyzeSilhouette sulla figura sintetica dei test. */
const person = {
  box: { top: 10, bottom: 210, left: 25, right: 75, width: 51, height: 201 },
  shoulders: { y: 40, left: 25, right: 75, width: 51, cx: 50 },
  hips: { y: 100, left: 28, right: 72, width: 45, cx: 50 },
  crotchY: 120,
  ankleY: 200,
  cx: 50,
};

const H = person.box.height;

describe('garmentPlacements', () => {
  it('senza capi non piazza nulla', () => {
    expect(garmentPlacements(person, {})).toEqual([]);
  });

  it('top: agganciato alle spalle, largo quanto le spalle più le maniche stese', () => {
    const [top] = garmentPlacements(person, { top: { aspect: 1.2 } });
    expect(top.kind).toBe('top');
    const width = person.shoulders.width * TOP_WIDTH_FACTOR;
    expect(top.width).toBeCloseTo(width, 5);
    expect(top.height).toBeCloseTo(width / 1.2, 5);
    expect(top.x).toBeCloseTo(person.cx - width / 2, 5);
    expect(top.y).toBeCloseTo(person.shoulders.y - 0.03 * H, 5);
  });

  it('abito: come il top ma con fattore proprio', () => {
    const [dress] = garmentPlacements(person, { top: { aspect: 0.7, isDress: true } });
    expect(dress.kind).toBe('dress');
    expect(dress.width).toBeCloseTo(person.shoulders.width * DRESS_WIDTH_FACTOR, 5);
  });

  it('pantaloni: dalla vita alle caviglie, larghezza dal rapporto della foto', () => {
    const [bottom] = garmentPlacements(person, { bottom: { aspect: 0.5 } });
    expect(bottom.kind).toBe('bottom');
    const y = person.crotchY - 0.13 * H;
    const height = person.ankleY + 0.02 * H - y;
    expect(bottom.y).toBeCloseTo(y, 5);
    expect(bottom.height).toBeCloseTo(height, 5);
    expect(bottom.width).toBeCloseTo(height * 0.5, 5);
    expect(bottom.x + bottom.width / 2).toBeCloseTo(person.cx, 5);
  });

  it('pantaloni da foto molto larga: larghezza limitata ai fianchi, senza distorcere', () => {
    const [bottom] = garmentPlacements(person, { bottom: { aspect: 2 } });
    const cap = person.hips.width * BOTTOM_MAX_WIDTH_FACTOR;
    expect(bottom.width).toBeCloseTo(cap, 5);
    expect(bottom.height).toBeCloseTo(cap / 2, 5);
    // resta ancorato in basso, alle caviglie
    expect(bottom.y + bottom.height).toBeCloseTo(person.ankleY + 0.02 * H, 5);
  });

  it('capospalla: più largo del top', () => {
    const [outer] = garmentPlacements(person, { outerwear: { aspect: 1 } });
    expect(outer.kind).toBe('outerwear');
    expect(outer.width).toBeCloseTo(person.shoulders.width * OUTER_WIDTH_FACTOR, 5);
  });

  it('scarpe: una per piede, ancorate al fondo della figura', () => {
    const shoes = garmentPlacements(person, { shoes: { aspect: 2 } });
    expect(shoes).toHaveLength(2);
    const height = 0.09 * H;
    for (const shoe of shoes) {
      expect(shoe.kind).toBe('shoes');
      expect(shoe.height).toBeCloseTo(height, 5);
      expect(shoe.width).toBeCloseTo(height * 2, 5);
      expect(shoe.y + shoe.height).toBeCloseTo(person.box.bottom + 0.01 * H, 5);
    }
    const centers = shoes.map((s) => s.x + s.width / 2).sort((a, b) => a - b);
    expect(centers[0]).toBeCloseTo(person.cx - person.hips.width * 0.22, 5);
    expect(centers[1]).toBeCloseTo(person.cx + person.hips.width * 0.22, 5);
  });

  it('ordine di pittura: bottom, top, capospalla, scarpe', () => {
    const kinds = garmentPlacements(person, {
      top: { aspect: 1 },
      bottom: { aspect: 0.5 },
      outerwear: { aspect: 1 },
      shoes: { aspect: 2 },
    }).map((p) => p.kind);
    expect(kinds).toEqual(['bottom', 'top', 'outerwear', 'shoes', 'shoes']);
  });
});
