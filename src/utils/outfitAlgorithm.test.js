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
    // Un capo per stagione: gennaio sceglie quelli invernali, luglio quelli estivi
    const wardrobe = [
      mk('topW', 'tops', { season: 'winter', warmthLevel: 4 }),
      mk('bottomW', 'bottoms', { season: 'winter', warmthLevel: 4 }),
      mk('shoesW', 'shoes', { season: 'winter', warmthLevel: 4 }),
      mk('topS', 'tops', { season: 'summer', warmthLevel: 1 }),
      mk('bottomS', 'bottoms', { season: 'summer', warmthLevel: 1 }),
      mk('shoesS', 'shoes', { season: 'summer', warmthLevel: 1 }),
    ];
    const janWeather = { ...WEATHER, temperature: 2, date: '2027-01-15' };
    const [jan] = generateOutfits(wardrobe, janWeather, 'all', 1);
    expect([jan.top.id, jan.bottom.id, jan.shoes.id]).toEqual(['topW', 'bottomW', 'shoesW']);

    const julWeather = { ...WEATHER, temperature: 2, date: '2026-07-08' };
    const [jul] = generateOutfits(wardrobe, julWeather, 'all', 1);
    expect([jul.top.id, jul.bottom.id, jul.shoes.id]).toEqual(['topS', 'bottomS', 'shoesS']);
  });
});

describe('generateOutfits — guardaroba incompleto', () => {
  it('genera lo stesso senza pantaloni né scarpe e segna cosa manca', () => {
    const outfits = generateOutfits([mk('top1', 'tops')], WEATHER, 'all', 3);
    expect(outfits).toHaveLength(1);
    expect(outfits[0].top.id).toBe('top1');
    expect(outfits[0].bottom).toBeNull();
    expect(outfits[0].shoes).toBeNull();
    expect(outfits[0].missing).toEqual(['bottom', 'shoes']);
  });

  it('senza top segna il top mancante', () => {
    const outfits = generateOutfits(
      [mk('bottom1', 'bottoms'), mk('shoes1', 'shoes')],
      WEATHER,
      'all',
      3
    );
    expect(outfits).toHaveLength(1);
    expect(outfits[0].top).toBeNull();
    expect(outfits[0].missing).toEqual(['top']);
  });

  it('un outfit completo non ha pezzi mancanti', () => {
    const outfits = generateOutfits(baseWardrobe(), WEATHER, 'all', 3);
    for (const o of outfits) expect(o.missing).toEqual([]);
  });

  it('con un abito non serve il pantalone', () => {
    const outfits = generateOutfits(
      [mk('dress1', 'dresses', { occasion: 'formal' }), mk('shoes1', 'shoes', { occasion: 'formal' })],
      WEATHER,
      'formal',
      3
    );
    expect(outfits.length).toBeGreaterThan(0);
    expect(outfits[0].top.id).toBe('dress1');
    expect(outfits[0].missing).toEqual([]);
  });

  it('se di un pezzo ci sono solo capi di altra stagione usa quelli', () => {
    const outfits = generateOutfits(
      [mk('top1', 'tops'), mk('bottom1', 'bottoms'), mk('boots', 'shoes', { season: 'winter' })],
      WEATHER,
      'all',
      3
    );
    expect(outfits[0].shoes.id).toBe('boots');
    expect(outfits[0].bottom.id).toBe('bottom1');
    expect(outfits[0].missing).toEqual([]);
  });

  it('con soli accessori non genera niente', () => {
    expect(generateOutfits([mk('bag', 'accessories')], WEATHER, 'all', 3)).toEqual([]);
  });
});
