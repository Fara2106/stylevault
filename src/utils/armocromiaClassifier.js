/**
 * Classificatore armocromia a 12 sotto-stagioni (sistema sci-art).
 * Tre assi da pelle/capelli/occhi in Lab:
 *   lightDeep  — valore (chiaro>0, scuro<0), capelli col peso maggiore;
 *   warmCool   — sottotono (caldo>0): componente gialla b al netto del rosa;
 *   brightSoft — croma di occhi/pelle/capelli + contrasto capelli↔pelle.
 * Stagione = centroide più vicino in questo spazio (sottotono pesato di più:
 * caldo/freddo è l'asse primario dell'armocromia). Numeri TARATI su fixture
 * validate: non ritoccare senza rifare la taratura.
 */
import { hexToRgb, rgbToLab } from './colorSampling';

export const SEASON_AXES = {
  'light-spring': { lightDeep: 0.9, warmCool: 0.5, brightSoft: -0.45 },
  'light-summer': { lightDeep: 0.9, warmCool: -0.4, brightSoft: -0.85 },
  'true-spring': { lightDeep: 0.3, warmCool: 1.3, brightSoft: 0.3 },
  'true-summer': { lightDeep: 0.3, warmCool: -0.5, brightSoft: -0.5 },
  'true-autumn': { lightDeep: -0.2, warmCool: 1.1, brightSoft: 0.1 },
  'true-winter': { lightDeep: -0.3, warmCool: -0.7, brightSoft: -0.15 },
  'bright-spring': { lightDeep: 0.3, warmCool: 0.85, brightSoft: 0.75 },
  'bright-winter': { lightDeep: -0.25, warmCool: -0.85, brightSoft: 0.55 },
  'soft-autumn': { lightDeep: 0.15, warmCool: 0.6, brightSoft: -0.45 },
  'soft-summer': { lightDeep: 0.45, warmCool: -0.35, brightSoft: -0.9 },
  'deep-autumn': { lightDeep: -0.55, warmCool: 1.0, brightSoft: 0.1 },
  'deep-winter': { lightDeep: -0.75, warmCool: -0.3, brightSoft: -0.3 },
};

// Il sottotono è l'asse primario dell'armocromia: pesa di più nella distanza.
const AXIS_WEIGHT = { lightDeep: 1, warmCool: 1.4, brightSoft: 1 };

const toLab = (hex) => {
  const rgb = hexToRgb(hex);
  return rgb ? rgbToLab(rgb) : null;
};

/** Media pesata che ignora i termini null e rinormalizza i pesi. */
const wsum = (pairs) => {
  const act = pairs.filter(([v]) => v !== null && v !== undefined);
  if (act.length === 0) return null;
  const tot = act.reduce((t, [, w]) => t + w, 0);
  return act.reduce((t, [v, w]) => t + v * (w / tot), 0);
};

export function computeAxes({ skin, hair, eyes }) {
  const s = skin ? toLab(skin) : null;
  const h = hair ? toLab(hair) : null;
  const e = eyes ? toLab(eyes) : null;

  const value = wsum([[h && h.L, 0.5], [s && s.L, 0.35], [e && e.L, 0.15]]);
  const lightDeep = (value - 53) / 34;

  const warmOf = (lab, bNeutral) => (lab.b - bNeutral) - 0.35 * Math.max(0, lab.a - 14);
  const warmCool = wsum([
    [s && warmOf(s, 15), 0.45],
    [h && warmOf(h, 10), 0.35],
    [e && (e.b - 2), 0.2],
  ]) / 16;

  const chroma = (lab) => Math.sqrt(lab.a * lab.a + lab.b * lab.b);
  const contrast = s && h ? Math.abs(s.L - h.L) : 0;
  const brightSoft =
    (wsum([[e && chroma(e), 0.45], [s && chroma(s), 0.25], [h && chroma(h), 0.3]]) - 27) / 26 +
    (contrast - 34) / 90;

  return { lightDeep, warmCool, brightSoft };
}

export function classifySeason({ skin, hair, eyes }) {
  if (!skin && !hair) return null; // occhi da soli non bastano
  const a = computeAxes({ skin, hair, eyes });
  const dist = (c) =>
    Math.sqrt(
      AXIS_WEIGHT.lightDeep * (a.lightDeep - c.lightDeep) ** 2 +
        AXIS_WEIGHT.warmCool * (a.warmCool - c.warmCool) ** 2 +
        AXIS_WEIGHT.brightSoft * (a.brightSoft - c.brightSoft) ** 2
    );
  const ranked = Object.entries(SEASON_AXES)
    .map(([season, c]) => [season, dist(c)])
    .sort((x, y) => x[1] - y[1]);
  const [best, d1] = ranked[0];
  const d2 = ranked[1][1];
  // Margine fra i due centroidi migliori: vicini ⇒ verdetto incerto.
  const confidence = Math.round(((d2 - d1) / (d2 + d1)) * 100) / 100;
  return { season: best, axes: a, confidence };
}
