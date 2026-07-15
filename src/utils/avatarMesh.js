/**
 * Il corpo dell'avatar, generato da codice: nessun modello 3D da scaricare,
 * nessuna licenza di terzi, e la corporatura resta un parametro invece di
 * dipendere dai morph target che il modello potrebbe non avere.
 *
 * Un profilo è una lista di [raggio, altezza]: ruotandolo attorno all'asse
 * verticale si ottiene il solido (three.js: LatheGeometry). Puro, senza three.js:
 * così è testabile in ambiente node.
 */
import { getSkinHex, getHairHex, getBodyWidthFactor, getGender } from './avatarOptions';

/** Figura alta 1.8, piedi a y = 0. */
const HEAD_RADIUS = 0.115;
const HEAD_Y = 1.63;

// [raggio, altezza] a corporatura 1, sagoma femminile: spalle più strette,
// vita marcata, fianchi più larghi delle spalle (hourglass).
const TORSO_FEMALE = [
  [0.005, 1.5],
  [0.075, 1.47],
  [0.09, 1.42],
  [0.145, 1.3],
  [0.135, 1.18],
  [0.105, 1.08],
  [0.125, 0.99],
  [0.15, 0.93],
  [0.145, 0.88],
  [0.005, 0.86],
];

// [raggio, altezza] a corporatura 1, sagoma maschile: spalle più larghe delle
// spalle femminili, vita meno marcata, fianchi più stretti delle spalle (a V).
const TORSO_MALE = [
  [0.005, 1.5],
  [0.095, 1.47],
  [0.125, 1.42],
  [0.16, 1.3],
  [0.145, 1.18],
  [0.125, 1.08],
  [0.115, 0.99],
  [0.118, 0.93],
  [0.112, 0.88],
  [0.005, 0.86],
];

const LEG_FEMALE = [
  [0.005, 0.9],
  [0.085, 0.86],
  [0.075, 0.6],
  [0.05, 0.45],
  [0.06, 0.3],
  [0.04, 0.08],
  [0.05, 0.02],
  [0.005, 0.0],
];

const LEG_MALE = [
  [0.005, 0.9],
  [0.082, 0.86],
  [0.078, 0.6],
  [0.055, 0.45],
  [0.062, 0.3],
  [0.042, 0.08],
  [0.052, 0.02],
  [0.005, 0.0],
];

const ARM_FEMALE = [
  [0.005, 1.42],
  [0.042, 1.38],
  [0.032, 1.1],
  [0.026, 0.92],
  [0.005, 0.88],
];

const ARM_MALE = [
  [0.005, 1.42],
  [0.05, 1.38],
  [0.038, 1.1],
  [0.03, 0.92],
  [0.005, 0.88],
];

/** Scostamento laterale di gambe e braccia, per genere: fianchi femminili
 * proporzionalmente più larghi, spalle maschili proporzionalmente più larghe. */
const OFFSETS = {
  female: { leg: 0.064, arm: 0.16 },
  male: { leg: 0.058, arm: 0.175 },
};

const PROFILES = {
  female: { torso: TORSO_FEMALE, leg: LEG_FEMALE, arm: ARM_FEMALE },
  male: { torso: TORSO_MALE, leg: LEG_MALE, arm: ARM_MALE },
};

const scaleRadii = (profile, factor) => profile.map(([r, y]) => [r * factor, y]);

export function bodyProfiles(config) {
  const widthFactor = getBodyWidthFactor(config?.bodyShape);
  const gender = getGender(config?.gender);
  const base = PROFILES[gender];
  const offsets = OFFSETS[gender];
  return {
    torso: scaleRadii(base.torso, widthFactor),
    leg: scaleRadii(base.leg, widthFactor),
    arm: scaleRadii(base.arm, widthFactor),
    head: { radius: HEAD_RADIUS, y: HEAD_Y },
    legOffsetX: offsets.leg * widthFactor,
    armOffsetX: offsets.arm * widthFactor,
    skinHex: getSkinHex(config?.skinTone),
    hairHex: getHairHex(config?.hairColor),
    hairStyle: config?.hairStyle || 'medium',
    widthFactor,
    gender,
  };
}
