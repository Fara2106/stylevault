/**
 * Outfit generation algorithm for StyleVault.
 * Generates scored outfit combinations based on weather, occasion, and color harmony.
 */

import { getWarmthTarget } from './weatherMapper';
import { getColorHarmonyScore } from './colorHarmony';
import { CLOTHING_COLORS } from './categories';

/** Map color IDs to hex values for harmony calculations */
const colorIdToHex = Object.fromEntries(
  CLOTHING_COLORS.map((c) => [c.id, c.hex])
);

/**
 * Get hex values for an item's color IDs.
 * @param {object} item - Wardrobe item with colors array
 * @returns {string[]} Array of hex color strings
 */
function getItemHexColors(item) {
  return (item.colors || [])
    .map((colorId) => colorIdToHex[colorId] || null)
    .filter(Boolean);
}

/**
 * Generate a unique ID for an outfit.
 * @returns {string}
 */
function generateId() {
  return `outfit_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
}

/**
 * Determine current season from a month number (0-11).
 * @param {number} month - Month (0-indexed)
 * @returns {string} Season ID
 */
function getSeasonFromMonth(month) {
  if (month >= 2 && month <= 4) return 'spring';
  if (month >= 5 && month <= 7) return 'summer';
  if (month >= 8 && month <= 10) return 'autumn';
  return 'winter';
}

/**
 * Check if an item matches the given season.
 * @param {object} item
 * @param {string} season
 * @returns {boolean}
 */
function matchesSeason(item, season) {
  if (item.season === 'all') return true;
  if (season === 'all') return true;
  return item.season === season;
}

/**
 * Check if an item matches the given occasion.
 * @param {object} item
 * @param {string} occasion
 * @returns {boolean}
 */
function matchesOccasion(item, occasion) {
  if (!occasion || occasion === 'all') return true;
  // Casual items can be worn everywhere except formal/business
  if (item.occasion === 'casual' && (occasion === 'casual' || occasion === 'sport')) return true;
  return item.occasion === occasion;
}

/**
 * Calculate how well an item's warmth matches the target.
 * @param {number} itemWarmth - Item warmth level (1-5)
 * @param {number} targetWarmth - Target warmth level (1-5)
 * @returns {number} Score 0-100
 */
function warmthMatchScore(itemWarmth, targetWarmth) {
  const diff = Math.abs(itemWarmth - targetWarmth);
  if (diff === 0) return 100;
  if (diff === 1) return 75;
  if (diff === 2) return 40;
  return 10;
}

/**
 * Filter items by category.
 * @param {object[]} items
 * @param {string} category
 * @returns {object[]}
 */
function filterByCategory(items, category) {
  return items.filter((item) => item.category === category);
}

/**
 * Pick a random item from an array, optionally weighted by score.
 * @param {object[]} items
 * @returns {object|null}
 */
function pickRandom(items) {
  if (!items || items.length === 0) return null;
  return items[Math.floor(Math.random() * items.length)];
}

/**
 * Pick the best items sorted by warmth match, with some randomness.
 * @param {object[]} items
 * @param {number} targetWarmth
 * @param {number} count
 * @returns {object[]}
 */
function pickBestByWarmth(items, targetWarmth, count = 3) {
  const scored = items.map((item) => ({
    item,
    score: warmthMatchScore(item.warmthLevel || 2, targetWarmth),
  }));

  scored.sort((a, b) => b.score - a.score);

  // Add some randomness: pick from top candidates
  const topCount = Math.min(scored.length, Math.max(count * 2, 5));
  const topItems = scored.slice(0, topCount).map((s) => s.item);

  // Shuffle top items
  for (let i = topItems.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [topItems[i], topItems[j]] = [topItems[j], topItems[i]];
  }

  return topItems.slice(0, count);
}

/**
 * Calculate weather match score for an outfit.
 * @param {object} outfit - Outfit with items
 * @param {number} targetWarmth
 * @param {object} weather
 * @returns {number} Score 0-100
 */
function calculateWeatherMatch(outfit, targetWarmth, weather) {
  const items = [outfit.top, outfit.bottom, outfit.shoes, outfit.outerwear].filter(Boolean);
  const avgWarmth =
    items.reduce((sum, item) => sum + (item.warmthLevel || 2), 0) / items.length;

  const warmthDiff = Math.abs(avgWarmth - targetWarmth);
  let score = Math.max(0, 100 - warmthDiff * 25);

  // Bonus for rain gear when raining
  if (weather.rain) {
    const hasRainGear =
      outfit.outerwear?.subcategory === 'raincoat' ||
      outfit.accessories?.some((a) => a.subcategory === 'umbrella');
    if (hasRainGear) score = Math.min(100, score + 15);
    else score = Math.max(0, score - 10);
  }

  // Bonus for sunglasses on sunny days
  if (weather.uvIndex >= 6) {
    const hasSunglasses = outfit.accessories?.some((a) => a.subcategory === 'sunglasses');
    if (hasSunglasses) score = Math.min(100, score + 5);
  }

  // Bonus for scarf/heavy outerwear in cold
  if (weather.temperature < 5) {
    const hasWarmOuterwear = outfit.outerwear && (outfit.outerwear.warmthLevel || 0) >= 4;
    if (hasWarmOuterwear) score = Math.min(100, score + 10);
  }

  return Math.round(score);
}

/**
 * Calculate color harmony score for an outfit.
 * @param {object} outfit
 * @returns {number} Score 0-100
 */
function calculateOutfitColorHarmony(outfit) {
  const allItems = [outfit.top, outfit.bottom, outfit.shoes, outfit.outerwear, ...(outfit.accessories || [])].filter(Boolean);
  const allHexColors = allItems.flatMap(getItemHexColors);

  if (allHexColors.length === 0) return 70; // Neutral default
  return getColorHarmonyScore(allHexColors);
}

/**
 * Generate outfit combinations.
 *
 * @param {object[]} items - All wardrobe items
 * @param {object} weather - Weather conditions from getMockWeather
 * @param {string} occasion - Occasion filter (or 'all')
 * @param {number} count - Number of outfits to generate (default 3)
 * @returns {object[]} Array of outfit objects
 */
export function generateOutfits(items, weather, occasion = 'all', count = 3) {
  if (!items || items.length === 0) return [];

  const currentMonth = new Date().getMonth();
  const currentSeason = getSeasonFromMonth(currentMonth);
  const targetWarmth = getWarmthTarget(weather.temperature, weather.windSpeed);

  // Filter items by season and occasion
  const seasonFiltered = items.filter((item) => matchesSeason(item, currentSeason));
  const filtered = seasonFiltered.filter((item) => matchesOccasion(item, occasion));

  // Get items by category
  const tops = filterByCategory(filtered, 'tops');
  const bottoms = filterByCategory(filtered, 'bottoms');
  const shoes = filterByCategory(filtered, 'shoes');
  const outerwear = filterByCategory(filtered, 'outerwear');
  const accessories = filterByCategory(filtered, 'accessories');
  const dresses = filterByCategory(filtered, 'dresses');

  // Check if we can use dresses for formal/evening
  const canUseDress = (occasion === 'formal' || occasion === 'evening') && dresses.length > 0;

  const outfits = [];
  const maxAttempts = count * 5; // Avoid infinite loops
  let attempts = 0;

  while (outfits.length < count && attempts < maxAttempts) {
    attempts++;

    let outfit = {
      id: generateId(),
      top: null,
      bottom: null,
      shoes: null,
      outerwear: null,
      accessories: [],
      score: 0,
      weatherMatch: 0,
      colorHarmony: 0,
    };

    // Decide: dress or top+bottom
    const useDress = canUseDress && Math.random() > 0.5 && dresses.length > 0;

    if (useDress) {
      const dressOptions = pickBestByWarmth(dresses, targetWarmth);
      const dress = pickRandom(dressOptions);
      if (!dress) continue;
      outfit.top = dress; // dress takes the top slot
      outfit.bottom = null; // no bottom needed with a dress
    } else {
      // Pick top
      const topOptions = pickBestByWarmth(tops, targetWarmth);
      const top = pickRandom(topOptions);
      if (!top && !canUseDress) continue; // Must have a top

      // Pick bottom
      const bottomOptions = pickBestByWarmth(bottoms, targetWarmth);
      const bottom = pickRandom(bottomOptions);
      if (!bottom && !canUseDress) continue; // Must have bottoms

      // If we couldn't find top or bottom and can't use dress, skip
      if (!top || !bottom) continue;

      outfit.top = top;
      outfit.bottom = bottom;
    }

    // Pick shoes (required)
    const shoeOptions = pickBestByWarmth(shoes, targetWarmth);
    const shoe = pickRandom(shoeOptions);
    if (!shoe) {
      // Try without warmth filter
      const anyShoe = pickRandom(shoes.length > 0 ? shoes : filterByCategory(items, 'shoes'));
      if (!anyShoe) continue;
      outfit.shoes = anyShoe;
    } else {
      outfit.shoes = shoe;
    }

    // Add outerwear if needed (temp < 18 or rain)
    if (weather.temperature < 18 || weather.rain) {
      const outerwearOptions = pickBestByWarmth(outerwear, targetWarmth);
      const outerItem = pickRandom(outerwearOptions);
      if (outerItem) {
        outfit.outerwear = outerItem;
      } else if (outerwear.length > 0) {
        outfit.outerwear = pickRandom(outerwear);
      }
    }

    // Add weather-appropriate accessories
    const selectedAccessories = [];

    // Umbrella if raining
    if (weather.rain) {
      const umbrellas = accessories.filter((a) => a.subcategory === 'umbrella');
      if (umbrellas.length > 0) selectedAccessories.push(pickRandom(umbrellas));
    }

    // Sunglasses if sunny
    if (weather.uvIndex >= 5 && !weather.rain) {
      const sunglasses = accessories.filter((a) => a.subcategory === 'sunglasses');
      if (sunglasses.length > 0) selectedAccessories.push(pickRandom(sunglasses));
    }

    // Scarf if cold
    if (weather.temperature < 10) {
      const scarves = accessories.filter((a) => a.subcategory === 'scarf');
      if (scarves.length > 0) selectedAccessories.push(pickRandom(scarves));
    }

    // Hat if very cold or very sunny
    if (weather.temperature < 5 || weather.uvIndex >= 8) {
      const hats = accessories.filter((a) => a.subcategory === 'hat');
      if (hats.length > 0) selectedAccessories.push(pickRandom(hats));
    }

    // Add a random accessory for style (bag, watch, jewelry)
    const styleAccessories = accessories.filter(
      (a) => !selectedAccessories.includes(a) &&
        ['bag', 'watch', 'jewelry', 'belt'].includes(a.subcategory)
    );
    if (styleAccessories.length > 0 && Math.random() > 0.4) {
      selectedAccessories.push(pickRandom(styleAccessories));
    }

    outfit.accessories = selectedAccessories.filter(Boolean);

    // Score the outfit
    outfit.weatherMatch = calculateWeatherMatch(outfit, targetWarmth, weather);
    outfit.colorHarmony = calculateOutfitColorHarmony(outfit);
    outfit.score = Math.round(outfit.weatherMatch * 0.5 + outfit.colorHarmony * 0.5);

    // Check for duplicate outfits (same items)
    const outfitKey = [
      outfit.top?.id,
      outfit.bottom?.id,
      outfit.shoes?.id,
      outfit.outerwear?.id,
    ].join('-');

    const isDuplicate = outfits.some((existing) => {
      const existingKey = [
        existing.top?.id,
        existing.bottom?.id,
        existing.shoes?.id,
        existing.outerwear?.id,
      ].join('-');
      return existingKey === outfitKey;
    });

    if (!isDuplicate) {
      outfits.push(outfit);
    }
  }

  // Sort by score descending
  outfits.sort((a, b) => b.score - a.score);

  return outfits.slice(0, count);
}
