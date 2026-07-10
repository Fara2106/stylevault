import { describe, it, expect } from 'vitest';
import { garmentProfile, radiusAt, decalBounds, GARMENT_KINDS, GARMENT_GAP } from './garmentMesh';
import { bodyProfiles } from './avatarMesh';

const cfg = { bodyShape: 'average', skinTone: 'medium', hairColor: 'brown', hairStyle: 'medium' };

const yRange = (profile) => {
  const ys = profile.map(([, y]) => y);
  return [Math.min(...ys), Math.max(...ys)];
};

/**
 * Interpolazione lineare scritta qui, indipendente da `radiusAt` del modulo
 * sotto test. Serve a rompere la tautologia dei test dell'invariante: se
 * `radiusAt` si rompe, questa non se ne accorge e il confronto con l'output
 * di `garmentProfile` (che usa `radiusAt` internamente) fallisce davvero.
 */
const linearRadius = (profile, y) => {
  const pts = [...profile].sort((a, b) => a[1] - b[1]);
  if (y <= pts[0][1]) return pts[0][0];
  if (y >= pts[pts.length - 1][1]) return pts[pts.length - 1][0];
  for (let i = 1; i < pts.length; i++) {
    const [r0, y0] = pts[i - 1];
    const [r1, y1] = pts[i];
    if (y <= y1) {
      return r0 + (r1 - r0) * ((y - y0) / (y1 - y0));
    }
  }
  return pts[pts.length - 1][0];
};

describe('radiusAt', () => {
  // Test diretti su profili inventati a mano, con valori attesi calcolati a
  // mente: non passano mai attraverso garmentProfile o bodyProfiles.
  it('interpola a metà strada tra due punti', () => {
    expect(radiusAt([[0, 0], [10, 10]], 5)).toBe(5);
  });

  it('restituisce il raggio esatto quando y coincide con un punto del profilo', () => {
    const profile = [[0, 0], [4, 2], [10, 10]];
    expect(radiusAt(profile, 2)).toBe(4);
  });

  it('aggancia (clamp) al raggio più basso quando y è sotto la campata', () => {
    expect(radiusAt([[3, 1], [9, 5]], -100)).toBe(3);
  });

  it('aggancia (clamp) al raggio più alto quando y è sopra la campata', () => {
    expect(radiusAt([[3, 1], [9, 5]], 100)).toBe(9);
  });

  it('riordina il profilo se non è dato in ordine crescente di y', () => {
    // stessi due punti di prima ma scritti al contrario: il risultato a metà
    // strada (y=3, tra y=1 r=3 e y=5 r=9) non deve cambiare.
    expect(radiusAt([[9, 5], [3, 1]], 3)).toBe(6);
  });

  it('interpola correttamente anche con un punto intermedio fuori ordine', () => {
    const profile = [[5, 5], [0, 0], [10, 10]];
    expect(radiusAt(profile, 7.5)).toBe(7.5);
  });
});

