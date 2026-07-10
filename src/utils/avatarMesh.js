/**
 * Il corpo dell'avatar, generato da codice: nessun modello 3D da scaricare,
 * nessuna licenza di terzi, e la corporatura resta un parametro invece di
 * dipendere dai morph target che il modello potrebbe non avere.
 *
 * Un profilo è una lista di [raggio, altezza]: ruotandolo attorno all'asse
 * verticale si ottiene il solido (three.js: LatheGeometry). Puro, senza three.js:
 * così è testabile in ambiente node.
 */
import { getSkinHex, getHairHex, getBodyWidthFactor } from './avatarOptions';

/** Figura alta 1.8, piedi a y = 0. */
const HEAD_RADIUS = 0.115;
const HEAD_Y = 1.63;

// [raggio, altezza] a corporatura 1
const TORSO = [
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

const LEG = [
  [0.005, 0.9],
  [0.085, 0.86],
  [0.075, 0.6],
  [0.05, 0.45],
  [0.06, 0.3],
  [0.04, 0.08],
  [0.05, 0.02],
  [0.005, 0.0],
];

const ARM = [
  [0.005, 1.42],
  [0.042, 1.38],
  [0.032, 1.1],
  [0.026, 0.92],
  [0.005, 0.88],
];

const LEG_OFFSET_X = 0.062;
const ARM_OFFSET_X = 0.165;

const scaleRadii = (profile, factor) => profile.map(([r, y]) => [r * factor, y]);

export function bodyProfiles(config) {
  const widthFactor = getBodyWidthFactor(config?.bodyShape);
  return {
    torso: scaleRadii(TORSO, widthFactor),
    leg: scaleRadii(LEG, widthFactor),
    arm: scaleRadii(ARM, widthFactor),
    head: { radius: HEAD_RADIUS, y: HEAD_Y },
    legOffsetX: LEG_OFFSET_X * widthFactor,
    armOffsetX: ARM_OFFSET_X * widthFactor,
    skinHex: getSkinHex(config?.skinTone),
    hairHex: getHairHex(config?.hairColor),
    hairStyle: config?.hairStyle || 'medium',
    widthFactor,
  };
}
