import { describe, it, expect } from 'vitest';
import { rowToItem, itemToRow, stalePhotoPaths } from './db';

const base = { name: 'Maglione', category: 'tops', colors: [] };

describe('itemToRow — retro del capo', () => {
  it('un retro esterno (link shop) va in photo_back_url', () => {
    const row = itemToRow({ ...base, photoBack: 'https://x/b.jpg' }, 'u1');
    expect(row.photo_back_url).toBe('https://x/b.jpg');
    expect(row.photo_back_path).toBeNull();
  });

  it('un retro caricato su Storage va in photo_back_path, senza url', () => {
    const row = itemToRow(
      { ...base, photoBack: 'https://signed/b', photoBackPath: 'u1/b.jpg' },
      'u1'
    );
    expect(row.photo_back_path).toBe('u1/b.jpg');
    expect(row.photo_back_url).toBeNull();
  });

  it('senza retro entrambi i campi sono null', () => {
    const row = itemToRow(base, 'u1');
    expect(row.photo_back_path).toBeNull();
    expect(row.photo_back_url).toBeNull();
  });
});

describe('rowToItem — retro del capo', () => {
  it('il retro su Storage usa la mappa delle URL firmate', () => {
    const urls = new Map([['u1/b.jpg', 'https://signed/b']]);
    const item = rowToItem({ id: '1', ...base, photo_back_path: 'u1/b.jpg' }, urls);
    expect(item.photoBack).toBe('https://signed/b');
    expect(item.photoBackPath).toBe('u1/b.jpg');
  });

  it('il retro esterno passa così com\'è; senza retro è stringa vuota', () => {
    expect(rowToItem({ id: '1', ...base, photo_back_url: 'https://x/b.jpg' }, new Map()).photoBack)
      .toBe('https://x/b.jpg');
    expect(rowToItem({ id: '1', ...base }, new Map()).photoBack).toBe('');
  });
});

describe('stalePhotoPaths — file da cancellare dopo una modifica', () => {
  it('retro tolto o sostituito: il file vecchio va cancellato', () => {
    expect(
      stalePhotoPaths({ photoPath: 'u/a.jpg', photoBackPath: 'u/b.jpg' }, { photoPath: 'u/a.jpg', photoBackPath: null })
    ).toEqual(['u/b.jpg']);
    expect(
      stalePhotoPaths({ photoPath: 'u/a.jpg', photoBackPath: 'u/b.jpg' }, { photoPath: 'u/c.jpg', photoBackPath: 'u/d.jpg' })
    ).toEqual(['u/a.jpg', 'u/b.jpg']);
  });

  it('niente cambiato: niente da cancellare', () => {
    expect(stalePhotoPaths({ photoPath: 'u/a.jpg', photoBackPath: null }, { photoPath: 'u/a.jpg' })).toEqual([]);
  });
});
