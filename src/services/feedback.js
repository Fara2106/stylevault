/**
 * Segnalazioni "Feedback": le invia la Edge Function `send-feedback`
 * (supabase/functions/), che le manda per email con Resend.
 * Con la segnalazione partono solo info tecniche (origine, versioni,
 * dispositivo, lingua): né nome né email dell'utente.
 */
import { supabase, isSupabaseEnabled } from './supabaseClient';

export const FEEDBACK_MIN = 10;
export const FEEDBACK_MAX = 2000;

// Stesse regole di redactSensitive nella funzione: qui fermano l'invio e
// spiegano cosa togliere, là sono la rete di sicurezza.
const SENSITIVE = {
  email: /[^\s@]+@[^\s@]+\.[^\s@]+/,
  iban: /\b[A-Z]{2}\d{2}(?:\s?[A-Z0-9]){11,30}\b/,
  number: /\+?\d(?:[\s./-]?\d){8,}/,
};

/** Tipi di dato sensibile trovati nel testo: [] se è pulito. */
export function findSensitive(text) {
  return Object.keys(SENSITIVE).filter((kind) => SENSITIVE[kind].test(text || ''));
}

/** true se il testo si può inviare (lunghezza giusta, niente dati sensibili). */
export function canSendFeedback(text) {
  const length = (text || '').trim().length;
  return length >= FEEDBACK_MIN && length <= FEEDBACK_MAX && findSensitive(text).length === 0;
}

/**
 * Info tecniche da allegare. Nell'app iOS le mette il nativo in
 * window.svDeviceInfo (versione app, iOS, modello); nel browser c'è solo lo
 * user agent.
 */
export function deviceInfo({ native, userAgent, language }) {
  const info = native
    ? {
        source: 'app iOS',
        appVersion: native.appVersion,
        osVersion: native.osVersion,
        model: native.model,
      }
    : { source: 'sito web', userAgent };
  if (language) info.language = language;
  return Object.fromEntries(Object.entries(info).filter(([, v]) => typeof v === 'string' && v));
}

/** Le info del dispositivo su cui gira il sito adesso. */
export function currentDeviceInfo(language) {
  return deviceInfo({
    native: globalThis.window?.svDeviceInfo,
    userAgent: globalThis.navigator?.userAgent,
    language,
  });
}

/**
 * @param {{kind: 'bug'|'idea', message: string, info: object}} feedback
 * @throws {Error} 'feedback-unavailable' senza cloud (modalità locale),
 *   'feedback-limit' dopo troppi invii ravvicinati, 'feedback-failed' altrimenti
 */
export async function sendFeedback({ kind, message, info }) {
  if (!isSupabaseEnabled) throw new Error('feedback-unavailable');
  const { data, error } = await supabase.functions.invoke('send-feedback', {
    body: { kind, message: message.trim(), info },
  });
  if (error) {
    throw new Error(error.context?.status === 429 ? 'feedback-limit' : 'feedback-failed');
  }
  if (!data?.ok) throw new Error('feedback-failed');
}
