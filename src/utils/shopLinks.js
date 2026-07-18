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

/**
 * Shop per i suggerimenti outfit "un capo → un negozio": include anche i
 * fast-fashion (Zara, Bershka) che non stanno nel giro dei link per colore.
 */
const SINGLE_SHOPS = {
  zara: {
    label: 'Zara',
    it: 'https://www.zara.com/it/it/search?searchTerm=',
    en: 'https://www.zara.com/uk/en/search?searchTerm=',
  },
  bershka: {
    label: 'Bershka',
    it: 'https://www.bershka.com/it/search?q=',
    en: 'https://www.bershka.com/gb/search?q=',
  },
  zalando: {
    label: 'Zalando',
    it: 'https://www.zalando.it/catalogo/?q=',
    en: 'https://www.zalando.co.uk/catalog/?q=',
  },
  asos: {
    label: 'ASOS',
    it: 'https://www.asos.com/it/search/?q=',
    en: 'https://www.asos.com/search/?q=',
  },
};

/** Un solo link a UNO shop preciso. null se lo shop non è tra i previsti. */
export function buildShopLink({ shop, query, lang }) {
  const entry = SINGLE_SHOPS[shop];
  if (!entry) return null;
  const base = entry[lang] || entry.it;
  const q = encodeURIComponent(query).replace(/\+/g, '%20');
  return { shop, label: entry.label, url: base + q };
}
