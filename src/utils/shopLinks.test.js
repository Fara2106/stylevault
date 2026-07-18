import { describe, it, expect } from 'vitest';
import { buildShopLinks, buildOutfitLinks } from './shopLinks';

describe('buildShopLinks', () => {
  it('abbigliamento IT: Zalando, Asos, Amazon con query codificata', () => {
    const links = buildShopLinks({ kind: 'clothing', query: 'maglione bordeaux', lang: 'it' });
    expect(links.map((l) => l.shop)).toEqual(['zalando', 'asos', 'amazon']);
    expect(links[0].url).toBe('https://www.zalando.it/catalogo/?q=maglione%20bordeaux');
    expect(links[2].url).toBe('https://www.amazon.it/s?k=maglione%20bordeaux');
  });
  it('abbigliamento EN: domini internazionali', () => {
    const links = buildShopLinks({ kind: 'clothing', query: 'burgundy sweater', lang: 'en' });
    expect(links[0].url).toContain('zalando.co.uk');
    expect(links[2].url).toContain('amazon.com');
  });
  it('make-up IT: Sephora, Douglas, Amazon', () => {
    const links = buildShopLinks({ kind: 'makeup', query: 'rossetto corallo', lang: 'it' });
    expect(links.map((l) => l.shop)).toEqual(['sephora', 'douglas', 'amazon']);
    expect(links[0].url).toBe('https://www.sephora.it/ricerca?q=rossetto%20corallo');
  });
  it("l'encoding gestisce accenti e simboli", () => {
    const [l] = buildShopLinks({ kind: 'clothing', query: 'très & chic', lang: 'it' });
    expect(l.url).toContain('tr%C3%A8s%20%26%20chic');
  });
  it('lingua ignota → ripiego su it', () => {
    const links = buildShopLinks({ kind: 'clothing', query: 'x', lang: 'de' });
    expect(links[0].url).toContain('zalando.it');
  });
});

describe('buildOutfitLinks', () => {
  it("IT: cerca il coordinato nel colore guida sugli shop abbigliamento", () => {
    const links = buildOutfitLinks({ colorName: 'bordeaux', lang: 'it' });
    expect(links.map((l) => l.shop)).toEqual(['zalando', 'asos', 'amazon']);
    expect(links[0].url).toBe('https://www.zalando.it/catalogo/?q=coordinato%20bordeaux');
  });
  it('EN: usa il termine co-ord', () => {
    const [l] = buildOutfitLinks({ colorName: 'burgundy', lang: 'en' });
    expect(l.url).toBe('https://www.zalando.co.uk/catalog/?q=co-ord%20burgundy');
  });
  it('lingua ignota → ripiego su it', () => {
    const [l] = buildOutfitLinks({ colorName: 'x', lang: 'de' });
    expect(l.url).toContain('zalando.it');
    expect(l.url).toContain('coordinato%20x');
  });
});
