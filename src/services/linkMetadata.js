/**
 * Estrazione metadati da un link di shop online.
 * Con Supabase configurato usa la Edge Function `fetch-link-metadata`
 * (vedi supabase/functions/); altrimenti, o in caso di errore, ripiega
 * sull'API pubblica di microlink.io (CORS aperto, piano gratuito).
 */
import { supabase, isSupabaseEnabled } from './supabaseClient';

const MICROLINK_URL = 'https://api.microlink.io/';

/**
 * "Maglione - ecru - Zalando.it" → "Maglione - ecru": il nome dello shop in
 * coda al titolo della pagina non serve come nome del capo.
 */
function stripShopSuffix(title, site) {
  const shop = site.toLowerCase().replace(/^www\./, '').split('.')[0];
  if (!shop) return title;
  const parts = title.split(/\s+[-|–]\s+/);
  if (parts.length > 1 && parts[parts.length - 1].toLowerCase().includes(shop)) {
    const cut = title.lastIndexOf(parts[parts.length - 1]);
    return title.slice(0, cut).replace(/\s+[-|–]\s*$/, '').trim();
  }
  return title;
}

async function viaMicrolink(url) {
  let res;
  try {
    res = await fetch(`${MICROLINK_URL}?url=${encodeURIComponent(url)}`);
  } catch (networkError) {
    throw new Error('link-metadata-failed', { cause: networkError });
  }
  // Piano gratuito: ~50 letture al giorno, poi 429 fino al giorno dopo.
  // Errore distinto: non è colpa dello shop, domani il link funzionerà.
  if (res.status === 429) throw new Error('link-metadata-limit');
  if (!res.ok) throw new Error('link-metadata-failed');

  const data = await res.json();
  if (data.status !== 'success' || !data.data) {
    throw new Error('link-metadata-failed');
  }
  // "success" vuol dire solo che microlink ha letto QUALCOSA: con gli shop
  // che bloccano i bot (es. H&M) è la pagina "Access Denied" con codice 403,
  // e il titolo finiva come nome del capo.
  if (data.statusCode >= 400) {
    throw new Error('link-metadata-failed');
  }

  return {
    title: stripShopSuffix(data.data.title || '', data.data.publisher || ''),
    // Niente ripiego sul logo del sito: come foto del capo è peggio di nessuna
    // foto (l'utente la carica a mano).
    image: data.data.image?.url || '',
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
 * @throws {Error} 'link-metadata-failed' se la pagina non è leggibile,
 *   'link-metadata-limit' se il servizio gratuito ha finito le letture del giorno
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
