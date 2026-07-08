/**
 * Estrazione metadati da un link di shop online.
 * Con Supabase configurato usa la Edge Function `fetch-link-metadata`
 * (vedi supabase/functions/); altrimenti, o in caso di errore, ripiega
 * sull'API pubblica di microlink.io (CORS aperto, piano gratuito).
 */
import { supabase, isSupabaseEnabled } from './supabaseClient';

const MICROLINK_URL = 'https://api.microlink.io/';

async function viaMicrolink(url) {
  let res;
  try {
    res = await fetch(`${MICROLINK_URL}?url=${encodeURIComponent(url)}`);
  } catch (networkError) {
    throw new Error('link-metadata-failed', { cause: networkError });
  }
  if (!res.ok) throw new Error('link-metadata-failed');

  const data = await res.json();
  if (data.status !== 'success' || !data.data) {
    throw new Error('link-metadata-failed');
  }

  return {
    title: data.data.title || '',
    image: data.data.image?.url || data.data.logo?.url || '',
    site: data.data.publisher || '',
  };
}

async function viaEdgeFunction(url) {
  const { data, error } = await supabase.functions.invoke('fetch-link-metadata', {
    body: { url },
  });
  if (error || !data || data.error) throw new Error('link-metadata-failed');
  return { title: data.title || '', image: data.image || '', site: data.site || '' };
}

/**
 * @param {string} url - Link alla pagina prodotto
 * @returns {Promise<{title: string, image: string, site: string}>}
 * @throws {Error} 'link-metadata-failed' se la pagina non è leggibile
 */
export async function fetchLinkMetadata(url) {
  if (isSupabaseEnabled) {
    try {
      return await viaEdgeFunction(url);
    } catch {
      // Funzione non deployata o shop ostile: si tenta comunque con microlink
    }
  }
  return viaMicrolink(url);
}

/** Validazione superficiale di un URL http(s). */
export function isValidHttpUrl(value) {
  try {
    const parsed = new URL(value);
    return parsed.protocol === 'http:' || parsed.protocol === 'https:';
  } catch {
    return false;
  }
}
