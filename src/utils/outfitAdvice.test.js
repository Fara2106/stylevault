import { describe, it, expect } from 'vitest';
import { getOutfitAdvice } from './outfitAdvice';

const mk = (id, category, over = {}) => ({
  id,
  name: id,
  category,
  subcategory: '',
  colors: ['black'],
  season: 'all',
  occasion: 'casual',
  warmthLevel: 2,
  photo: '',
  ...over,
});

const outfitOf = (over = {}) => ({
  top: mk('top1', 'tops'),
  bottom: mk('bottom1', 'bottoms'),
  shoes: mk('shoes1', 'shoes'),
  outerwear: null,
  accessories: [],
  score: 80,
  weatherMatch: 80,
  colorHarmony: 85,
  ...over,
});

const weatherOf = (over = {}) => ({
  temperature: 20,
  windSpeed: 5,
  rain: false,
  snow: false,
  uvIndex: 3,
  date: '2026-07-08',
  ...over,
});

const keys = (advice) => advice.map((a) => a.key);

describe('getOutfitAdvice — colori', () => {
  it('elogia i colori quando l\'armonia è alta', () => {
    const outfit = outfitOf({
      top: mk('t', 'tops', { colors: ['white'] }),
      bottom: mk('b', 'bottoms', { colors: ['navy'] }),
      colorHarmony: 88,
    });
    expect(keys(getOutfitAdvice(outfit, weatherOf()))).toContain('advice.colorsHarmonious');
  });

  it('riconosce la palette monocromatica', () => {
    const advice = getOutfitAdvice(outfitOf({ colorHarmony: 88 }), weatherOf());
    expect(keys(advice)).toContain('advice.monochrome');
  });

  it('segnala colori che stridono quando l\'armonia è bassa', () => {
    const advice = getOutfitAdvice(outfitOf({ colorHarmony: 40 }), weatherOf());
    expect(keys(advice)).toContain('advice.colorsClash');
  });

  it('segnala troppi colori accesi', () => {
    const outfit = outfitOf({
      top: mk('t', 'tops', { colors: ['red'] }),
      bottom: mk('b', 'bottoms', { colors: ['green'] }),
      shoes: mk('s', 'shoes', { colors: ['purple'] }),
      outerwear: mk('o', 'outerwear', { colors: ['orange'] }),
      colorHarmony: 55,
    });
    expect(keys(getOutfitAdvice(outfit, weatherOf()))).toContain('advice.tooManyColors');
  });
});

describe('getOutfitAdvice — meteo', () => {
  it('troppo leggero per il freddo', () => {
    // target a 2° è 4-5, capi warmth 1
    const outfit = outfitOf({
      top: mk('t', 'tops', { warmthLevel: 1 }),
      bottom: mk('b', 'bottoms', { warmthLevel: 1 }),
      shoes: mk('s', 'shoes', { warmthLevel: 1 }),
    });
    const advice = getOutfitAdvice(outfit, weatherOf({ temperature: 2 }));
    const tooLight = advice.find((a) => a.key === 'advice.tooLight');
    expect(tooLight).toBeTruthy();
    expect(tooLight.params.temp).toBeDefined();
  });

  it('troppo caldo per l\'estate', () => {
    const outfit = outfitOf({
      top: mk('t', 'tops', { warmthLevel: 5 }),
      bottom: mk('b', 'bottoms', { warmthLevel: 5 }),
      shoes: mk('s', 'shoes', { warmthLevel: 5 }),
    });
    expect(keys(getOutfitAdvice(outfit, weatherOf({ temperature: 32 })))).toContain(
      'advice.tooWarm'
    );
  });

  it('pioggia + sandali → consiglia scarpe chiuse', () => {
    const outfit = outfitOf({
      shoes: mk('s', 'shoes', { subcategory: 'sandals' }),
      outerwear: mk('o', 'outerwear', { subcategory: 'raincoat' }),
    });
    expect(keys(getOutfitAdvice(outfit, weatherOf({ rain: true })))).toContain(
      'advice.rainShoes'
    );
  });

  it('pioggia senza capospalla → serve capo esterno', () => {
    const outfit = outfitOf({ outerwear: null });
    expect(keys(getOutfitAdvice(outfit, weatherOf({ rain: true, temperature: 15 })))).toContain(
      'advice.rainOuter'
    );
  });
});

describe('getOutfitAdvice — ripetizione e occasione', () => {
  it('avvisa se un capo è stato indossato di recente', () => {
    const advice = getOutfitAdvice(outfitOf(), weatherOf(), {
      recentWear: [{ itemId: 'top1', date: '2026-07-06' }],
    });
    const worn = advice.find((a) => a.key === 'advice.wornRecently');
    expect(worn).toBeTruthy();
    expect(worn.params.date).toBe('2026-07-06');
  });

  it('blazer su outfit casual eleva il look', () => {
    const outfit = outfitOf({
      outerwear: mk('o', 'outerwear', { subcategory: 'blazer' }),
    });
    expect(keys(getOutfitAdvice(outfit, weatherOf(), { occasion: 'casual' }))).toContain(
      'advice.elevated'
    );
  });
});
