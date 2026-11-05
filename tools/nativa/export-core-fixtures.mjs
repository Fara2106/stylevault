// Esporta il catalogo del sito in un JSON usato dai test di StyleVaultCore.
import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { CATEGORIES, SEASONS, OCCASIONS, CLOTHING_COLORS } from '../../src/utils/categories.js';

const here = dirname(fileURLToPath(import.meta.url));
const out = resolve(here, '../../ios/StyleVaultCore/Tests/StyleVaultCoreTests/Fixtures/catalog.json');

const catalog = {
  categories: Object.entries(CATEGORIES).map(([id, c]) => ({
    id,
    icon: c.icon,
    labelKey: c.labelKey,
    subcategories: c.subcategories.map(({ id, labelKey }) => ({ id, labelKey })),
  })),
  seasons: SEASONS,
  occasions: OCCASIONS,
  colors: CLOTHING_COLORS,
};

mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, JSON.stringify(catalog, null, 2) + '\n');
console.log(`Scritto ${out}: ${catalog.categories.length} categorie, ${catalog.seasons.length} stagioni, ${catalog.occasions.length} occasioni, ${catalog.colors.length} colori`);
