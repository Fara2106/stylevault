/**
 * Consigli di stile rule-based per un outfit.
 * Restituisce chiavi i18n con parametri: la UI le traduce con t(key, params).
 * Nessuna AI: le regole derivano dagli stessi punteggi del motore outfit.
 */

import { getWarmthTarget } from './weatherMapper';
import { CLOTHING_COLORS } from './categories';

const NEUTRAL_COLOR_IDS = new Set([
  'black', 'white', 'gray', 'beige', 'navy', 'cream', 'brown', 'tan', 'khaki',
  'denim', 'silver',
]);

const OPEN_SHOES = new Set(['sandals', 'heels', 'pumps']);
const ELEVATING_OUTERWEAR = new Set(['blazer', 'coat', 'trench']);

function outfitItems(outfit) {
  return [
    outfit.top,
    outfit.bottom,
    outfit.shoes,
    outfit.outerwear,
    ...(outfit.accessories || []),
  ].filter(Boolean);
}

/**
 * @param {object} outfit - Outfit generato (con colorHarmony, capi negli slot)
 * @param {object} weather - {temperature, windSpeed, rain, uvIndex, ...}
 * @param {object} [context] - { recentWear?: {itemId, date}[], occasion?: string }
 * @returns {{key: string, params?: object}[]}
 */
export function getOutfitAdvice(outfit, weather, context = {}) {
  const advice = [];
  const items = outfitItems(outfit);
  if (items.length === 0) return advice;

  // ── Colori ──────────────────────────────────────────────
  const allColorIds = items.flatMap((i) => i.colors || []);
  const chromatic = [...new Set(allColorIds)].filter((c) => !NEUTRAL_COLOR_IDS.has(c));
  const knownIds = new Set(CLOTHING_COLORS.map((c) => c.id));
  const uniqueKnown = [...new Set(allColorIds)].filter((c) => knownIds.has(c));

  if (chromatic.length > 3) {
    advice.push({ key: 'advice.tooManyColors' });
  } else if (outfit.colorHarmony >= 80) {
    advice.push({
      key: uniqueKnown.length <= 1 ? 'advice.monochrome' : 'advice.colorsHarmonious',
    });
  } else if (outfit.colorHarmony < 50) {
    advice.push({ key: 'advice.colorsClash' });
  }

  // ── Calore vs temperatura ───────────────────────────────
  const target = getWarmthTarget(weather.temperature, weather.windSpeed);
  const coreItems = [outfit.top, outfit.bottom, outfit.shoes, outfit.outerwear].filter(Boolean);
  const avgWarmth =
    coreItems.reduce((sum, i) => sum + (i.warmthLevel || 2), 0) / coreItems.length;
  const roundedTemp = Math.round(weather.temperature);

  if (avgWarmth < target - 1) {
    advice.push({ key: 'advice.tooLight', params: { temp: roundedTemp } });
  } else if (avgWarmth > target + 1) {
    advice.push({ key: 'advice.tooWarm', params: { temp: roundedTemp } });
  } else if (Math.abs(avgWarmth - target) <= 0.5) {
    advice.push({ key: 'advice.perfectWarmth' });
  }

  // ── Pioggia / vento / sole ──────────────────────────────
  if (weather.rain) {
    if (outfit.shoes && OPEN_SHOES.has(outfit.shoes.subcategory)) {
      advice.push({ key: 'advice.rainShoes' });
    }
    if (!outfit.outerwear && weather.temperature < 22) {
      advice.push({ key: 'advice.rainOuter' });
    }
  }
  if (weather.uvIndex >= 8 && !weather.rain) {
    advice.push({ key: 'advice.uvHigh' });
  }
  if (weather.windSpeed > 25) {
    advice.push({ key: 'advice.windStrong' });
  }

  // ── Ripetizione ─────────────────────────────────────────
  const itemIds = new Set(items.map((i) => i.id));
  const recentHit = (context.recentWear || [])
    .filter((w) => itemIds.has(w.itemId))
    .sort((a, b) => (a.date < b.date ? 1 : -1))[0];
  if (recentHit) {
    advice.push({ key: 'advice.wornRecently', params: { date: recentHit.date } });
  }

  // ── Occasione ───────────────────────────────────────────
  if (
    outfit.outerwear &&
    ELEVATING_OUTERWEAR.has(outfit.outerwear.subcategory) &&
    (context.occasion === 'casual' || !context.occasion)
  ) {
    advice.push({ key: 'advice.elevated' });
  }

  return advice;
}
