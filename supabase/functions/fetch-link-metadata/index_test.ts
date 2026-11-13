// `deno test supabase/functions/fetch-link-metadata/` (nessuna rete)
import { assertEquals } from 'jsr:@std/assert@1';
import { isPublicHttpUrl } from './guard.ts';

Deno.test('isPublicHttpUrl accetta le pagine dei negozi', () => {
  assertEquals(isPublicHttpUrl('https://www.zalando.it/capo.html'), true);
  assertEquals(isPublicHttpUrl('http://shop.example.com/p?id=1'), true);
});

Deno.test('isPublicHttpUrl rifiuta indirizzi interni, altri protocolli e testo', () => {
  for (const url of [
    'http://localhost:8080/',
    'http://127.0.0.1/',
    'http://10.0.0.5/',
    'http://192.168.1.1/admin',
    'http://172.16.0.1/',
    'http://169.254.169.254/latest/meta-data',
    'http://[::1]/',
    'http://0.0.0.0/',
    'http://intranet/',
    'http://db.internal/',
    'ftp://example.com/file',
    'file:///etc/passwd',
    'non è un link',
    '',
  ]) {
    assertEquals(isPublicHttpUrl(url), false, url);
  }
});
