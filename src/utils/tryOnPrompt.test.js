import { describe, it, expect } from 'vitest';
import { garmentDescriptor, buildTryOnPrompt, hasSwimwear } from './tryOnPrompt';

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
  it('spiega che le foto possono arrivare come provino unico numerato', () => {
    expect(buildTryOnPrompt(items)).toMatch(/single numbered contact sheet/i);
  });
});

describe('hasSwimwear', () => {
  it('riconosce il costume dal nome, in italiano e in inglese', () => {
    expect(hasSwimwear([{ name: 'Costume intero blu', category: 'underwear' }])).toBe(true);
    expect(hasSwimwear([{ name: 'COSTUMI mare', category: 'custom_1' }])).toBe(true);
    expect(hasSwimwear([{ name: 'Bikini a righe', category: 'tops' }])).toBe(true);
    expect(hasSwimwear([{ name: 'Black swimsuit', category: 'underwear' }])).toBe(true);
    expect(hasSwimwear([{ name: 'Pantaloncini da bagno', category: 'bottoms' }])).toBe(true);
  });
  it('basta un capo fra quelli scelti', () => {
    expect(hasSwimwear([{ name: 'Camicia', category: 'tops' }, { name: 'Tankini', category: 'tops' }])).toBe(true);
  });
  it('gli altri capi non fanno scattare il consiglio', () => {
    expect(hasSwimwear([{ name: 'Camicia di lino', category: 'tops' }])).toBe(false);
    expect(hasSwimwear([{ name: 'Accostumato', category: 'tops' }])).toBe(false);
    expect(hasSwimwear([{ category: 'tops' }])).toBe(false);
    expect(hasSwimwear([])).toBe(false);
  });
  it('scarpe e accessori non sono costumi, anche se il nome lo dice', () => {
    expect(hasSwimwear([{ name: 'Costume jewelry', category: 'accessories' }])).toBe(false);
    expect(hasSwimwear([{ name: 'Sandali da bagno', category: 'shoes' }])).toBe(false);
  });
});
