import { describe, it, expect } from 'vitest';
import { summarizeDay } from './dayParts';

/** 24 ore di un giorno; over(h) può cambiare i campi di ogni ora. */
const day = (over = () => ({})) =>
  Array.from({ length: 24 }, (_, hour) => ({
    hour,
    apparent: hour,
    precipProb: 0,
    code: 0,
    ...over(hour),
  }));

describe('summarizeDay', () => {
  it('fasce e media sulle ore 8–20 per un giorno futuro', () => {
    const s = summarizeDay(day(), { nowHour: null });
    expect(s.temperature).toBe(13.5);
    expect(s.parts.map((p) => p.key)).toEqual(['morning', 'afternoon', 'evening']);
    expect(s.parts.map((p) => p.temperature)).toEqual([9.5, 14, 18]);
    expect(s.parts.some((p) => p.past)).toBe(false);
  });

  it('oggi alle 15 conta solo da adesso', () => {
    const s = summarizeDay(day(), { nowHour: 15 });
    expect(s.temperature).toBe(17);
    expect(s.parts[0].past).toBe(true);
    expect(s.parts[1].past).toBe(false);
    expect(s.parts[2].past).toBe(false);
  });

  it('dopo le 20 o prima delle 8 conta tutta la giornata', () => {
    for (const nowHour of [21, 6]) {
      const s = summarizeDay(day(), { nowHour });
      expect(s.temperature).toBe(13.5);
      expect(s.parts.some((p) => p.past)).toBe(false);
    }
  });

  it('rainFrom: prima ora considerata con probabilità ≥ 45', () => {
    const evening = summarizeDay(day((h) => ({ precipProb: h >= 18 ? 50 : 10 })), {
      nowHour: null,
    });
    expect(evening.rainFrom).toBe(18);
    expect(evening.rainFromStart).toBe(false);

    const morning = summarizeDay(day(() => ({ precipProb: 50 })), { nowHour: null });
    expect(morning.rainFrom).toBe(8);
    expect(morning.rainFromStart).toBe(true);

    // Oggi alle 15: la prima ora considerata è le 15
    const today = summarizeDay(day(() => ({ precipProb: 50 })), { nowHour: 15 });
    expect(today.rainFrom).toBe(15);
    expect(today.rainFromStart).toBe(true);

    expect(summarizeDay(day(), { nowHour: null }).rainFrom).toBeNull();
  });

  it('codice e pioggia della fascia sono i massimi', () => {
    const s = summarizeDay(
      day((h) => ({ code: h === 13 ? 61 : 3, precipProb: h === 14 ? 70 : 5 })),
      { nowHour: null }
    );
    expect(s.parts[1].code).toBe(61);
    expect(s.parts[1].precipProb).toBe(70);
    expect(s.parts[0].code).toBe(3);
  });

  it('ore senza dati', () => {
    const s = summarizeDay(day(() => ({ apparent: null, precipProb: null, code: null })), {
      nowHour: null,
    });
    expect(s.temperature).toBeNull();
    for (const p of s.parts) {
      expect(p.temperature).toBeNull();
      expect(p.code).toBeNull();
      expect(p.precipProb).toBeNull();
    }
    expect(s.rainFrom).toBeNull();
  });
});
