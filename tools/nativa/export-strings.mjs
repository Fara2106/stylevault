// Genera i String Catalog dell'app nativa dai testi del sito (it.json, en.json) e da strings-native.json.
// Il catalogo è generato: non va modificato a mano, si rilancia lo script.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const read = (p) => JSON.parse(readFileSync(resolve(here, p), 'utf8'));
const site = { it: read('../../src/i18n/it.json'), en: read('../../src/i18n/en.json') };
const extra = read('./strings-native.json');
const outDir = resolve(here, '../../ios/StyleVaultNative/Resources');

const GROUPS = ['nav', 'categories', 'subcategories', 'seasons', 'occasions', 'colors'];
const PROFILE_KEYS = ['settings', 'defaultCity', 'language', 'theme', 'themeLight', 'themeDark', 'themeSystem'];
const PICKED = {
  wardrobe: ['title', 'emptyState', 'emptyAction', 'deleteConfirm', 'searchPlaceholder', 'tabWardrobe', 'tabWishlist'],
  wishlist: ['title', 'subtitle', 'bought', 'emptyState', 'emptyAction', 'moveToWardrobe', 'openLink'],
  addItem: [
    'title', 'photo', 'link', 'uploadPhoto', 'takePhoto', 'pasteLink', 'analyzeLink', 'itemName', 'category',
    'subcategory', 'brand', 'size', 'colors', 'season', 'occasion', 'warmth', 'photoHint', 'changePhoto', 'price',
    'destination', 'toWardrobe', 'toWishlist', 'linkLoading', 'linkError', 'linkSuccess', 'nameRequired',
    'categoryRequired', 'photoBack', 'photoBackHint', 'photoBackAdd', 'photoBackRemove',
    'warmthLevels.1', 'warmthLevels.2', 'warmthLevels.3', 'warmthLevels.4', 'warmthLevels.5',
  ],
  itemDetail: ['title', 'openShop', 'deleteItem'],
  common: ['save', 'cancel', 'delete', 'edit', 'close', 'all', 'favorites', 'noResults', 'optional'],
};

const wanted = [];
for (const g of GROUPS) for (const k of Object.keys(site.it[g])) wanted.push(`${g}.${k}`);
for (const k of PROFILE_KEYS) wanted.push(`profile.${k}`);
for (const [g, keys] of Object.entries(PICKED)) for (const k of keys) wanted.push(`${g}.${k}`);

const lookup = (lang, key) => key.split('.').reduce((o, p) => o?.[p], site[lang]);
const entries = {};
for (const key of wanted) {
  const it = lookup('it', key);
  const en = lookup('en', key);
  if (typeof it !== 'string' || typeof en !== 'string') throw new Error(`Testo mancante nel sito: ${key}`);
  entries[key] = { it, en };
}
for (const [key, v] of Object.entries(extra)) {
  if (entries[key]) throw new Error(`Chiave doppia: ${key}`);
  entries[key] = v;
}

// Un testo è una stringa, oppure { one, other } per il plurale.
const unit = (value) => ({ stringUnit: { state: 'translated', value } });
const localization = (value) => (typeof value === 'string'
  ? unit(value)
  : { variations: { plural: Object.fromEntries(Object.entries(value).map(([form, text]) => [form, unit(text)])) } });

const catalog = (map) => ({
  sourceLanguage: 'it',
  strings: Object.fromEntries(
    Object.keys(map).sort().map((key) => [key, {
      extractionState: 'manual',
      localizations: Object.fromEntries(['it', 'en'].map((lang) => [lang, localization(map[key][lang])])),
    }]),
  ),
  version: '1.0',
});

mkdirSync(outDir, { recursive: true });
const write = (name, data) => writeFileSync(resolve(outDir, name), JSON.stringify(data, null, 2) + '\n');
write('Localizable.xcstrings', catalog(entries));
write('InfoPlist.xcstrings', catalog({
  CFBundleDisplayName: { it: 'SV Nativa', en: 'SV Nativa' },
  NSCameraUsageDescription: { it: 'Per fotografare i tuoi capi.', en: 'To take photos of your clothes.' },
  NSFaceIDUsageDescription: {
    it: "Serve per sbloccare l'app, se attivi il blocco nel Profilo.",
    en: 'Used to unlock the app when you turn on the lock in Profile.',
  },
}));
console.log(`Scritti ${Object.keys(entries).length} testi in ${outDir}`);
