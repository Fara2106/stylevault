/**
 * Fondamenta colore per l'armocromia: conversioni sRGB↔Lab (D65), distanza
 * percettiva CIE76 e campionamento robusto di regioni di pixel.
 * Puro: nessun DOM, nessuna rete. Unico posto per la matematica Lab.
 */

export const hexToRgb = (hex) => {
  const m = /^#?([0-9a-f]{6})$/i.exec(hex || '');
  if (!m) return null;
  const n = parseInt(m[1], 16);
  return { r: (n >> 16) & 255, g: (n >> 8) & 255, b: n & 255 };
};

export const rgbToHex = ({ r, g, b }) =>
  `#${[r, g, b].map((v) => Math.round(v).toString(16).padStart(2, '0')).join('')}`;

const srgbToLinear = (c) => {
  const v = c / 255;
  return v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4;
};
const linearToSrgb = (v) =>
  255 * (v <= 0.0031308 ? 12.92 * v : 1.055 * v ** (1 / 2.4) - 0.055);

export const rgbToLab = ({ r, g, b }) => {
  const R = srgbToLinear(r), G = srgbToLinear(g), B = srgbToLinear(b);
  const X = (0.4124564 * R + 0.3575761 * G + 0.1804375 * B) / 0.95047;
  const Y = 0.2126729 * R + 0.7151522 * G + 0.072175 * B;
  const Z = (0.0193339 * R + 0.119192 * G + 0.9503041 * B) / 1.08883;
  const f = (t) => (t > 0.008856 ? Math.cbrt(t) : 7.787 * t + 16 / 116);
  const fx = f(X), fy = f(Y), fz = f(Z);
  return { L: 116 * fy - 16, a: 500 * (fx - fy), b: 200 * (fy - fz) };
};

export const labToRgb = ({ L, a, b }) => {
  const fy = (L + 16) / 116;
  const fx = fy + a / 500;
  const fz = fy - b / 200;
  const inv = (t) => (t ** 3 > 0.008856 ? t ** 3 : (t - 16 / 116) / 7.787);
  const X = inv(fx) * 0.95047, Y = inv(fy), Z = inv(fz) * 1.08883;
  const R = 3.2404542 * X - 1.5371385 * Y - 0.4985314 * Z;
  const G = -0.969266 * X + 1.8760108 * Y + 0.041556 * Z;
  const B = 0.0556434 * X - 0.2040259 * Y + 1.0572252 * Z;
  const clamp = (v) => Math.max(0, Math.min(255, Math.round(linearToSrgb(v))));
  return { r: clamp(R), g: clamp(G), b: clamp(B) };
};

/** Distanza percettiva CIE76: sufficiente per palette e guardaroba. */
export const deltaE = (l1, l2) =>
  Math.sqrt((l1.L - l2.L) ** 2 + (l1.a - l2.a) ** 2 + (l1.b - l2.b) ** 2);

/**
 * Colore rappresentativo di una regione: Lab, ordina per L, scarta gli
 * estremi (ombre/riflessi), mediana per canale, riconverte in hex.
 */
export function representativeColor(pixels, { trim = 0.15 } = {}) {
  if (!pixels || pixels.length === 0) return null;
  const labs = pixels.map(rgbToLab).sort((p, q) => p.L - q.L);
  const cut = Math.floor(labs.length * trim);
  const kept = labs.slice(cut, labs.length - cut);
  if (kept.length === 0) return null;
  const median = (arr) => {
    const s = [...arr].sort((x, y) => x - y);
    const m = s.length >> 1;
    return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
  };
  return rgbToHex(labToRgb({
    L: median(kept.map((p) => p.L)),
    a: median(kept.map((p) => p.a)),
    b: median(kept.map((p) => p.b)),
  }));
}

/**
 * Pixel RGB delle classi volute da una maschera di segmentazione parallela
 * all'imageData. Campiona a passo costante per non superare maxSamples.
 */
export function maskedPixels(imageData, categories, wanted, maxSamples = 4000) {
  const want = new Set(wanted);
  const idx = [];
  for (let i = 0; i < categories.length; i++) if (want.has(categories[i])) idx.push(i);
  const step = Math.max(1, Math.ceil(idx.length / maxSamples));
  const out = [];
  for (let k = 0; k < idx.length; k += step) {
    const o = idx[k] * 4;
    out.push({ r: imageData.data[o], g: imageData.data[o + 1], b: imageData.data[o + 2] });
  }
  return out;
}
