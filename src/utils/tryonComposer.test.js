import { describe, it, expect } from 'vitest';
import {
  emptyOutfit,
  slotForItem,
  slotCategories,
  applyItem,
  removeFromSlot,
  outfitHasItems,
  garmentLayers,
  MAX_ACCESSORIES,
} from './tryonComposer';

const item = (id, category) => ({ id, category, name: id, photo: 'p' });

describe('tryonComposer', () => {
  it('emptyOutfit ha tutti gli slot vuoti', () => {
    const o = emptyOutfit();
    expect(o.top).toBeNull();
    expect(o.bottom).toBeNull();
    expect(o.shoes).toBeNull();
    expect(o.outerwear).toBeNull();
    expect(o.accessories).toEqual([]);
    expect(outfitHasItems(o)).toBe(false);
  });

  it('slotForItem mappa le categorie sugli slot giusti', () => {
    expect(slotForItem(item('a', 'tops'))).toBe('top');
    expect(slotForItem(item('a', 'dresses'))).toBe('top');
    expect(slotForItem(item('a', 'bottoms'))).toBe('bottom');
    expect(slotForItem(item('a', 'shoes'))).toBe('shoes');
    expect(slotForItem(item('a', 'outerwear'))).toBe('outerwear');
    expect(slotForItem(item('a', 'accessories'))).toBe('accessories');
    expect(slotForItem(item('a', 'underwear'))).toBeNull();
  });

  it('slotCategories espone le categorie ammesse per slot', () => {
    expect(slotCategories('top')).toEqual(['tops', 'dresses']);
    expect(slotCategories('bottom')).toEqual(['bottoms']);
    expect(slotCategories('accessories')).toEqual(['accessories']);
  });

  it('applyItem riempie uno slot singolo', () => {
    const o = applyItem(emptyOutfit(), 'top', item('t1', 'tops'));
    expect(o.top.id).toBe('t1');
    expect(outfitHasItems(o)).toBe(true);
  });

  it('applyItem sostituisce il capo già presente nello slot', () => {
    let o = applyItem(emptyOutfit(), 'shoes', item('s1', 'shoes'));
    o = applyItem(o, 'shoes', item('s2', 'shoes'));
    expect(o.shoes.id).toBe('s2');
  });

  it('un abito nello slot top svuota il bottom', () => {
    let o = applyItem(emptyOutfit(), 'bottom', item('b1', 'bottoms'));
    o = applyItem(o, 'top', item('d1', 'dresses'));
    expect(o.top.id).toBe('d1');
    expect(o.bottom).toBeNull();
  });

  it('scegliere un bottom mentre è indossato un abito toglie l\'abito', () => {
    let o = applyItem(emptyOutfit(), 'top', item('d1', 'dresses'));
    o = applyItem(o, 'bottom', item('b1', 'bottoms'));
    expect(o.bottom.id).toBe('b1');
    expect(o.top).toBeNull();
  });

  it('gli accessori si aggiungono e si tolgono (toggle), con un massimo', () => {
    let o = emptyOutfit();
    o = applyItem(o, 'accessories', item('a1', 'accessories'));
    o = applyItem(o, 'accessories', item('a2', 'accessories'));
    expect(o.accessories.map((a) => a.id)).toEqual(['a1', 'a2']);

    // toggle: riselezionare lo stesso lo rimuove
    o = applyItem(o, 'accessories', item('a1', 'accessories'));
    expect(o.accessories.map((a) => a.id)).toEqual(['a2']);

    // limite massimo
    for (let i = 0; i < MAX_ACCESSORIES + 2; i++) {
      o = applyItem(o, 'accessories', item(`x${i}`, 'accessories'));
    }
    expect(o.accessories.length).toBe(MAX_ACCESSORIES);
  });

  it('removeFromSlot svuota lo slot o il singolo accessorio', () => {
    let o = applyItem(emptyOutfit(), 'top', item('t1', 'tops'));
    o = applyItem(o, 'accessories', item('a1', 'accessories'));
    o = removeFromSlot(o, 'top');
    expect(o.top).toBeNull();
    o = removeFromSlot(o, 'accessories', 'a1');
    expect(o.accessories).toEqual([]);
  });

  it('applyItem non muta l\'outfit di partenza', () => {
    const base = emptyOutfit();
    applyItem(base, 'top', item('t1', 'tops'));
    expect(base.top).toBeNull();
  });

  it('garmentLayers: outfit vuoto o assente → nessun layer', () => {
    expect(garmentLayers(null)).toEqual([]);
    expect(garmentLayers(emptyOutfit())).toEqual([]);
  });

  it('garmentLayers: top+bottom → il bottom si disegna prima del top', () => {
    let o = applyItem(emptyOutfit(), 'top', item('t1', 'tops'));
    o = applyItem(o, 'bottom', item('b1', 'bottoms'));
    const kinds = garmentLayers(o).map((l) => l.kind);
    expect(kinds.indexOf('bottom')).toBeLessThan(kinds.indexOf('top'));
  });

  it('garmentLayers: un abito produce il layer "dress", non "top"', () => {
    const o = applyItem(emptyOutfit(), 'top', item('d1', 'dresses'));
    const layers = garmentLayers(o);
    expect(layers.map((l) => l.kind)).toEqual(['dress']);
    expect(layers[0].item.id).toBe('d1');
  });

  it('garmentLayers: il capospalla si disegna sopra top e bottom', () => {
    let o = applyItem(emptyOutfit(), 'top', item('t1', 'tops'));
    o = applyItem(o, 'bottom', item('b1', 'bottoms'));
    o = applyItem(o, 'outerwear', item('o1', 'outerwear'));
    const kinds = garmentLayers(o).map((l) => l.kind);
    expect(kinds.indexOf('outerwear')).toBeGreaterThan(kinds.indexOf('top'));
    expect(kinds.indexOf('outerwear')).toBeGreaterThan(kinds.indexOf('bottom'));
  });

  it('garmentLayers: le scarpe compaiono, gli accessori no', () => {
    let o = applyItem(emptyOutfit(), 'shoes', item('s1', 'shoes'));
    o = applyItem(o, 'accessories', item('a1', 'accessories'));
    const kinds = garmentLayers(o).map((l) => l.kind);
    expect(kinds).toContain('shoes');
    expect(kinds).not.toContain('accessories');
  });
});
