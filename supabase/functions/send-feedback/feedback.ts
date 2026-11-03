// Regole della segnalazione, senza rete: le prova `deno test` (feedback_test.ts).
// Il sito fa gli stessi controlli prima di inviare (src/services/feedback.js):
// qui sono la rete di sicurezza, perché la funzione è pubblica.

export const MESSAGE_MIN = 10;
export const MESSAGE_MAX = 2000;
export const KINDS = { bug: 'Qualcosa non va', idea: "Un'idea per migliorare" } as const;
export type Kind = keyof typeof KINDS;

/** Info tecniche ammesse (nient'altro passa) e lunghezza massima di ognuna. */
const INFO_FIELDS = {
  source: 120,
  appVersion: 120,
  osVersion: 120,
  model: 120,
  language: 20,
  userAgent: 300,
} as const;
const INFO_LABELS: Record<keyof typeof INFO_FIELDS, string> = {
  source: 'Origine',
  appVersion: 'Versione app',
  osVersion: 'Sistema',
  model: 'Dispositivo',
  language: 'Lingua',
  userAgent: 'Browser',
};

export type Info = Partial<Record<keyof typeof INFO_FIELDS, string>>;
export interface Feedback {
  kind: Kind;
  message: string;
  info: Info;
}

/** Corpo della richiesta → segnalazione pulita; null se non valida. */
export function parseFeedback(body: unknown): Feedback | null {
  if (!body || typeof body !== 'object') return null;
  const { kind, message, info } = body as Record<string, unknown>;
  if (typeof kind !== 'string' || !(kind in KINDS)) return null;
  if (typeof message !== 'string') return null;
  const text = message.trim();
  if (text.length < MESSAGE_MIN || text.length > MESSAGE_MAX) return null;

  const clean: Info = {};
  if (info && typeof info === 'object') {
    for (const [field, max] of Object.entries(INFO_FIELDS)) {
      const value = (info as Record<string, unknown>)[field];
      if (typeof value !== 'string') continue;
      // Una riga sola: niente a capo o caratteri di controllo nelle info
      const line = value.replace(/[\u0000-\u001f\u007f]+/g, ' ').trim().slice(0, max);
      if (line) clean[field as keyof Info] = line;
    }
  }
  return { kind: kind as Kind, message: text, info: clean };
}

const SENSITIVE = [
  /[^\s@]+@[^\s@]+\.[^\s@]+/g, // email
  /\b[A-Z]{2}\d{2}(?:\s?[A-Z0-9]){11,30}\b/g, // IBAN
  /\+?\d(?:[\s.\-/]?\d){8,}/g, // telefono, carta, documento: 9+ cifre
];

/** Toglie quello che sembra un dato personale sfuggito all'avviso. */
export function redactSensitive(text: string): string {
  return SENSITIVE.reduce((out, re) => out.replace(re, '[rimosso]'), text);
}

/** Oggetto e testo dell'email (solo testo: niente HTML da iniettare). */
export function buildEmail({ kind, message, info }: Feedback, sentAt: Date) {
  const safe = redactSensitive(message);
  const firstLine = safe.split('\n')[0].slice(0, 60);
  const subject = `StyleVault · ${kind === 'bug' ? 'Problema' : 'Idea'}: ${firstLine}`;
  const infoLines = (Object.keys(INFO_LABELS) as (keyof Info)[])
    .filter((field) => info[field])
    .map((field) => `${INFO_LABELS[field]}: ${info[field]}`);
  const text = [
    `Tipo: ${KINDS[kind]}`,
    '',
    safe,
    '',
    '— Info tecniche (allegate in automatico) —',
    ...(infoLines.length ? infoLines : ['(nessuna)']),
    `Inviata: ${sentAt.toISOString()}`,
  ].join('\n');
  return { subject, text };
}

/**
 * Freno contro gli invii a raffica: al massimo `limit` segnalazioni per
 * utente nella finestra. Vale per la singola istanza della funzione (Supabase
 * può averne più d'una): basta a non bruciare il piano gratuito di Resend.
 */
export function allowSend(
  log: Map<string, number[]>,
  userId: string,
  now: number,
  limit = 5,
  windowMs = 10 * 60_000,
): boolean {
  const recent = (log.get(userId) ?? []).filter((t) => now - t < windowMs);
  if (recent.length >= limit) {
    log.set(userId, recent);
    return false;
  }
  log.set(userId, [...recent, now]);
  return true;
}
