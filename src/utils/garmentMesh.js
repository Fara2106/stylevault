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
 * crescente. Uso interno: chi ha già un profilo ordinato (es. il ciclo di
 * garmentProfile, che altrimenti riordinerebbe lo stesso profilo 15 volte)
 * evita di riordinare a ogni chiamata.
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

/**
 * Estremi verticali e raggio del cilindro che ospita la fantasia frontale
 * (il "decal") di un capo. Pura, senza three.js: three.js non gira in
 * ambiente `node`, quindi questa matematica vive negli utils, testabile.
 * `extraRadius` allarga il cilindro per i capi sdoppiati (pantaloni, scarpe),
 * dove una sola foto deve abbracciare entrambe le gambe.
 */
export function decalBounds(profile, extraRadius = 0) {
  const ys = profile.map(([, y]) => y);
  const top = Math.max(...ys);
  const bottom = Math.min(...ys);
  const radius = Math.max(...profile.map(([r]) => r)) + extraRadius + 0.004;
  return { top, bottom, radius, centerY: (top + bottom) / 2 };
}

export function garmentProfile(kind, config) {
  const span = SPANS[kind];
  if (!span) return null;

  const body = bodyProfiles(config);
  const source = body[span.source];
  const sortedSource = [...source].sort((a, b) => a[1] - b[1]);
  const profile = [];

  // Bordo inferiore chiuso, poi il guscio, poi bordo superiore chiuso:
  // un solido, non una superficie aperta. Il profilo sorgente è ordinato una
  // sola volta qui, non a ogni passo del ciclo.
  profile.push([0.001, span.from]);
  for (let i = 0; i <= STEPS; i++) {
    const y = span.from + ((span.to - span.from) * i) / STEPS;
    profile.push([interpolate(sortedSource, y) + span.gap, y]);
  }
  profile.push([0.001, span.to]);

  return {
    profile,
    offsetX: DOUBLED.has(kind) ? body.legOffsetX : 0,
    doubled: DOUBLED.has(kind),
  };
}
