import { describe, it, expect } from 'vitest';
import { garmentProfile, radiusAt, GARMENT_KINDS, GARMENT_GAP } from './garmentMesh';
import { bodyProfiles } from './avatarMesh';

const cfg = { bodyShape: 'average', skinTone: 'medium', hairColor: 'brown', hairStyle: 'medium' };

const yRange = (profile) => {
  const ys = profile.map(([, y]) => y);
  return [Math.min(...ys), Math.max(...ys)];
};

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
    const body = bodyProfiles(cfg);
    const { profile } = garmentProfile('top', cfg);
    const shell = profile.slice(1, -1); // via i due punti di chiusura sull'asse
    expect(shell.length).toBeGreaterThan(10);
    for (const [r, y] of shell) {
      expect(r).toBeCloseTo(radiusAt(body.torso, y) + GARMENT_GAP, 9);
    }
  });

  it('il capospalla sta fuori del top: si indossa sopra', () => {
    const top = garmentProfile('top', cfg);
    const outer = garmentProfile('outerwear', cfg);
    const y = 1.2; // quota coperta da entrambi
    const radiusOf = ({ profile }) => radiusAt(profile.slice(1, -1), y);
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
