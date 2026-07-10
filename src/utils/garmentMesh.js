/**
 * I capi 3D: gusci ricavati dal profilo del corpo, ingrossati di GARMENT_GAP e
 * tagliati all'altezza giusta. Derivarli dal corpo significa che aderiscono da
 * soli alla corporatura scelta: nessuno deve modellare 5 capi x 5 corporature.
 *
 * La forma è generica — una maglietta è "una maglietta". Colore e fantasia
 * vengono dalla foto vera (garmentTexture.js). Il capo esatto addosso alla
 * persona lo dà solo la scheda "Sulla tua foto (AI)".
 */
import { bodyProfiles } from './avatarMesh';

export const GARMENT_KINDS = ['top', 'dress', 'bottom', 'outerwear', 'shoes'];

/** Di quanto il capo sta fuori dalla pelle. */
export const GARMENT_GAP = 0.012;

/** Estremi verticali di ogni capo, in unità della figura alta 1.8. */
const SPANS = {
  top: { from: 0.98, to: 1.45, source: 'torso', gap: GARMENT_GAP },
  dress: { from: 0.55, to: 1.45, source: 'torso', gap: GARMENT_GAP },
  bottom: { from: 0.06, to: 0.95, source: 'leg', gap: GARMENT_GAP },
  outerwear: { from: 0.9, to: 1.46, source: 'torso', gap: GARMENT_GAP * 2.2 },
  shoes: { from: 0.0, to: 0.1, source: 'leg', gap: GARMENT_GAP * 1.6 },
};

const DOUBLED = new Set(['bottom', 'shoes']);

/**
 * Interpolazione lineare del raggio su un profilo già ordinato per quota
 * crescente. Uso interno di `radiusAt`, che si occupa dell'ordinamento.
 */
const interpolate = (sorted, y) => {
  if (y <= sorted[0][1]) return sorted[0][0];
  if (y >= sorted[sorted.length - 1][1]) return sorted[sorted.length - 1][0];
  for (let i = 1; i < sorted.length; i++) {
    const [r0, y0] = sorted[i - 1];
    const [r1, y1] = sorted[i];
    if (y <= y1) {
      const k = y1 === y0 ? 0 : (y - y0) / (y1 - y0);
      return r0 + (r1 - r0) * k;
    }
  }
  return sorted[sorted.length - 1][0];
};

/**
 * Raggio del profilo alla quota y, per interpolazione lineare.
 * Esportata: è ciò che permette al test di verificare, quota per quota, che il
 * capo stia fuori dalla pelle. Riordina il profilo a ogni chiamata, quindi
 * accetta profili in qualsiasi ordine di quota.
 */
export const radiusAt = (profile, y) => interpolate([...profile].sort((a, b) => a[1] - b[1]), y);

const STEPS = 14;

/** Campate delle maniche, per tipo. Assenti dove il capo non ne ha. */
const SLEEVES = {
  top: { from: 1.24, to: 1.42 },
  dress: { from: 1.24, to: 1.42 },
  outerwear: { from: 0.98, to: 1.44 },
};

/**
 * Costruisce il profilo di un guscio attorno a `source`, fra due quote:
 * bordo inferiore chiuso, poi il guscio, poi bordo superiore chiuso (un
 * solido, non una superficie aperta). Unica costruzione di guscio nel file:
 * la usano sia `garmentProfile` sia `garmentParts`.
 */
const shell = (source, from, to, gap) => {
  const profile = [[0.001, from]];
  for (let i = 0; i <= STEPS; i++) {
    const y = from + ((to - from) * i) / STEPS;
    profile.push([radiusAt(source, y) + gap, y]);
  }
  profile.push([0.001, to]);
  return profile;
};

export function garmentProfile(kind, config) {
  const span = SPANS[kind];
  if (!span) return null;

  const body = bodyProfiles(config);
  const source = body[span.source];

  return {
    profile: shell(source, span.from, span.to, span.gap),
    offsetX: DOUBLED.has(kind) ? body.legOffsetX : 0,
    doubled: DOUBLED.has(kind),
  };
}

/**
 * Le parti 3D di un capo. Ogni parte è un profilo da ruotare attorno
 * all'asse, con lo scostamento laterale a cui va messa. `mirror: true`
 * significa "istanzia anche a -offsetX" (le due maniche, le due gambe).
 * Le maniche sono un guscio del braccio, separato da quello del busto:
 * è ciò che distingue una canotta (top senza SLEEVES) da una maglietta.
 */
export function garmentParts(kind, config) {
  const span = SPANS[kind];
  if (!span) return [];

  const body = bodyProfiles(config);
  const parts = [];

  const main = garmentProfile(kind, config);
  parts.push({ profile: main.profile, offsetX: main.offsetX, mirror: main.doubled });

  const sleeve = SLEEVES[kind];
  if (sleeve) {
    parts.push({
      profile: shell(body.arm, sleeve.from, sleeve.to, span.gap),
      offsetX: body.armOffsetX,
      mirror: true,
    });
  }
  return parts;
}
