import { describe, it, expect } from 'vitest';
import { panelPlacement } from './garmentPanel';

// Profilo semplice: raggio max 0.2, quote da 1.0 a 1.5 (altezza zona = 0.5).
const profile = [
  [0.001, 1.0],
  [0.2, 1.1],
  [0.2, 1.4],
  [0.001, 1.5],
];
const arc = Math.PI; // 180°, frontWidth = radius * PI

describe('panelPlacement', () => {
  it('centra il pannello a meta della zona del capo', () => {
    const p = panelPlacement({ profile, aspect: 1, arc, gap: 0 });
    expect(p.yCenter).toBeCloseTo(1.25, 5);
  });

  it('senza mirror, raggio = raggio massimo del profilo + gap', () => {
    const p = panelPlacement({ profile, aspect: 1, arc, gap: 0.02 });
    expect(p.radius).toBeCloseTo(0.22, 5);
  });

  it('con mirror, raggio = offsetX + raggio massimo + gap (avvolge entrambe le gambe)', () => {
    const p = panelPlacement({ profile, offsetX: 0.06, mirror: true, aspect: 1, arc, gap: 0.02 });
    expect(p.radius).toBeCloseTo(0.28, 5);
  });

  it('capo alto e stretto (aspect piccolo): limite in altezza, usa tutta altezza zona', () => {
    const p = panelPlacement({ profile, aspect: 0.25, arc, gap: 0 });
    expect(p.height).toBeCloseTo(0.5, 5); // = altezza zona
    // panelWidth = 0.5 * 0.25 = 0.125; arcAngle = 0.125 / 0.2 = 0.625
    expect(p.arcAngle).toBeCloseTo(0.625, 5);
  });

  it('capo largo (aspect grande): limite in larghezza, non supera arco massimo', () => {
    const p = panelPlacement({ profile, aspect: 10, arc, gap: 0 });
    expect(p.arcAngle).toBeCloseTo(arc, 5); // arcAngle = frontWidth/radius = arc
    expect(p.height).toBeLessThan(0.5);      // altezza ridotta per tenere le proporzioni
  });

  it('piu il capo e stretto, piu arco e piccolo (monotonico)', () => {
    const stretto = panelPlacement({ profile, aspect: 0.2, arc, gap: 0 });
    const largo = panelPlacement({ profile, aspect: 0.6, arc, gap: 0 });
    expect(largo.arcAngle).toBeGreaterThan(stretto.arcAngle);
  });
});
