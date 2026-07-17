import { describe, it, expect } from 'vitest';
import { shareFilePlan } from './tryOnShare';

describe('shareFilePlan', () => {
  const items = [
    { name: 'Camicia bianca', photo: 'data:image/png;base64,AAA' },
    { name: 'Jeans', photo: 'https://x.test/j.jpg' },
  ];

  it('persona per prima, capi numerati da 2 come nel prompt', () => {
    const plan = shareFilePlan('data:image/jpeg;base64,ME', items);
    expect(plan.map((p) => p.name)).toEqual(['1-persona', '2-camicia-bianca', '3-jeans']);
    expect(plan[0].source).toBe('data:image/jpeg;base64,ME');
    expect(plan[2].source).toBe('https://x.test/j.jpg');
  });

  it('senza foto persona: si parte comunque da 2 (Image 1 resta la persona)', () => {
    const plan = shareFilePlan(null, items);
    expect(plan.map((p) => p.name)).toEqual(['2-camicia-bianca', '3-jeans']);
  });

  it('nome capo mancante o non ascii: ripiego pulito', () => {
    const plan = shareFilePlan(null, [{ name: '', photo: 'p' }, { name: 'Été ♥', photo: 'q' }]);
    expect(plan.map((p) => p.name)).toEqual(['2-capo', '3-t']);
  });
});
