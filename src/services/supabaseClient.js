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

export const supabase = isSupabaseEnabled ? createClient(url, anonKey) : null;
