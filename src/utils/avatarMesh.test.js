import { describe, it, expect } from 'vitest';
import { bodyProfiles } from './avatarMesh';

const cfg = (bodyShape) => ({
  bodyShape,
  skinTone: 'medium',
  hairColor: 'brown',
  hairStyle: 'medium',
});

const maxRadius = (profile) => Math.max(...profile.map(([r]) => r));

describe('bodyProfiles', () => {
  it('produce profili non vuoti con raggi e altezze positive', () => {
    const p = bodyProfiles(cfg('average'));
    expect(p.torso.length).toBeGreaterThan(3);
    expect(p.leg.length).toBeGreaterThan(3);
    expect(p.arm.length).toBeGreaterThan(1);
    for (const [r, y] of p.torso) {
      expect(r).toBeGreaterThan(0);
      expect(y).toBeGreaterThanOrEqual(0);
    }
  });

  it('la corporatura allarga il torso: plus è più largo di slim', () => {
    expect(maxRadius(bodyProfiles(cfg('plus')).torso)).toBeGreaterThan(
      maxRadius(bodyProfiles(cfg('slim')).torso)
    );
  });

  it('la corporatura scala i raggi esattamente come widthFactor', () => {
    const slim = bodyProfiles(cfg('slim'));
    const average = bodyProfiles(cfg('average'));
    expect(slim.widthFactor).toBeCloseTo(0.88, 5);
    expect(maxRadius(slim.torso) / maxRadius(average.torso)).toBeCloseTo(0.88, 5);
  });

  it('la testa non si allarga con la corporatura', () => {
    expect(bodyProfiles(cfg('plus')).head.radius).toBeCloseTo(
      bodyProfiles(cfg('slim')).head.radius,
      5
    );
  });

  it('non altera le altezze: la testa sta sempre alla stessa quota', () => {
    expect(bodyProfiles(cfg('plus')).head.y).toBeCloseTo(
      bodyProfiles(cfg('slim')).head.y,
      5
    );
  });

  it('riporta i colori risolti da avatarOptions', () => {
    const p = bodyProfiles(cfg('average'));
    expect(p.skinHex).toBe('#C99A6E');
    expect(p.hairHex).toBe('#6B4A2F');
    expect(p.hairStyle).toBe('medium');
  });

  it('con config assente usa i valori di default senza esplodere', () => {
    expect(() => bodyProfiles(undefined)).not.toThrow();
    expect(bodyProfiles(undefined).widthFactor).toBeCloseTo(1, 5);
  });
});
