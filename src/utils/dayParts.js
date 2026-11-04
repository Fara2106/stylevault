/**
 * La giornata in tre fasce, dalle previsioni ora per ora (ora locale del luogo).
 * Contano solo le ore "fuori casa", dalle 8 alle 20; per oggi solo quelle da
 * adesso in poi (dopo le 20 o prima delle 8 di nuovo tutte).
 */

import { RAIN_PROBABILITY_THRESHOLD } from '../services/weatherThresholds';

export const DAY_START = 8;
export const DAY_END = 20;

export const DAY_PARTS = [
  { key: 'morning', from: 8, to: 12 },
  { key: 'afternoon', from: 12, to: 17 },
  { key: 'evening', from: 17, to: 20 },
];

const valid = (v) => typeof v === 'number' && Number.isFinite(v);

const average = (values) => {
  const nums = values.filter(valid);
  return nums.length ? nums.reduce((a, b) => a + b, 0) / nums.length : null;
};

const maximum = (values) => {
  const nums = values.filter(valid);
  return nums.length ? Math.max(...nums) : null;
};

/**
 * @param {{hour:number, apparent:number|null, precipProb:number|null, code:number|null}[]} hours
 *   le ore di un solo giorno
 * @param {{nowHour:number|null}} options ora locale del luogo se il giorno è oggi
 * @returns {{temperature:number|null, parts:object[], rainFrom:number|null, rainFromStart:boolean}}
 */
export function summarizeDay(hours, { nowHour = null } = {}) {
  const start = valid(nowHour) && nowHour >= DAY_START && nowHour < DAY_END ? nowHour : DAY_START;
  const counted = hours
    .filter((h) => h.hour >= start && h.hour < DAY_END)
    .sort((a, b) => a.hour - b.hour);

  const parts = DAY_PARTS.map(({ key, from, to }) => {
    const inPart = hours.filter((h) => h.hour >= from && h.hour < to);
    return {
      key,
      temperature: average(inPart.map((h) => h.apparent)),
      code: maximum(inPart.map((h) => h.code)),
      precipProb: maximum(inPart.map((h) => h.precipProb)),
      past: to <= start,
    };
  });

  const rainy = counted.find(
    (h) => valid(h.precipProb) && h.precipProb >= RAIN_PROBABILITY_THRESHOLD
  );
  const rainFrom = rainy ? rainy.hour : null;

  return {
    temperature: average(counted.map((h) => h.apparent)),
    parts,
    rainFrom,
    rainFromStart: rainFrom != null && rainFrom === start,
  };
}
