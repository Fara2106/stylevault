import { describe, it, expect } from 'vitest';
import {
  getWearStats,
  getMostWorn,
  getLeastWorn,
  getCategoryBreakdown,
  getColorBreakdown,
  getCostPerWear,
} from './statistics';

const mk = (id, category, over = {}) => ({
  id,
  name: id,
  category,
  colors: ['black'],
  ...over,
});

const top = mk('top1', 'tops', { colors: ['white', 'navy'], price: 60 });
const bottom = mk('bottom1', 'bottoms', { price: 100 });
const shoes = mk('shoes1', 'shoes');
const items = [top, bottom, shoes];

const log = (date, outfit, worn = true) => ({ id: `l${date}`, date, outfit, worn });
const history = [
  log('2026-07-01', { top, bottom, shoes, outerwear: null, accessories: [] }),
  log('2026-07-03', { top, bottom: null, shoes, outerwear: null, accessories: [] }),
  // pianificato: non deve contare
  log('2026-07-05', { top, bottom, shoes, outerwear: null, accessories: [] }, false),
];

describe('getWearStats', () => {
  it('conta solo le voci indossate e tiene l\'ultima data', () => {
    const stats = getWearStats(history);
    expect(stats.get('top1')).toEqual({ count: 2, lastDate: '2026-07-03' });
    expect(stats.get('bottom1')).toEqual({ count: 1, lastDate: '2026-07-01' });
  });
});

describe('classifiche', () => {
  it('mostWorn ordina per utilizzi decrescenti', () => {
    const most = getMostWorn(items, history);
    expect(most[0].item.id).toBe('top1');
    expect(most[0].count).toBe(2);
  });

  it('leastWorn mette i mai indossati per primi', () => {
    const wardrobe = [...items, mk('nuovo', 'tops')];
    const least = getLeastWorn(wardrobe, history);
    expect(least[0].item.id).toBe('nuovo');
    expect(least[0].count).toBe(0);
  });
});

describe('ripartizioni', () => {
  it('per categoria', () => {
    const wardrobe = [...items, mk('top2', 'tops')];
    expect(getCategoryBreakdown(wardrobe)[0]).toEqual({ category: 'tops', count: 2 });
  });

  it('per colore, contando i multicolore', () => {
    const byColor = getColorBreakdown(items);
    expect(byColor.find((c) => c.color === 'black').count).toBe(2);
    expect(byColor.find((c) => c.color === 'white').count).toBe(1);
  });
});

describe('getCostPerWear', () => {
  it('divide il prezzo per gli utilizzi e ordina dal più conveniente', () => {
    const result = getCostPerWear(items, history);
    // top1: 60/2=30 · bottom1: 100/1=100 · shoes1 senza prezzo escluso
    expect(result).toHaveLength(2);
    expect(result[0].item.id).toBe('top1');
    expect(result[0].costPerWear).toBe(30);
    expect(result[1].costPerWear).toBe(100);
  });
});
