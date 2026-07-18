/**
 * Capi del guardaroba "in palette" per una stagione: per ogni capo si prende
 * il deltaE minimo fra i suoi colori (id → hex di CLOTHING_COLORS) e
 * palette+neutri della stagione. Sotto soglia ⇒ in palette.
 */
import { getSeason } from './armocromiaSeasons';
import { hexToRgb, rgbToLab, deltaE } from './colorSampling';
import { CLOTHING_COLORS } from './categories';

export const IN_PALETTE_MAX = 25;

export function matchWardrobe(items, seasonId) {
  const season = getSeason(seasonId);
  if (!season) return [];
  const paletteLabs = [...season.palette, ...season.neutrals].map((c) => ({
    hex: c.hex,
    lab: rgbToLab(hexToRgb(c.hex)),
  }));
  const out = [];
  for (const item of items || []) {
    let best = null;
    for (const colorId of item.colors || []) {
      const cc = CLOTHING_COLORS.find((c) => c.id === colorId);
      if (!cc) continue;
      const lab = rgbToLab(hexToRgb(cc.hex));
      for (const p of paletteLabs) {
        const d = deltaE(lab, p.lab);
        if (!best || d < best.distance) {
          best = { distance: d, itemHex: cc.hex, paletteHex: p.hex };
        }
      }
    }
    if (best && best.distance <= IN_PALETTE_MAX) out.push({ item, ...best });
  }
  return out.sort((a, b) => a.distance - b.distance);
}
