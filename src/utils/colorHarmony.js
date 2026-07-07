/**
 * Color harmony utilities for StyleVault.
 * Provides color conversion, compatibility checking, and harmony scoring for outfits.
 */

/** Neutral color IDs that are always compatible with any other color */
const NEUTRAL_IDS = new Set([
  'black', 'white', 'gray', 'beige', 'navy', 'cream', 'brown', 'tan', 'khaki',
]);

/** Neutral hex values (approximate ranges handled via saturation check) */
const NEUTRAL_HEX_THRESHOLD_SATURATION = 15; // below this saturation %, treat as neutral
const NEUTRAL_HEX_THRESHOLD_LIGHTNESS_LOW = 10;
const NEUTRAL_HEX_THRESHOLD_LIGHTNESS_HIGH = 95;

/**
 * Convert a hex color string to HSL values.
 * @param {string} hex - Hex color string (with or without #)
 * @returns {{ h: number, s: number, l: number }} HSL object (h: 0-360, s: 0-100, l: 0-100)
 */
export function hexToHsl(hex) {
  const cleanHex = hex.replace('#', '');
  const r = parseInt(cleanHex.substring(0, 2), 16) / 255;
  const g = parseInt(cleanHex.substring(2, 4), 16) / 255;
  const b = parseInt(cleanHex.substring(4, 6), 16) / 255;

  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const delta = max - min;

  let h = 0;
  let s = 0;
  const l = (max + min) / 2;

  if (delta !== 0) {
    s = l > 0.5 ? delta / (2 - max - min) : delta / (max + min);

    if (max === r) {
      h = ((g - b) / delta + (g < b ? 6 : 0)) * 60;
    } else if (max === g) {
      h = ((b - r) / delta + 2) * 60;
    } else {
      h = ((r - g) / delta + 4) * 60;
    }
  }

  return {
    h: Math.round(h),
    s: Math.round(s * 100),
    l: Math.round(l * 100),
  };
}

/**
 * Convert HSL values to a hex color string.
 * @param {number} h - Hue (0-360)
 * @param {number} s - Saturation (0-100)
 * @param {number} l - Lightness (0-100)
 * @returns {string} Hex color string with # prefix
 */
export function hslToHex(h, s, l) {
  const sNorm = s / 100;
  const lNorm = l / 100;

  const c = (1 - Math.abs(2 * lNorm - 1)) * sNorm;
  const x = c * (1 - Math.abs(((h / 60) % 2) - 1));
  const m = lNorm - c / 2;

  let r = 0, g = 0, b = 0;

  if (h < 60) { r = c; g = x; b = 0; }
  else if (h < 120) { r = x; g = c; b = 0; }
  else if (h < 180) { r = 0; g = c; b = x; }
  else if (h < 240) { r = 0; g = x; b = c; }
  else if (h < 300) { r = x; g = 0; b = c; }
  else { r = c; g = 0; b = x; }

  const toHex = (val) => {
    const hex = Math.round((val + m) * 255).toString(16);
    return hex.length === 1 ? '0' + hex : hex;
  };

  return `#${toHex(r)}${toHex(g)}${toHex(b)}`.toUpperCase();
}

/**
 * Check if a color is neutral (by ID or hex analysis).
 * @param {string} colorIdOrHex - A color ID (e.g., 'black') or hex string
 * @returns {boolean}
 */
function isNeutral(colorIdOrHex) {
  // Check by ID
  if (NEUTRAL_IDS.has(colorIdOrHex?.toLowerCase())) return true;

  // Check by hex: low saturation or extreme lightness
  if (colorIdOrHex?.startsWith('#') || /^[0-9a-fA-F]{6}$/.test(colorIdOrHex)) {
    const hsl = hexToHsl(colorIdOrHex);
    if (hsl.s < NEUTRAL_HEX_THRESHOLD_SATURATION) return true;
    if (hsl.l < NEUTRAL_HEX_THRESHOLD_LIGHTNESS_LOW || hsl.l > NEUTRAL_HEX_THRESHOLD_LIGHTNESS_HIGH) return true;
  }

  return false;
}

