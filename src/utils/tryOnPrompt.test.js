import { describe, it, expect } from 'vitest';
import { garmentDescriptor, buildTryOnPrompt } from './tryOnPrompt';

describe('garmentDescriptor', () => {
  it('unisce colore inglese e capo', () => {
    expect(garmentDescriptor({ subcategory: 'shirt', colors: ['white'] }))
      .toBe('white button-up shirt');
  });
  it('denim usa la parola blu', () => {
    expect(garmentDescriptor({ subcategory: 'jeans', colors: ['denim'] }))
      .toBe('denim-blue jeans');
  });
  it('colore sconosciuto: solo il capo', () => {
    expect(garmentDescriptor({ subcategory: 'sneakers', colors: ['fuxia'] }))
      .toBe('sneakers');
  });
  it('sotto-categoria sconosciuta: ripiego sul nome', () => {
    expect(garmentDescriptor({ subcategory: 'zzz', colors: ['black'], name: 'Kimono' }))
      .toBe('black Kimono');
  });
});

describe('buildTryOnPrompt', () => {
  const items = [
    { subcategory: 'shirt', colors: ['white'] },
    { subcategory: 'trousers', colors: ['navy'] },
    { subcategory: 'sneakers', colors: ['white'] },
  ];
  it('numera i capi partendo da Image 2', () => {
    const p = buildTryOnPrompt(items);
    expect(p).toContain('1. white button-up shirt (Image 2)');
    expect(p).toContain('2. navy-blue trousers (Image 3)');
    expect(p).toContain('3. white sneakers (Image 4)');
  });
  it('preserva identità e chiede solo la foto finale', () => {
    const p = buildTryOnPrompt(items);
    expect(p).toMatch(/preserve their exact face/i);
    expect(p).toMatch(/return only the final edited photograph/i);
  });
  it('senza capi non lancia e resta valido', () => {
    expect(() => buildTryOnPrompt([])).not.toThrow();
    expect(buildTryOnPrompt([])).toMatch(/photorealistic virtual try-on/i);
  });
});
