import { describe, it, expect } from 'vitest';
import { buildShopLinks, buildShopLink } from './shopLinks';

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
  it('make-up IT: Notino e Amazon (deep-link verificati sul campo)', () => {
    const links = buildShopLinks({ kind: 'makeup', query: 'rossetto corallo', lang: 'it' });
    expect(links.map((l) => l.shop)).toEqual(['notino', 'amazon']);
    expect(links[0].url).toBe('https://www.notino.it/search.asp?exps=rossetto%20corallo');
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

describe('buildShopLink', () => {
  it('Zara IT con query codificata', () => {
    expect(buildShopLink({ shop: 'zara', query: 'maglietta pesca', lang: 'it' })).toEqual({
      shop: 'zara',
      label: 'Zara',
      url: 'https://www.zara.com/it/it/search?searchTerm=maglietta%20pesca',
    });
  });
  it('H&M IT e Zalando EN', () => {
    expect(buildShopLink({ shop: 'hm', query: 'pantaloni crema', lang: 'it' }).url).toBe(
      'https://www2.hm.com/it_it/search-results.html?q=pantaloni%20crema'
    );
    expect(buildShopLink({ shop: 'zalando', query: 'peach t-shirt', lang: 'en' }).url).toBe(
      'https://www.zalando.co.uk/catalog/?q=peach%20t-shirt'
    );
  });
  it('shop ignoto → null; lingua ignota → ripiego it', () => {
    expect(buildShopLink({ shop: 'boh', query: 'x', lang: 'it' })).toBeNull();
    expect(buildShopLink({ shop: 'zara', query: 'x', lang: 'de' }).url).toContain('zara.com/it/it');
  });
});
