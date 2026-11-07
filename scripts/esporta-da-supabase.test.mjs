import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { makeZip, outfitItemIds, toBundle } from './esporta-da-supabase.mjs';

const photos = {
  front: (row) => (row.photo_path ? `photos/${row.id}-front.jpg` : null),
  back: () => null,
  body: () => [],
};

test('le righe diventano il documento che l\'app importa', () => {
  const bundle = toBundle({
    items: [{ id: 'a', name: 'Maglia', category: 'tops', colors: ['red'], warmth_level: 3, price: '12.50', favorite: true,
      photo_path: 'u/a.jpg', created_at: '2026-07-19T10:00:00.000Z' }],
    wishlist: [],
    outfits: [{ id: 'o', item_ids: ['a', 'sparito'], created_at: '2026-07-19T10:00:00.000Z' }],
    calendar: [{ id: 'c', date: '2026-07-20', worn: true, payload: { top: { id: 'a' } }, created_at: '2026-07-19T10:00:00.000Z' }],
    profile: { theme: 'dark', default_city: { name: 'Roma', latitude: 41.9, longitude: 12.5, country: 'Italia' }, armocromia: { season: 'true-autumn' } },
  }, photos, new Date('2026-11-06T22:00:00Z'));
  assert.equal(bundle.version, 1);
  assert.equal(bundle.items[0].warmthLevel, 3);
  assert.equal(bundle.items[0].price, 12.5);
  assert.equal(bundle.items[0].photoFront, 'photos/a-front.jpg');
  assert.deepEqual(bundle.outfits[0].itemIDs, ['a']);
  assert.equal(bundle.calendar[0].day, '2026-07-20');
  assert.deepEqual(bundle.calendar[0].itemIDs, ['a']);
  assert.equal(bundle.profile.cityName, 'Roma');
  assert.deepEqual(JSON.parse(bundle.profile.armocromia), { season: 'true-autumn' });
});

test('le categorie personali restano collegate ai capi', () => {
  const row = { id: 'a', name: 'Telo', category: 'custom_1', created_at: '2026-07-19T10:00:00.000Z' };
  const bundle = toBundle({ items: [row, { ...row, id: 'b' }], wishlist: [], outfits: [], calendar: [], profile: null }, photos);
  assert.deepEqual(bundle.customCategories.map((c) => c.id), ['custom_1']);
  assert.equal(bundle.customCategories[0].name, 'Categoria 1');
});

test('lo storico ricorda i capi che non esistono più', () => {
  const bundle = toBundle({
    items: [{ id: 'a', name: 'Maglia', category: 'tops', created_at: '2026-07-19T10:00:00.000Z' }],
    wishlist: [{ id: 'w', name: 'Telo', category: null, created_at: '2026-07-19T10:00:00.000Z' },
      { id: 'x', name: 'Borsa', category: 'custom_2', created_at: '2026-07-19T10:00:00.000Z' }],
    outfits: [{ id: 'o', payload: { score: 80, top: { id: 'a' } }, created_at: '2026-07-19T10:00:00.000Z' }],
    calendar: [{ id: 'c', date: '2026-07-20', worn: true, created_at: '2026-07-19T10:00:00.000Z',
      payload: { top: { id: 'a', name: 'Maglia' }, shoes: { id: 'via', name: 'Stivali', category: 'shoes' } } }],
    profile: null,
  }, photos);
  assert.deepEqual(bundle.calendar[0].itemIDs, ['a', 'via']);
  assert.deepEqual(bundle.calendar[0].snapshot, [{ id: 'via', name: 'Stivali', category: 'shoes' }]);
  assert.equal(bundle.wishlist[0].category, 'other');
  assert.deepEqual(bundle.customCategories.map((c) => c.id), ['custom_2']);
  assert.equal(bundle.outfits[0].score, 80);
});

test('chi non ha un profilo si esporta lo stesso', () => {
  const bundle = toBundle({ items: [], wishlist: [], outfits: [], calendar: [], profile: null }, photos);
  assert.equal(bundle.profile, null);
});

test('i capi di un outfit si trovano anche negli accessori', () => {
  assert.deepEqual(outfitItemIds({ top: { id: 'a' }, accessories: [{ id: 'b' }], shoes: null }), ['a', 'b']);
  assert.deepEqual(outfitItemIds(undefined), []);
});

test('lo zip si apre con gli strumenti standard', () => {
  const path = join(mkdtempSync(join(tmpdir(), 'sv-')), 'prova.zip');
  writeFileSync(path, makeZip([['stylevault-export.json', Buffer.from('{"ok":true}')], ['photos/a.jpg', Buffer.from([1, 2, 3])]]));
  execFileSync('unzip', ['-tq', path]);
  assert.equal(execFileSync('unzip', ['-p', path, 'stylevault-export.json']).toString(), '{"ok":true}');
});
