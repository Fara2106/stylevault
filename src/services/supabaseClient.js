/**
 * Client Supabase condizionale.
 * Se le variabili d'ambiente non sono impostate l'app resta in "modalità locale"
 * (localStorage, auth simulata): tutto continua a funzionare come in Fase A.
 * Con VITE_SUPABASE_URL e VITE_SUPABASE_ANON_KEY in .env.local si attiva il cloud.
 */
import { createClient } from '@supabase/supabase-js';

const url = import.meta.env.VITE_SUPABASE_URL;
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

export const isSupabaseEnabled = Boolean(url && anonKey);

/**
 * Nell'app iOS la sessione la gestisce il login nativo e la passa al sito:
 * se rinnovassero il token entrambi, il secondo userebbe un refresh token già
 * consumato e Supabase chiuderebbe la sessione (utente buttato fuori).
 */
export function authOptions(native) {
  return { autoRefreshToken: !native };
}

const insideApp = Boolean(globalThis.window?.webkit?.messageHandlers?.svNative);

export const supabase = isSupabaseEnabled
  ? createClient(url, anonKey, { auth: authOptions(insideApp) })
  : null;
