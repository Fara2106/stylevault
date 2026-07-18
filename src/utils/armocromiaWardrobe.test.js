import { describe, it, expect } from 'vitest';
import { matchWardrobe, IN_PALETTE_MAX } from './armocromiaWardrobe';

const item = (id, colors) => ({ id, name: id, colors });

describe('matchWardrobe', () => {
  it('un capo bordeaux entra nella palette deep-winter, uno arancio no', () => {
    const res = matchWardrobe([item('a', ['burgundy']), item('b', ['orange'])], 'deep-winter');
    expect(res.map((r) => r.item.id)).toEqual(['a']);
    expect(res[0].distance).toBeLessThanOrEqual(IN_PALETTE_MAX);
    expect(res[0].itemHex).toBeTruthy();
    expect(res[0].paletteHex).toBeTruthy();
  });
  it('ordina per distanza crescente', () => {
    const res = matchWardrobe(
      [item('lontano', ['navy']), item('vicino', ['burgundy'])],
      'deep-winter'
    );
    expect(res.length).toBe(2);
    expect(res[0].distance).toBeLessThanOrEqual(res[1].distance);
  });
  it('capi senza colori o con id ignoti si saltano; stagione ignota → []', () => {
    expect(matchWardrobe([item('x', []), item('y', ['colore-inventato'])], 'deep-winter')).toEqual([]);
    expect(matchWardrobe([item('a', ['burgundy'])], 'stagione-finta')).toEqual([]);
  });
});
