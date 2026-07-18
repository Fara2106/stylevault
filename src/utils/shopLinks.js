/**
 * Link di RICERCA agli shop (niente deep-link a filtri fragili): query
 * testuale localizzata → URL stabile. Nessuna API, nessun costo.
 */
const SHOPS = {
  clothing: {
    it: [
      { shop: 'zalando', label: 'Zalando', base: 'https://www.zalando.it/catalogo/?q=' },
      { shop: 'asos', label: 'ASOS', base: 'https://www.asos.com/it/search/?q=' },
      { shop: 'amazon', label: 'Amazon', base: 'https://www.amazon.it/s?k=' },
    ],
    en: [
      { shop: 'zalando', label: 'Zalando', base: 'https://www.zalando.co.uk/catalog/?q=' },
      { shop: 'asos', label: 'ASOS', base: 'https://www.asos.com/search/?q=' },
      { shop: 'amazon', label: 'Amazon', base: 'https://www.amazon.com/s?k=' },
    ],
  },
  makeup: {
    it: [
      { shop: 'sephora', label: 'Sephora', base: 'https://www.sephora.it/ricerca?q=' },
      { shop: 'douglas', label: 'Douglas', base: 'https://www.douglas.it/it/search?query=' },
      { shop: 'amazon', label: 'Amazon', base: 'https://www.amazon.it/s?k=' },
    ],
    en: [
      { shop: 'sephora', label: 'Sephora', base: 'https://www.sephora.com/search?keyword=' },
      { shop: 'amazon', label: 'Amazon', base: 'https://www.amazon.com/s?k=' },
    ],
  },
};

export function buildShopLinks({ kind, query, lang }) {
  const byLang = SHOPS[kind] || SHOPS.clothing;
  const shops = byLang[lang] || byLang.it;
  const q = encodeURIComponent(query).replace(/\+/g, '%20');
  return shops.map(({ shop, label, base }) => ({ shop, label, url: base + q }));
}
