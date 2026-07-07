import { describe, it, expect } from 'vitest';
import { generateOutfits } from './outfitAlgorithm';

/** Item di test con default sensati. */
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

const WEATHER = {
  temperature: 20,
  windSpeed: 5,
  rain: false,
  snow: false,
  uvIndex: 3,
  date: '2026-07-08',
};

const baseWardrobe = () => [
  mk('top1', 'tops'),
  mk('top2', 'tops'),
  mk('top3', 'tops'),
  mk('bottom1', 'bottoms'),
  mk('bottom2', 'bottoms'),
  mk('shoes1', 'shoes'),
  mk('shoes2', 'shoes'),
];

describe('generateOutfits (comportamento base)', () => {
  it('genera outfit completi con top, bottom e scarpe', () => {
    const outfits = generateOutfits(baseWardrobe(), WEATHER, 'all', 3);
    expect(outfits.length).toBeGreaterThan(0);
    for (const o of outfits) {
      expect(o.top).toBeTruthy();
      expect(o.bottom).toBeTruthy();
      expect(o.shoes).toBeTruthy();
      expect(o.score).toBeGreaterThan(0);
    }
  });

  it('restituisce [] con guardaroba vuoto', () => {
    expect(generateOutfits([], WEATHER)).toEqual([]);
  });
});

describe('generateOutfits — blocco capi (options.lockedItems)', () => {
  it('ogni outfit generato contiene i capi bloccati nel loro slot', () => {
    const wardrobe = baseWardrobe();
    const lockedTop = wardrobe[1]; // top2
    for (let run = 0; run < 5; run++) {
      const outfits = generateOutfits(wardrobe, WEATHER, 'all', 3, {
        lockedItems: [lockedTop],
      });
      expect(outfits.length).toBeGreaterThan(0);
      for (const o of outfits) {
        expect(o.top.id).toBe('top2');
      }
    }
  });

  it('blocca anche bottom e scarpe insieme', () => {
    const wardrobe = baseWardrobe();
    const locked = [wardrobe[3], wardrobe[5]]; // bottom1, shoes1
    const outfits = generateOutfits(wardrobe, WEATHER, 'all', 3, {
      lockedItems: locked,
    });
    for (const o of outfits) {
      expect(o.bottom.id).toBe('bottom1');
      expect(o.shoes.id).toBe('shoes1');
    }
  });
});

describe('generateOutfits — penalità ripetizione (options.recentWear)', () => {
  it('un capo indossato di recente abbassa il punteggio', () => {
    // Guardaroba minimo: una sola combinazione possibile
    const wardrobe = [mk('top1', 'tops'), mk('bottom1', 'bottoms'), mk('shoes1', 'shoes')];

    const [fresh] = generateOutfits(wardrobe, WEATHER, 'all', 1);
    const [worn] = generateOutfits(wardrobe, WEATHER, 'all', 1, {
      recentWear: [{ itemId: 'top1', date: '2026-07-07' }],
      referenceDate: '2026-07-08',
    });

    expect(worn.score).toBeLessThan(fresh.score);
  });

  it('un capo indossato più di 7 giorni fa non penalizza', () => {
    const wardrobe = [mk('top1', 'tops'), mk('bottom1', 'bottoms'), mk('shoes1', 'shoes')];

    const [fresh] = generateOutfits(wardrobe, WEATHER, 'all', 1);
    const [old] = generateOutfits(wardrobe, WEATHER, 'all', 1, {
      recentWear: [{ itemId: 'top1', date: '2026-06-20' }],
      referenceDate: '2026-07-08',
    });

    expect(old.score).toBe(fresh.score);
  });
});

describe('generateOutfits — stagione dal giorno selezionato', () => {
  it('usa la data del meteo per la stagione, non quella odierna', () => {
    // Capi solo invernali: con data di gennaio devono uscire outfit
    const winter = [
      mk('top1', 'tops', { season: 'winter', warmthLevel: 4 }),
      mk('bottom1', 'bottoms', { season: 'winter', warmthLevel: 4 }),
      mk('shoes1', 'shoes', { season: 'winter', warmthLevel: 4 }),
    ];
    const janWeather = { ...WEATHER, temperature: 2, date: '2027-01-15' };
    const outfits = generateOutfits(winter, janWeather, 'all', 1);
    expect(outfits.length).toBe(1);

    // ...e con data di luglio non deve uscire nulla (capi winter, stagione summer)
    const julWeather = { ...WEATHER, date: '2026-07-08' };
    expect(generateOutfits(winter, julWeather, 'all', 1)).toEqual([]);
  });
});