/**
 * Calculate the minimum angular distance between two hues on the color wheel.
 * @param {number} h1 - First hue (0-360)
 * @param {number} h2 - Second hue (0-360)
 * @returns {number} Angular distance (0-180)
 */
function hueDistance(h1, h2) {
  const diff = Math.abs(h1 - h2);
  return diff > 180 ? 360 - diff : diff;
}

/**
 * Determine if two colors are compatible in an outfit.
 * Rules:
 * - Neutrals are always compatible with anything.
 * - Same hue family (distance < 30): analogous, compatible.
 * - Complementary (distance 150-180): compatible.
 * - Triadic (distance ~120): compatible.
 * - Split-complementary (distance ~150): compatible.
 * - Otherwise: lower compatibility.
 *
 * @param {string} hex1 - First hex color
 * @param {string} hex2 - Second hex color
 * @returns {boolean} True if colors work together
 */
export function areColorsCompatible(hex1, hex2) {
  // Neutrals are always compatible
  if (isNeutral(hex1) || isNeutral(hex2)) return true;

  const hsl1 = hexToHsl(hex1);
  const hsl2 = hexToHsl(hex2);

  const dist = hueDistance(hsl1.h, hsl2.h);

  // Analogous (close hues)
  if (dist <= 30) return true;

  // Complementary
  if (dist >= 150 && dist <= 180) return true;

  // Triadic (roughly 120° apart)
  if (dist >= 100 && dist <= 140) return true;

  // Split-complementary
  if (dist >= 140 && dist <= 160) return true;

  // Monochromatic (same hue, different saturation/lightness)
  if (dist <= 15) return true;

  return false;
}

/**
 * Calculate a color harmony score for a set of hex colors.
 * Returns a score from 0 to 100.
 *
 * @param {string[]} hexArray - Array of hex color strings
 * @returns {number} Harmony score (0-100)
 */
export function getColorHarmonyScore(hexArray) {
  if (!hexArray || hexArray.length === 0) return 100;
  if (hexArray.length === 1) return 100;

  // Remove duplicates
  const unique = [...new Set(hexArray)];
  if (unique.length === 1) return 100;

  let totalPairs = 0;
  let compatiblePairs = 0;
  let totalHueScore = 0;

  for (let i = 0; i < unique.length; i++) {
    for (let j = i + 1; j < unique.length; j++) {
      totalPairs++;
      const compatible = areColorsCompatible(unique[i], unique[j]);
      if (compatible) compatiblePairs++;

      // Calculate detailed hue relationship score
      const neutral1 = isNeutral(unique[i]);
      const neutral2 = isNeutral(unique[j]);

      if (neutral1 || neutral2) {
        totalHueScore += 90; // Neutrals are safe but slightly less exciting
      } else {
        const hsl1 = hexToHsl(unique[i]);
        const hsl2 = hexToHsl(unique[j]);
        const dist = hueDistance(hsl1.h, hsl2.h);

        // Score based on harmony type
        if (dist <= 15) totalHueScore += 95;         // Monochromatic
        else if (dist <= 30) totalHueScore += 85;    // Analogous
        else if (dist >= 165) totalHueScore += 80;   // Complementary
        else if (dist >= 110 && dist <= 130) totalHueScore += 75; // Triadic
        else if (dist >= 140 && dist <= 160) totalHueScore += 70; // Split-comp
        else if (compatible) totalHueScore += 60;
        else totalHueScore += 25;                    // Clashing
      }
    }
  }

  // Weighted score: compatibility ratio + hue relationship quality
  const compatibilityScore = (compatiblePairs / totalPairs) * 100;
  const hueScore = totalHueScore / totalPairs;

  // Penalize too many non-neutral colors (more than 3 chromatic colors is risky)
  const chromaticCount = unique.filter((c) => !isNeutral(c)).length;
  const varietyPenalty = chromaticCount > 3 ? (chromaticCount - 3) * 10 : 0;

  const finalScore = Math.round(
    compatibilityScore * 0.4 + hueScore * 0.6 - varietyPenalty
  );

  return Math.max(0, Math.min(100, finalScore));
}
