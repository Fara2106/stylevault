// `deno test supabase/functions/send-feedback/` (nessuna rete, nessuna chiave)
import { assert, assertEquals, assertStringIncludes } from 'jsr:@std/assert@1';
import { allowSend, buildEmail, parseFeedback, redactSensitive } from './feedback.ts';

Deno.test('parseFeedback accetta una segnalazione valida e tiene solo le info ammesse', () => {
  const parsed = parseFeedback({
    kind: 'bug',
    message: '  Il calendario non si apre  ',
    info: { source: 'app iOS', model: 'iPhone18,2\nriga', email: 'a@b.it', userId: 'x' },
  });
  assertEquals(parsed, {
    kind: 'bug',
    message: 'Il calendario non si apre',
    info: { source: 'app iOS', model: 'iPhone18,2 riga' },
  });
});

Deno.test('parseFeedback rifiuta tipo, messaggio corto o lungo e corpo assente', () => {
  assertEquals(parseFeedback(null), null);
  assertEquals(parseFeedback({ kind: 'spam', message: 'abbastanza lungo' }), null);
  assertEquals(parseFeedback({ kind: 'idea', message: 'corto' }), null);
  assertEquals(parseFeedback({ kind: 'idea', message: 'x'.repeat(2001) }), null);
  assertEquals(parseFeedback({ kind: 'idea', message: 42 }), null);
});

Deno.test('redactSensitive toglie email, numeri lunghi e IBAN, lascia il resto', () => {
  const out = redactSensitive(
    'scrivimi a mario.rossi@gmail.com o al +39 333 123 4567, carta 4111 1111 1111 1111, IBAN IT60X0542811101000000123456. Taglia 42, anno 2026.',
  );
  assert(!out.includes('mario.rossi'));
  assert(!out.includes('333'));
  assert(!out.includes('4111'));
  assert(!out.includes('IT60X'));
  assertStringIncludes(out, 'Taglia 42, anno 2026.');
});

Deno.test("buildEmail: oggetto dalla prima riga, info tecniche in coda, dati sensibili tolti", () => {
  const { subject, text } = buildEmail(
    {
      kind: 'idea',
      message: 'Vorrei ordinare i capi per colore\nanche nel calendario. a@b.it',
      info: { source: 'sito web', language: 'it' },
    },
    new Date('2026-11-03T10:00:00Z'),
  );
  assertEquals(subject, 'StyleVault · Idea: Vorrei ordinare i capi per colore');
  assertStringIncludes(text, "Tipo: Un'idea per migliorare");
  assertStringIncludes(text, 'Origine: sito web');
  assertStringIncludes(text, 'Lingua: it');
  assertStringIncludes(text, '[rimosso]');
  assertStringIncludes(text, 'Inviata: 2026-11-03T10:00:00.000Z');
});

Deno.test('allowSend ferma il sesto invio in 10 minuti e riparte dopo', () => {
  const log = new Map<string, number[]>();
  for (let i = 0; i < 5; i++) assert(allowSend(log, 'u1', i * 1000));
  assertEquals(allowSend(log, 'u1', 6000), false);
  assert(allowSend(log, 'u2', 6000), 'un altro utente non è frenato');
  assert(allowSend(log, 'u1', 10 * 60_000 + 1000));
});
