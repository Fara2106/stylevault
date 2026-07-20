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
  // Solo shop coi deep-link di ricerca VERIFICATI sul campo (2026-07-19):
  // Sephora e Douglas hanno la ricerca solo in overlay (niente URL con query).
  makeup: {
    it: [
      { shop: 'notino', label: 'Notino', base: 'https://www.notino.it/search.asp?exps=' },
      { shop: 'amazon', label: 'Amazon', base: 'https://www.amazon.it/s?k=' },
    ],
    en: [
      { shop: 'notino', label: 'Notino', base: 'https://www.notino.co.uk/search.asp?exps=' },
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
  hm: {
    label: 'H&M',
    it: 'https://www2.hm.com/it_it/search-results.html?q=',
    en: 'https://www2.hm.com/en_gb/search-results.html?q=',
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

/**
 * Shop richiesti da Lorenzo ma SENZA deep-link di ricerca (verificato sul
 * campo 2026-07-19: la loro ricerca vive in un overlay e l'URL non porta la
 * query — Bershka rimbalza in home, Sephora /ricerca dà 404, Douglas 403).
 * Si linka la home verificata: lì l'utente cerca il colore a mano.
 */
const HOME_SHOPS = {
  clothing: [
    { shop: 'bershka', label: 'Bershka', it: 'https://www.bershka.com/it/', en: 'https://www.bershka.com/gb/' },
  ],
  makeup: [
    { shop: 'sephora', label: 'Sephora', it: 'https://www.sephora.it/', en: 'https://www.sephora.com/' },
    { shop: 'douglas', label: 'Douglas', it: 'https://www.douglas.it/', en: 'https://www.douglas.de/' },
  ],
};

/** Link alla home degli shop senza ricerca linkabile, per categoria. */
export function buildHomeLinks({ kind, lang }) {
  const shops = HOME_SHOPS[kind] || [];
  return shops.map(({ shop, label, ...urls }) => ({
    shop,
    label,
    url: urls[lang] || urls.it,
  }));
}

/** Un solo link a UNO shop preciso. null se lo shop non è tra i previsti. */
export function buildShopLink({ shop, query, lang }) {
  const entry = SINGLE_SHOPS[shop];
  if (!entry) return null;
  const base = entry[lang] || entry.it;
  const q = encodeURIComponent(query).replace(/\+/g, '%20');
  return { shop, label: entry.label, url: base + q };
}