describe('garmentProfile', () => {
  it('conosce i cinque tipi che garmentLayers produce', () => {
    expect(GARMENT_KINDS).toEqual(['top', 'dress', 'bottom', 'outerwear', 'shoes']);
    for (const kind of GARMENT_KINDS) {
      expect(garmentProfile(kind, cfg)).not.toBeNull();
    }
  });

  it('restituisce null per un tipo sconosciuto', () => {
    expect(garmentProfile('cappello', cfg)).toBeNull();
  });

  it('il capo sta fuori dalla pelle a ogni quota, mai dentro', () => {
    // NON "il raggio massimo del capo supera il raggio massimo del corpo": i
    // fianchi (0.15 a quota 0.93) stanno sotto la campata del top (0.98-1.45),
    // dove il torso arriva a 0.145. L'invariante e' locale, quota per quota.
    // Il raggio atteso è calcolato con `linearRadius`, non con `radiusAt`: se
    // `radiusAt` si rompesse, l'atteso resterebbe corretto e il confronto
    // con l'output di `garmentProfile` fallirebbe.
    const body = bodyProfiles(cfg);
    const { profile } = garmentProfile('top', cfg);
    const shell = profile.slice(1, -1); // via i due punti di chiusura sull'asse
    expect(shell.length).toBeGreaterThan(10);
    for (const [r, y] of shell) {
      expect(r).toBeCloseTo(linearRadius(body.torso, y) + GARMENT_GAP, 9);
    }
  });

  it('il capospalla sta fuori del top: si indossa sopra', () => {
    // Non basta confrontare radiusOf(outer) > radiusOf(top): essendo
    // entrambi "raggio del corpo + margine", se il raggio del corpo fosse
    // sbagliato allo stesso modo per entrambi il termine si semplificherebbe
    // e il confronto passerebbe comunque (il margine dell'outerwear è 2.2x
    // quello del top a prescindere). Si asserisce quindi sul valore assoluto
    // atteso a quota 1.2, calcolato in modo indipendente da `radiusAt`.
    const body = bodyProfiles(cfg);
    const top = garmentProfile('top', cfg);
    const outer = garmentProfile('outerwear', cfg);
    const y = 1.2; // quota coperta da entrambi
    const expectedBodyRadius = linearRadius(body.torso, y);
    const radiusOf = ({ profile }) => linearRadius(profile.slice(1, -1), y);
    expect(radiusOf(top)).toBeCloseTo(expectedBodyRadius + GARMENT_GAP, 9);
    expect(radiusOf(outer)).toBeCloseTo(expectedBodyRadius + GARMENT_GAP * 2.2, 9);
    expect(radiusOf(outer)).toBeGreaterThan(radiusOf(top));
  });

  it('il capo segue la corporatura: plus è più largo di slim', () => {
    const slim = garmentProfile('top', { ...cfg, bodyShape: 'slim' });
    const plus = garmentProfile('top', { ...cfg, bodyShape: 'plus' });
    expect(Math.max(...plus.profile.map(([r]) => r))).toBeGreaterThan(
      Math.max(...slim.profile.map(([r]) => r))
    );
  });

  it("l'abito scende più in basso del top", () => {
    const [topLow] = yRange(garmentProfile('top', cfg).profile);
    const [dressLow] = yRange(garmentProfile('dress', cfg).profile);
    expect(dressLow).toBeLessThan(topLow);
  });

  it('il bottom parte dalla vita e arriva alle caviglie', () => {
    const [low, high] = yRange(garmentProfile('bottom', cfg).profile);
    expect(high).toBeCloseTo(0.95, 1);
    expect(low).toBeLessThan(0.15);
  });

  it('bottom e scarpe si istanziano due volte, il top no', () => {
    expect(garmentProfile('bottom', cfg).doubled).toBe(true);
    expect(garmentProfile('shoes', cfg).doubled).toBe(true);
    expect(garmentProfile('top', cfg).doubled).toBe(false);
    expect(garmentProfile('dress', cfg).doubled).toBe(false);
  });

  it('i cinque tipi producono profili distinti', () => {
    const seen = GARMENT_KINDS.map((k) => JSON.stringify(garmentProfile(k, cfg).profile));
    expect(new Set(seen).size).toBe(5);
  });
});

describe('decalBounds', () => {
  // Profilo inventato a mano: raggio massimo 0.1 a quota 0.5, estremi 0 e 1.
  // Valori attesi calcolati a mente, non richiamando decalBounds stessa:
  // top = 1, bottom = 0, raggio = 0.1 + extraRadius + 0.004, centro = 0.5.
  const profile = [
    [0.02, 0],
    [0.1, 0.5],
    [0.05, 1],
  ];

  it('calcola top, bottom, raggio e centro da un profilo semplice', () => {
    const bounds = decalBounds(profile);
    expect(bounds.top).toBe(1);
    expect(bounds.bottom).toBe(0);
    expect(bounds.radius).toBeCloseTo(0.104, 9); // 0.1 + 0 + 0.004
    expect(bounds.centerY).toBe(0.5);
  });

  it('allarga il raggio di extraRadius per abbracciare i capi sdoppiati', () => {
    const bounds = decalBounds(profile, 0.03);
    expect(bounds.radius).toBeCloseTo(0.134, 9); // 0.1 + 0.03 + 0.004
    // top/bottom/centro non dipendono da extraRadius
    expect(bounds.top).toBe(1);
    expect(bounds.bottom).toBe(0);
  });

  it("non dipende dall'ordine dei punti nel profilo", () => {
    const shuffled = [profile[2], profile[0], profile[1]];
    expect(decalBounds(shuffled)).toEqual(decalBounds(profile));
  });

  it('gestisce profili con quote negative (sotto lo zero della figura)', () => {
    const legProfile = [
      [0.03, -0.2],
      [0.08, 0.1],
      [0.04, 0.4],
    ];
    // top = 0.4, bottom = -0.2, raggio = 0.08 + 0 + 0.004, centro = 0.1
    const bounds = decalBounds(legProfile);
    expect(bounds.top).toBe(0.4);
    expect(bounds.bottom).toBe(-0.2);
    expect(bounds.radius).toBeCloseTo(0.084, 9);
    expect(bounds.centerY).toBeCloseTo(0.1, 9);
  });
});
