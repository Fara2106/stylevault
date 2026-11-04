// `deno test supabase/functions/delete-account/` (nessuna rete, nessuna chiave)
import { assertEquals, assertRejects } from 'jsr:@std/assert@1';
import { chunks, isConfirmed, listUserFiles, type ListFn } from './account.ts';

/** Finto storage: cartelle (id null) e file, come risponde /object/list. */
function fakeStorage(tree: Record<string, string[]>): ListFn {
  return async (prefix: string, offset: number) => {
    const names = tree[prefix] ?? [];
    return names.slice(offset, offset + 2).map((name) => ({
      name,
      id: tree[`${prefix}${name}/`] ? null : `id-${name}`,
    }));
  };
}

Deno.test('listUserFiles trova i file anche nelle sottocartelle e su più pagine', async () => {
  const list = fakeStorage({
    'u1/': ['a.jpg', 'b.jpg', 'cutouts', 'c.jpg'],
    'u1/cutouts/': ['d.png'],
  });
  const files = await listUserFiles(list, 'u1', 2);
  assertEquals(files.sort(), ['u1/a.jpg', 'u1/b.jpg', 'u1/c.jpg', 'u1/cutouts/d.png']);
});

Deno.test('listUserFiles: nessun file → lista vuota', async () => {
  assertEquals(await listUserFiles(fakeStorage({}), 'u2', 2), []);
});

Deno.test('listUserFiles rifiuta un id utente vuoto o con barre (mai la radice del bucket)', async () => {
  await assertRejects(() => listUserFiles(fakeStorage({}), '', 2));
  await assertRejects(() => listUserFiles(fakeStorage({}), 'a/b', 2));
});

Deno.test('chunks divide in blocchi della dimensione data', () => {
  assertEquals(chunks([1, 2, 3, 4, 5], 2), [[1, 2], [3, 4], [5]]);
  assertEquals(chunks([], 2), []);
});

Deno.test('isConfirmed vuole esattamente { confirm: "DELETE" }', () => {
  assertEquals(isConfirmed({ confirm: 'DELETE' }), true);
  assertEquals(isConfirmed({ confirm: 'delete' }), false);
  assertEquals(isConfirmed(null), false);
  assertEquals(isConfirmed({}), false);
});
