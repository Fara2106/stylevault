/**
 * Costruzione del prompt di try-on da copiare in Gemini/ChatGPT.
 * Puro: nessun DOM, nessuna rete. Il prompt è in inglese (rende meglio coi
 * modelli immagine); le istruzioni nella UI restano nella lingua dell'app.
 */

/** Colore (id come in categories.js CLOTHING_COLORS) → parola inglese. */
const COLOR_EN = {
  black: 'black', white: 'white', gray: 'gray', navy: 'navy-blue', blue: 'blue',
  lightblue: 'light-blue', red: 'red', burgundy: 'burgundy', pink: 'pink',
  green: 'green', olive: 'olive-green', brown: 'brown', tan: 'tan', beige: 'beige',
  cream: 'cream', yellow: 'yellow', orange: 'orange', purple: 'purple',
  lavender: 'lavender', coral: 'coral', gold: 'gold', silver: 'silver',
  denim: 'denim-blue', khaki: 'khaki',
};

/** Sotto-categoria (id come in categories.js) → sostantivo inglese del capo. */
const SUBCATEGORY_EN = {
  tshirt: 't-shirt', shirt: 'button-up shirt', hoodie: 'hoodie', sweater: 'sweater',
  tank: 'tank top', polo: 'polo shirt', croptop: 'crop top', blouse: 'blouse',
  jeans: 'jeans', trousers: 'trousers', shorts: 'shorts', skirt: 'skirt',
  joggers: 'joggers', leggings: 'leggings', dresspants: 'dress trousers',
  jacket: 'jacket', coat: 'coat', puffer: 'puffer jacket', blazer: 'blazer',
  trench: 'trench coat', vest: 'vest', raincoat: 'raincoat', cardigan: 'cardigan',
  shortdress: 'short dress', longdress: 'long dress', jumpsuit: 'jumpsuit',
  eveningdress: 'evening dress',
  sneakers: 'sneakers', boots: 'boots', loafers: 'loafers', sandals: 'sandals',
  heels: 'heels', ankleboots: 'ankle boots', pumps: 'pumps',
  hat: 'hat', scarf: 'scarf', belt: 'belt', bag: 'bag', sunglasses: 'sunglasses',
  jewelry: 'jewelry',
};

export function garmentDescriptor(item) {
  const noun = SUBCATEGORY_EN[item.subcategory] || item.name || 'garment';
  const colorId = Array.isArray(item.colors) ? item.colors[0] : undefined;
  const color = COLOR_EN[colorId];
  return color ? `${color} ${noun}` : noun;
}
