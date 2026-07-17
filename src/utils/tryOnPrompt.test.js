import { describe, it, expect } from 'vitest';
import { garmentDescriptor } from './tryOnPrompt';

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
